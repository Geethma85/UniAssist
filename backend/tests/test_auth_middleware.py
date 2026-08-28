import pytest
from unittest.mock import patch
from flask import jsonify, g
from app import create_app
from app.middleware.auth import require_auth


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True

    @app.route("/protected")
    @require_auth
    def protected():
        return jsonify({"uid": g.uid, "role": g.role})

    with app.test_client() as client:
        yield client


def test_missing_token_rejected(client):
    response = client.get("/protected")
    assert response.status_code == 401


def test_malformed_header_rejected(client):
    response = client.get("/protected", headers={"Authorization": "Token abc123"})
    assert response.status_code == 401


@patch("app.middleware.auth.firebase_auth.verify_id_token")
def test_invalid_token_rejected(mock_verify, client):
    mock_verify.side_effect = Exception("Invalid token")
    response = client.get("/protected", headers={"Authorization": "Bearer faketoken"})
    assert response.status_code == 401