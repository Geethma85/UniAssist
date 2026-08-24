from flask import Flask
from flask_cors import CORS


def create_app():
    """Application factory. Keeps app creation testable (pytest can spin up
    fresh instances) instead of using a single global Flask object."""
    app = Flask(__name__)
    CORS(app)

    from app.routes.health import health_bp
    app.register_blueprint(health_bp)

    return app
