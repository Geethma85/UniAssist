"""
test_chat.py

Tests for POST /chat. Mocked so tests run instantly with no network calls:
  1. firebase_auth.verify_id_token  -> require_auth's token check
  2. the Firestore users/{uid} lookup that require_auth also does
  3. get_chat_reply, get_relevant_chunks -> no real Gemini or ChromaDB
  4. create_conversation, save_message -> no real Firestore writes

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
    """Simulates a valid, logged-in student so tests get past @require_auth."""
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


@patch("app.routes.chat.get_relevant_chunks", return_value=[])
@patch("app.routes.chat.save_message")
@patch("app.routes.chat.create_conversation", return_value="convo-1")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
@patch("app.routes.chat.get_chat_reply")
def test_chat_returns_reply_and_saves_messages(
    mock_reply, mock_verify, mock_db, mock_create, mock_save, mock_chunks, client
):
    _mock_successful_auth(mock_verify, mock_db)
    mock_reply.return_value = "The library closes at 10pm on weekdays."

    response = client.post(
        "/chat",
        json={"message": "What time does the library close?"},
        headers=auth_headers(),
    )

    body = response.get_json()
    assert response.status_code == 200
    assert body["reply"] == "The library closes at 10pm on weekdays."
    assert body["conversation_id"] == "convo-1"
    assert body["saved"] is True

    # New conversation created under the verified uid, from the first message
    mock_create.assert_called_once_with("test-user-123", "What time does the library close?")

    # Both sides of the exchange saved, under the token's uid
    mock_save.assert_any_call("test-user-123", "convo-1", "user", "What time does the library close?")
    mock_save.assert_any_call("test-user-123", "convo-1", "assistant", "The library closes at 10pm on weekdays.")