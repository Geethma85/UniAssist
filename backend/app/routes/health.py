from flask import Blueprint, jsonify

health_bp = Blueprint("health", __name__)


@health_bp.route("/health", methods=["GET"])
def health():
    """Simple liveness check. Confirms the Flask app is up before any
    Firebase/Gemini wiring is added."""
    return jsonify({"status": "ok", "service": "UniAssist backend"}), 200
