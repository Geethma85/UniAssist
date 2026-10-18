"""
test_document_management.py

Tests for GET /admin/documents and DELETE /admin/documents/<doc_id>.

Auth is mocked the same way as test_documents.py. Unlike the upload tests,
the delete tests use a REAL in-memory ChromaDB collection (no embedding
model needed - we pass tiny fake vectors), so the real delete_document()
function body actually runs.
"""

import uuid
import chromadb
import pytest
from unittest.mock import patch, MagicMock

from app import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def auth_headers(token="fake-valid-token"):
    return {"Authorization": f"Bearer {token}"}


def _mock_auth(mock_verify, mock_db, role="admin"):
    mock_verify.return_value = {"uid": "test-user-123"}
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {"role": role}
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc


def _make_collection(docs):
    """Build a throwaway in-memory collection.
    docs: {document_id: (filename, chunk_count)}"""
    client = chromadb.EphemeralClient()
    collection = client.create_collection(f"test_{uuid.uuid4().hex}")
    for doc_id, (filename, n) in docs.items():
        collection.add(
            ids=[f"{doc_id}_{i}" for i in range(n)],
            embeddings=[[0.1, 0.2, 0.3] for _ in range(n)],
            documents=[f"chunk {i} of {filename}" for i in range(n)],
            metadatas=[
                {
                    "filename": filename,
                    "upload_date": "2026-10-13T00:00:00+00:00",
                    "chunk_index": i,
                    "document_id": doc_id,
                }
                for i in range(n)
            ],
        )
    return collection


def _chunks_for(collection, doc_id):
    return collection.get(where={"document_id": doc_id}, include=[])["ids"]


@patch("app.routes.documents.delete_document")
@patch("app.routes.documents.list_documents")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_non_admin_cannot_list_or_delete(
    mock_verify, mock_db, mock_list, mock_delete, client
):
    """A student gets 403 on both routes, and the service functions
    are never reached."""
    _mock_auth(mock_verify, mock_db, role="student")

    list_response = client.get("/admin/documents", headers=auth_headers())
    delete_response = client.delete("/admin/documents/some-id", headers=auth_headers())

    assert list_response.status_code == 403
    assert delete_response.status_code == 403
    mock_list.assert_not_called()
    mock_delete.assert_not_called()


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_delete_removes_all_chunks_of_that_document_only(mock_verify, mock_db, client):
    """Deleting document A removes all 3 of its chunks and leaves
    document B's 2 chunks alone."""
    _mock_auth(mock_verify, mock_db, role="admin")
    collection = _make_collection({
        "doc-a": ("timetable.pdf", 3),
        "doc-b": ("timetable.pdf", 2),  # same filename on purpose
    })

    with patch("app.services.vector_store.get_collection", return_value=collection):
        response = client.delete("/admin/documents/doc-a", headers=auth_headers())

    assert response.status_code == 200
    assert response.get_json()["chunks_deleted"] == 3
    assert _chunks_for(collection, "doc-a") == []
    assert len(_chunks_for(collection, "doc-b")) == 2


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_delete_unknown_id_returns_404(mock_verify, mock_db, client):
    """An id that doesn't exist gives a clean 404 and deletes nothing."""
    _mock_auth(mock_verify, mock_db, role="admin")
    collection = _make_collection({"doc-a": ("policy.txt", 2)})

    with patch("app.services.vector_store.get_collection", return_value=collection):
        response = client.delete("/admin/documents/does-not-exist", headers=auth_headers())

    assert response.status_code == 404
    assert response.get_json() == {"error": "Document not found."}
    assert len(_chunks_for(collection, "doc-a")) == 2