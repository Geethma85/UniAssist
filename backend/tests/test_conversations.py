"""
test_conversations.py

Tests for GET /conversations, GET /conversations/<id> and the
conversation_service validation. Firestore is mocked at _conversations_ref,
the one function that builds users/{uid}/conversations, so we can check
which uid the path was built from.
"""

import pytest
from unittest.mock import patch, MagicMock

from app import create_app
from app.services.conversation_service import save_message


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def auth_headers(token="fake-valid-token"):
    return {"Authorization": f"Bearer {token}"}


def _mock_successful_auth(mock_verify, mock_db):
    mock_verify.return_value = {"uid": "test-user-123"}
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {"role": "student"}
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc


@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_cannot_fetch_another_users_conversation(
    mock_verify, mock_db, mock_ref, client
):
    """Requesting someone else's conversation id looks under OUR uid's path,
    finds nothing, and returns 404 (not 403)."""
    _mock_successful_auth(mock_verify, mock_db)
    mock_ref.return_value.document.return_value.get.return_value.exists = False

    response = client.get("/conversations/someone-elses-convo", headers=auth_headers())

    assert response.status_code == 404
    # The path was built from the token's uid, never from the URL
    mock_ref.assert_called_once_with("test-user-123")


@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_empty_history_returns_empty_list(mock_verify, mock_db, mock_ref, client):
    """A brand-new user with no conversations gets 200 and [], not an error."""
    _mock_successful_auth(mock_verify, mock_db)
    mock_ref.return_value.order_by.return_value.limit.return_value.stream.return_value = []

    response = client.get("/conversations", headers=auth_headers())

    assert response.status_code == 200
    assert response.get_json() == {"conversations": []}


def test_conversations_require_auth(client):
    assert client.get("/conversations").status_code == 401
    assert client.get("/conversations/abc").status_code == 401


def test_save_message_rejects_invalid_role():
    """Only 'user' and 'assistant' roles may be stored."""
    with pytest.raises(ValueError):
        save_message("test-user-123", "convo-1", "system", "hello")

@patch("app.services.conversation_service.firestore")
@patch("app.services.conversation_service._conversations_ref")
def test_save_message_writes_message_and_updates_preview(mock_ref, mock_firestore):
    """The message doc and the conversation preview go through one batch,
    and the batch is actually committed."""
    mock_batch = mock_firestore.client.return_value.batch.return_value

    save_message("uid-1", "convo-1", "user", "hello there")

    mock_ref.assert_called_once_with("uid-1")  # path built from the given uid
    mock_batch.set.assert_called_once()
    saved = mock_batch.set.call_args[0][1]
    assert saved["role"] == "user"
    assert saved["content"] == "hello there"

    mock_batch.update.assert_called_once()
    assert mock_batch.update.call_args[0][1]["lastMessagePreview"] == "hello there"

    mock_batch.commit.assert_called_once()

def test_delete_conversation_requires_auth(client):
    assert client.delete("/conversations/abc").status_code == 401


@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_delete_uses_authenticated_users_path(
    mock_verify, mock_db, mock_ref, client
):
    _mock_successful_auth(mock_verify, mock_db)
    convo = mock_ref.return_value.document.return_value
    convo.get.return_value.exists = False

    response = client.delete(
        "/conversations/another-users-convo",
        headers=auth_headers(),
    )

    assert response.status_code == 404
    mock_ref.assert_called_once_with("test-user-123")
    convo.collection.assert_not_called()
    convo.delete.assert_not_called()


@patch("app.services.conversation_service.firestore")
@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_delete_removes_messages_before_parent(
    mock_verify, mock_db, mock_ref, mock_firestore, client
):
    _mock_successful_auth(mock_verify, mock_db)
    convo = mock_ref.return_value.document.return_value
    convo.get.return_value.exists = True

    message = MagicMock()
    query = convo.collection.return_value.limit.return_value
    query.stream.side_effect = [[message], []]

    batch = mock_firestore.client.return_value.batch.return_value
    order = MagicMock()
    order.attach_mock(batch.commit, "commit")
    order.attach_mock(convo.delete, "delete_parent")

    response = client.delete(
        "/conversations/convo-1", headers=auth_headers()
    )

    assert response.status_code == 204
    assert response.data == b""
    mock_ref.assert_called_once_with("test-user-123")
    convo.collection.assert_called_once_with("messages")
    batch.delete.assert_called_once_with(message.reference)
    assert [call[0] for call in order.mock_calls] == [
        "commit", "delete_parent"
    ]


@patch("app.services.conversation_service.firestore")
@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_delete_failure_preserves_parent_for_retry(
    mock_verify, mock_db, mock_ref, mock_firestore, client
):
    _mock_successful_auth(mock_verify, mock_db)
    convo = mock_ref.return_value.document.return_value
    convo.get.return_value.exists = True
    convo.collection.return_value.limit.return_value.stream.return_value = [
        MagicMock()
    ]
    batch = mock_firestore.client.return_value.batch.return_value
    batch.commit.side_effect = RuntimeError("private database details")

    response = client.delete(
        "/conversations/convo-1", headers=auth_headers()
    )

    assert response.status_code == 503
    assert response.get_json()["error"] == (
        "Could not delete conversation. Please try again."
    )
    convo.delete.assert_not_called()


@patch("app.services.conversation_service._conversations_ref")
@patch("app.middleware.auth.db")
@patch("app.middleware.auth.firebase_auth.verify_id_token")

def test_delete_empty_conversation(
    mock_verify, mock_db, mock_ref, client
):
    _mock_successful_auth(mock_verify, mock_db)
    convo = mock_ref.return_value.document.return_value
    convo.get.return_value.exists = True
    convo.collection.return_value.limit.return_value.stream.return_value = []

    response = client.delete(
        "/conversations/convo-1", headers=auth_headers()
    )

    assert response.status_code == 204
    convo.delete.assert_called_once()