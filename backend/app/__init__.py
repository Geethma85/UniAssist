import os
import firebase_admin
from firebase_admin import credentials
from flask import Flask
from flask_cors import CORS

# Initialize Firebase Admin SDK once, using the service account key.
# Guarded with firebase_admin._apps so repeated create_app() calls
# (e.g. one per pytest test) don't try to re-initialize and crash.
if not firebase_admin._apps:
    cred_path = os.path.join(os.path.dirname(__file__), '..', 'serviceAccountKey.json')
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)


def create_app():
    """Application factory. Keeps app creation testable (pytest can spin up
    fresh instances) instead of using a single global Flask object."""
    app = Flask(__name__)
    CORS(app)

    from app.routes.health import health_bp
    app.register_blueprint(health_bp)

    return app