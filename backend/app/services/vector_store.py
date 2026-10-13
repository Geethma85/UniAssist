import uuid
from datetime import datetime, timezone
import chromadb
from sentence_transformers import SentenceTransformer

EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"
CHROMA_PERSIST_DIR = "chroma_data"
COLLECTION_NAME = "documents"

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
        _collection = _client.get_or_create_collection(COLLECTION_NAME)
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
    """Return the top_k most relevant chunks for a question, with distances."""
    model = get_model()
    collection = get_collection()

    question_embedding = model.encode([question]).tolist()
    results = collection.query(
        query_embeddings=question_embedding,
        n_results=top_k,
    )
    return results

DISTANCE_THRESHOLD = 0.8  # cosine distance cutoff; chunks farther than this
                           # are treated as irrelevant to the question.
                           # Tuned by eye — revisit with real usage data.


def get_relevant_chunks(question: str, top_k: int = 3) -> list[dict]:
    """
    Returns a list of relevant chunks for the question, each as
    {"text": ..., "filename": ..., "distance": ...}, filtered to only
    chunks under DISTANCE_THRESHOLD. Returns [] if nothing is relevant
    (including when the collection is empty).
    """
    results = query_chunks(question, top_k=top_k)

    documents = results.get("documents", [[]])[0]
    metadatas = results.get("metadatas", [[]])[0]
    distances = results.get("distances", [[]])[0]

    relevant = []
    for text, meta, distance in zip(documents, metadatas, distances):
        if distance <= DISTANCE_THRESHOLD:
            relevant.append({
                "text": text,
                "filename": meta.get("filename", "unknown"),
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