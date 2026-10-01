"""
test_vector_store.py

Tests the actual embedding + ChromaDB retrieval logic end-to-end, using
a real (temporary) ChromaDB collection - no mocking here, since the
whole point is to prove that semantically similar text actually gets
retrieved. This test is slower than the others because it loads the
real embedding model.
"""

import pytest
from app.services import vector_store


@pytest.fixture
def isolated_store(tmp_path, monkeypatch):
    """Points the vector store at a temp folder and resets its cached
    client/collection, so this test doesn't touch your real chroma_data/
    and doesn't leak state into other tests."""
    monkeypatch.setattr(vector_store, "CHROMA_PERSIST_DIR", str(tmp_path / "test_chroma"))
    monkeypatch.setattr(vector_store, "_client", None)
    monkeypatch.setattr(vector_store, "_collection", None)
    yield vector_store


def test_retrieval_finds_relevant_chunk(isolated_store):
    chunks = [
        "Grade disputes must be submitted within 14 days of results publication.",
        "The library is open from 8am to 10pm on weekdays.",
        "Students must maintain a minimum GPA of 2.0 to remain enrolled.",
    ]
    isolated_store.store_document_chunks("handbook.pdf", chunks)

    results = isolated_store.query_chunks("How many days do I have to appeal my grade?", top_k=1)

    top_chunk = results["documents"][0][0]
    assert "14 days" in top_chunk
    assert results["metadatas"][0][0]["filename"] == "handbook.pdf"