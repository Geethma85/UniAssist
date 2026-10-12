from flask import Blueprint, jsonify, g

from app.middleware.auth import require_auth
from app.services.conversation_service import list_conversations, get_conversation

conversations_bp = Blueprint("conversations", __name__)


@conversations_bp.route("/conversations", methods=["GET"])
@require_auth
def list_my_conversations():
    return jsonify({"conversations": list_conversations(g.uid)}), 200


@conversations_bp.route("/conversations/<conversation_id>", methods=["GET"])
@require_auth
def get_my_conversation(conversation_id):
    convo = get_conversation(g.uid, conversation_id)
    if convo is None:
        return jsonify({"error": "Conversation not found."}), 404
    return jsonify(convo), 200