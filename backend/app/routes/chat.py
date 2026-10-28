"""
chat.py

POST /chat: protected chat endpoint with RAG. History is loaded from
Firestore under the verified uid (never trusted from the client), and each
exchange is saved after Gemini replies.
"""

import logging
from flask import Blueprint, request, jsonify, g

from app.middleware.auth import require_auth
from app.services.conversation_service import (
    create_conversation, save_message, get_recent_messages,
)
from app.services.gemini_service import get_chat_reply, GeminiServiceError
from app.services.vector_store import get_relevant_chunks

logger = logging.getLogger(__name__)
from flask import Blueprint, request, jsonify

from app.middleware.auth import require_auth
from app.services.gemini_service import get_chat_reply, GeminiServiceError
from app.services.vector_store import get_relevant_chunks

chat_bp = Blueprint("chat", __name__)

MAX_MESSAGE_LENGTH = 2000
MAX_HISTORY_TURNS = 20  # how many prior turns we forward to Gemini per request


@chat_bp.route("/chat", methods=["POST"])
@require_auth
def chat():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Request body must be a JSON object."}), 400
    message = data.get("message")
    conversation_id = data.get("conversation_id")

    if not isinstance(message, str) or not message.strip():
        return jsonify({"error": "Message cannot be empty."}), 400
    if len(message) > MAX_MESSAGE_LENGTH:
        return jsonify(
            {"error": f"Message is too long (max {MAX_MESSAGE_LENGTH} characters)."}
        ), 400
    if conversation_id is not None and not isinstance(conversation_id, str):
        return jsonify({"error": "conversation_id must be a string."}), 400

    message = message.strip()

    # History comes from Firestore under the verified uid, never from the client.
    if conversation_id:
        try:
            history = get_recent_messages(
                g.uid, conversation_id, MAX_HISTORY_TURNS
            )
        except Exception:
            logger.exception("Conversation history loading failed")
            return jsonify({
                "error": "Conversation history is temporarily unavailable. "
                         "Please try again."
            }), 503

        if history is None:
            return jsonify({"error": "Conversation not found."}), 404
    else:
        history = []

    try:
        relevant_chunks = get_relevant_chunks(message)
    except Exception:
        logger.exception("Document retrieval failed")
        return jsonify({
            "error": "Document search is temporarily unavailable. Please try again."
        }), 503
    
    try:
        reply = get_chat_reply(message, history, context_chunks=relevant_chunks)
    except GeminiServiceError as e:
        return jsonify({"error": str(e)}), e.status_code

    # Gemini succeeded, so now persist (option B: nothing saved on failure).
    saved = True
    try:
        if not conversation_id:
            conversation_id = create_conversation(g.uid, message)
        save_message(g.uid, conversation_id, "user", message)
        save_message(g.uid, conversation_id, "assistant", reply)
    except Exception:
        logger.exception("Failed to save chat history")
        saved = False

    return jsonify({
        "reply": reply,
        "conversation_id": conversation_id,
        "saved": saved,
    }), 200