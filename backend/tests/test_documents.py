"""
test_documents.py

Tests for POST /admin/documents/upload.

Mocks the same two auth pieces as test_chat.py, but lets the role be
set per-test so we can check both the admin-allowed and
non-admin-rejected paths. The actual chunking/storage call
(store_document_chunks) is mocked too, so these tests don't touch
ChromaDB or load the embedding model - that's covered separately in
test_vector_store.py.
"""

import io
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


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.documents.store_document_chunks")
def test_wrong_file_type_rejected(mock_store, mock_verify, mock_db, client):
    """Admin uploads a .docx - should be rejected by extract_text's
    validation before store_document_chunks is ever called."""
    _mock_auth(mock_verify, mock_db, role="admin")

    data = {"file": (io.BytesIO(b"fake content"), "notes.docx")}
    response = client.post(
        "/admin/documents/upload",
        data=data,
        headers=auth_headers(),
        content_type="multipart/form-data",
    )

    assert response.status_code == 400
    assert "Unsupported" in response.get_json()["error"]
    mock_store.assert_not_called()


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.documents.store_document_chunks")
def test_non_admin_upload_rejected(mock_store, mock_verify, mock_db, client):
    """A logged-in student (not admin) should be blocked by require_admin
    with 403, before the route body runs at all."""
    _mock_auth(mock_verify, mock_db, role="student")

    data = {"file": (io.BytesIO(b"Some policy text."), "policy.txt")}
    response = client.post(
        "/admin/documents/upload",
        data=data,
        headers=auth_headers(),
        content_type="multipart/form-data",
    )

    assert response.status_code == 403
    mock_store.assert_not_called()


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.documents.store_document_chunks")
def test_valid_txt_upload_succeeds(mock_store, mock_verify, mock_db, client):
    """Sanity check: a valid .txt from an admin reaches storage and
    returns 201 with the expected shape."""
    _mock_auth(mock_verify, mock_db, role="admin")
    mock_store.return_value = "fake-document-id"

    data = {"file": (io.BytesIO(b"Appeals must be filed within 14 days."), "policy.txt")}
    response = client.post(
        "/admin/documents/upload",
        data=data,
        headers=auth_headers(),
        content_type="multipart/form-data",
    )

    assert response.status_code == 201
    body = response.get_json()
    assert body["document_id"] == "fake-document-id"
    assert body["filename"] == "policy.txt"
    mock_store.assert_called_once()