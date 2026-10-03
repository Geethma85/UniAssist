"""
chat.py

POST /chat — protected plain-chat endpoint. No RAG, no persistence yet;
history is whatever the client sends in the request body.

ADJUST THE IMPORT BELOW: swap `your_auth_module` for whatever module
actually defines your @require_auth decorator.
"""

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
    if data is None:
        return jsonify({"error": "Request body must be valid JSON."}), 400

    message = data.get("message")
    history = data.get("history", [])

    # --- validation ---
    if not isinstance(message, str) or not message.strip():
        return jsonify({"error": "Message cannot be empty."}), 400

    if len(message) > MAX_MESSAGE_LENGTH:
        return jsonify(
            {"error": f"Message is too long (max {MAX_MESSAGE_LENGTH} characters)."}
        ), 400

    if not isinstance(history, list):
        return jsonify({"error": "History must be a list."}), 400

    # Only forward the most recent turns — protects against a client sending
    # an ever-growing history and blowing up request size/cost over a long
    # session. Doesn't matter much today since Flutter isn't persisting
    # anything yet, but it's cheap to have in place now.
    trimmed_history = history[-MAX_HISTORY_TURNS:]

    relevant_chunks = get_relevant_chunks(message.strip())
    try:
        reply = get_chat_reply(message.strip(), trimmed_history, context_chunks=relevant_chunks)
    except GeminiServiceError as e:
        return jsonify({"error": str(e)}), e.status_code

    return jsonify({"reply": reply}), 200