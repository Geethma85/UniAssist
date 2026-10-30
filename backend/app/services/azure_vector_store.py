import logging
import os
import uuid
from datetime import datetime, timezone
from functools import lru_cache

from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery

logger = logging.getLogger(__name__)

BATCH_SIZE = 100
METADATA_FIELDS = [
    "id", "document_id", "filename", "upload_date", "chunk_index"
]


@lru_cache(maxsize=1)
def get_client():
    return SearchClient(
        endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
        index_name=os.environ["AZURE_SEARCH_INDEX"],
        credential=AzureKeyCredential(
            os.environ["AZURE_SEARCH_ADMIN_KEY"]
        ),
        connection_timeout=10,
        read_timeout=30,
    )


def _write_batches(documents, *, delete=False):
    client = get_client()
    operation = client.delete_documents if delete else client.upload_documents

    for start in range(0, len(documents), BATCH_SIZE):
        batch = documents[start:start + BATCH_SIZE]
        results = operation(documents=batch)
        if any(not result.succeeded for result in results):
            raise RuntimeError("Azure Search rejected some indexing operations.")


def store_document_chunks(filename: str, chunks: list[str]) -> str:
    if not chunks:
        raise ValueError("No chunks to store.")

    # Reuse the existing lazy MiniLM loader.
    from app.services.vector_store import get_model

    document_id = str(uuid.uuid4())
    uploaded_at = datetime.now(timezone.utc).isoformat()
    embeddings = get_model().encode(chunks).tolist()

    documents = [
        {
            "id": f"{document_id}_{i}",
            "document_id": document_id,
            "filename": filename,
            "upload_date": uploaded_at,
            "chunk_index": i,
            "text": text,
            "embedding": embedding,
        }
        for i, (text, embedding) in enumerate(zip(chunks, embeddings))
    ]

    try:
        _write_batches(documents)
    except Exception:
        # Uploads are not transactional. Try removing any accepted chunks.
        try:
            _write_batches(
                [{"id": document["id"]} for document in documents],
                delete=True,
            )
        except Exception:
            logger.exception(
                "Upload cleanup failed for document %s", document_id
            )
        raise

    return document_id


def query_chunks(question: str, top_k: int = 3):
    if top_k < 1:
        raise ValueError("top_k must be at least 1.")

    empty = {
        "ids": [[]],
        "documents": [[]],
        "metadatas": [[]],
        "distances": [[]],
    }

    client = get_client()
    count = client.get_document_count()
    if count == 0:
        return empty

    from app.services.vector_store import get_model

    embedding = get_model().encode([question]).tolist()[0]
    limit = min(top_k, count)

    results = client.search(
        search_text=None,
        vector_queries=[
            VectorizedQuery(
                vector=embedding,
                fields="embedding",
                k_nearest_neighbors=limit,
                exhaustive=True,
            )
        ],
        select=METADATA_FIELDS + ["text"],
        top=limit,
    )

    for row in results:
        # For a pure cosine vector query:
        # Azure score = 1 / (1 + cosine distance).
        score = row["@search.score"]
        if score is None or score <= 0:
            continue

        empty["ids"][0].append(row["id"])
        empty["documents"][0].append(row["text"])
        empty["metadatas"][0].append({
            field: row[field]
            for field in METADATA_FIELDS
            if field != "id"
        })
        empty["distances"][0].append(
            max(0.0, min(2.0, (1.0 / score) - 1.0))
        )

    return empty


def list_documents() -> list[dict]:
    rows = get_client().search(
        search_text="*",
        select=METADATA_FIELDS,
    )

    documents = {}
    for row in rows:
        doc_id = row["document_id"]
        if doc_id not in documents:
            documents[doc_id] = {
                "document_id": doc_id,
                "filename": row["filename"],
                "upload_date": row["upload_date"],
                "chunk_count": 0,
            }
        documents[doc_id]["chunk_count"] += 1

    return sorted(
        documents.values(),
        key=lambda document: document["upload_date"],
        reverse=True,
    )


def delete_document(document_id: str) -> int:
    # Escape quotes before inserting a value into an OData filter.
    escaped_id = document_id.replace("'", "''")
    rows = get_client().search(
        search_text="*",
        filter=f"document_id eq '{escaped_id}'",
        select=["id"],
    )
    documents = [{"id": row["id"]} for row in rows]

    if not documents:
        return 0

    _write_batches(documents, delete=True)
    return len(documents)