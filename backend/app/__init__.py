import os
import json
from pathlib import Path

from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials
from flask import Flask
from flask_cors import CORS

BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND_DIR / ".env")


def firebase_credential_path():
    configured = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
    path = Path(configured or "serviceAccountKey.json").expanduser()
    return path if path.is_absolute() else BACKEND_DIR / path


# Initialize once, including when tests create multiple app instances.
if not firebase_admin._apps:
    service_account_json = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON", ""
    ).strip()

    if service_account_json:
        cred = credentials.Certificate(json.loads(service_account_json))
    else:
        cred = credentials.Certificate(str(firebase_credential_path()))

    firebase_admin.initialize_app(cred)
def create_app():
    """Application factory. Keeps app creation testable (pytest can spin up
    fresh instances) instead of using a single global Flask object."""
    app = Flask(__name__)
    allowed_origins = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ALLOWED_ORIGINS",
            "http://localhost:3000",
        ).split(",")
        if origin.strip()
    ]
    CORS(
        app,
        origins=allowed_origins,
        allow_headers=["Authorization", "Content-Type"],
        methods=["GET", "POST", "DELETE", "OPTIONS"],
    )
    
    app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024  # 10 MB, matches our file validation

    from app.routes.health import health_bp
    app.register_blueprint(health_bp)

    from app.routes.chat import chat_bp
    app.register_blueprint(chat_bp)
    
    from app.routes.documents import documents_bp
    app.register_blueprint(documents_bp)

    from app.routes.conversations import conversations_bp
    app.register_blueprint(conversations_bp)
    
    return app