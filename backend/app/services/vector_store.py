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
    metadatas = [
        {
            "filename": filename,
            "upload_date": datetime.now(timezone.utc).isoformat(),
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