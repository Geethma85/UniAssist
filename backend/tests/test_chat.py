"""
test_chat.py

Basic tests for POST /chat. Two things get mocked so tests run instantly
with no network calls:
  1. firebase_auth.verify_id_token  -> require_auth's token check
  2. the Firestore users/{uid} lookup that require_auth also does
     (it reads the user's role after verifying the token)
  3. gemini_service.get_chat_reply -> so we never call the real Gemini API

Run from the `backend/` directory: `pytest`
"""

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


def _mock_successful_auth(mock_verify, mock_db):
    """Configures the two auth-related mocks to simulate a valid,
    logged-in student. Reused across the tests that need to get past
    @require_auth to reach the endpoint's own logic."""
    mock_verify.return_value = {"uid": "test-user-123"}

    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {"role": "student"}
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc


def test_chat_rejects_missing_auth(client):
    """No Authorization header -> require_auth should 401 before the route
    body ever runs."""
    response = client.post("/chat", json={"message": "Hello"})
    assert response.status_code == 401


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.chat.get_chat_reply")
def test_chat_rejects_empty_message(mock_reply, mock_verify, mock_db, client):
    _mock_successful_auth(mock_verify, mock_db)

    response = client.post("/chat", json={"message": "   "}, headers=auth_headers())

    assert response.status_code == 400
    mock_reply.assert_not_called()  # should fail validation before calling Gemini


@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.chat.get_chat_reply")
def test_chat_returns_reply_on_success(mock_reply, mock_verify, mock_db, client):
    _mock_successful_auth(mock_verify, mock_db)
    mock_reply.return_value = "The library closes at 10pm on weekdays."

    response = client.post(
        "/chat",
        json={"message": "What time does the library close?"},
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.get_json()["reply"] == "The library closes at 10pm on weekdays."