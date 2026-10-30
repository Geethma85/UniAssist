import uuid
from datetime import datetime, timezone
import chromadb
from sentence_transformers import SentenceTransformer
import os

EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
CHROMA_PERSIST_DIR = "chroma_data"
COLLECTION_NAME = "documents_cosine_v1"

_model = None
_client = None
_collection = None


def get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        _model = SentenceTransformer(EMBEDDING_MODEL_NAME)
    return _model


def get_collection():
    global _client, _collection

    if _collection is None:
        _client = chromadb.PersistentClient(path=CHROMA_PERSIST_DIR)
        collection = _client.get_or_create_collection(
            name=COLLECTION_NAME,
            configuration={"hnsw": {"space": "cosine"}},
        )

        # Creation settings do not change an existing collection.
        space = collection.configuration["hnsw"]["space"]
        if space != "cosine":
            raise RuntimeError(
                f"Collection '{COLLECTION_NAME}' uses {space}, "
                "but retrieval requires cosine. Migrate the index first."
            )

        _collection = collection

    return _collection


def store_document_chunks(filename: str, chunks: list[str]) -> str:
    """Embed and store chunks for one uploaded document. Returns the document_id."""
    if not chunks:
        raise ValueError("No chunks to store.")

    document_id = str(uuid.uuid4())
    model = get_model()
    collection = get_collection()

    embeddings = model.encode(chunks).tolist()
    ids = [f"{document_id}_{i}" for i in range(len(chunks))]
    uploaded_at = datetime.now(timezone.utc).isoformat()
    metadatas = [
        {
            "filename": filename,
            "upload_date": uploaded_at,
            "chunk_index": i,
            "document_id": document_id,
        }
        for i in range(len(chunks))
    ]

    collection.add(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas,
    )

    return document_id


def query_chunks(question: str, top_k: int = 3):
    """Return nearest chunks and cosine distances; lower is closer."""
    if top_k < 1:
        raise ValueError("top_k must be at least 1.")

    collection = get_collection()
    count = collection.count()

    if count == 0:
        return {
            "ids": [[]],
            "documents": [[]],
            "metadatas": [[]],
            "distances": [[]],
        }

    question_embedding = get_model().encode([question]).tolist()

    return collection.query(
        query_embeddings=question_embedding,
        n_results=min(top_k, count),
        include=["documents", "metadatas", "distances"],
    )

# Cosine distance: lower is closer; include distances <= this cutoff.
# Provisional value to assess with the evaluation set; not a confidence score.
DISTANCE_THRESHOLD = 0.8 


def get_relevant_chunks(question: str, top_k: int = 3) -> list[dict]:
    """Return chunks with cosine distance <= the cutoff, including source IDs."""
    results = query_chunks(question, top_k=top_k)

    ids = results["ids"][0]
    documents = results["documents"][0]
    metadatas = results["metadatas"][0]
    distances = results["distances"][0]

    relevant = []
    for chunk_id, text, meta, distance in zip(
        ids, documents, metadatas, distances
    ):
        if distance is None or distance > DISTANCE_THRESHOLD:
            continue

        meta = meta or {}
        relevant.append({
            "text": text,
            "filename": meta.get("filename", "unknown"),
            "document_id": meta.get("document_id"),
            "chunk_id": chunk_id,
            "chunk_index": meta.get("chunk_index"),
            "distance": distance,
        })

    return relevant

def list_documents() -> list[dict]:
    """
    Group all stored chunks by document_id and return one entry per document:
    {"document_id", "filename", "upload_date", "chunk_count"}, newest first.
    Returns [] if nothing is stored.
    """
    collection = get_collection()
    results = collection.get(include=["metadatas"])
    metadatas = results.get("metadatas") or []

    documents = {}
    for meta in metadatas:
        doc_id = meta.get("document_id")
        if not doc_id:
            continue  # skip chunks without an id (very old data)

        date = meta.get("upload_date", "")
        entry = documents.get(doc_id)
        if entry is None:
            documents[doc_id] = {
                "document_id": doc_id,
                "filename": meta.get("filename", "unknown"),
                "upload_date": date,
                "chunk_count": 1,
            }
        else:
            entry["chunk_count"] += 1
            # keep the earliest date (ISO strings sort correctly as text)
            if date and (not entry["upload_date"] or date < entry["upload_date"]):
                entry["upload_date"] = date

    return sorted(documents.values(), key=lambda d: d["upload_date"], reverse=True)

def delete_document(document_id: str) -> int:
    """
    Delete all chunks belonging to one document.
    Returns how many chunks were deleted (0 means the id was unknown).
    """
    collection = get_collection()
    existing = collection.get(where={"document_id": document_id}, include=[])
    ids = existing.get("ids") or []
    if not ids:
        return 0
    collection.delete(ids=ids)
    return len(ids)

_backend = os.getenv("VECTOR_STORE_BACKEND", "chroma").strip().lower()

if _backend == "azure":
    from app.services.azure_vector_store import (
        store_document_chunks,
        query_chunks,
        list_documents,
        delete_document,
    )
elif _backend != "chroma":
    raise RuntimeError("VECTOR_STORE_BACKEND must be 'chroma' or 'azure'.")