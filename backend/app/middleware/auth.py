from functools import wraps
from flask import request, jsonify, g
from firebase_admin import auth as firebase_auth, firestore

db = firestore.client()


def require_auth(f):
    """Verifies the Firebase ID token on the Authorization header.
    On success, attaches g.uid and g.role for the route to use."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')

        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or malformed Authorization header'}), 401

        id_token = auth_header.split('Bearer ', 1)[1]

        try:
            decoded_token = firebase_auth.verify_id_token(id_token)
        except Exception as e:
            print(f"TOKEN VERIFY FAILED: {e}")
            return jsonify({'error': 'Invalid or expired token'}), 401

        uid = decoded_token['uid']

        user_doc = db.collection('users').document(uid).get()
        if not user_doc.exists:
            return jsonify({'error': 'User profile not found'}), 401

        g.uid = uid
        g.role = user_doc.to_dict().get('role', 'student')

        return f(*args, **kwargs)
    return decorated


def require_auth(f):
    """Verifies the Firebase ID token on the Authorization header.
    On success, attaches g.uid and g.role for the route to use."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')

        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or malformed Authorization header'}), 401

        id_token = auth_header.split('Bearer ', 1)[1]

        try:
            decoded_token = firebase_auth.verify_id_token(id_token)
        except Exception:
            return jsonify({'error': 'Invalid or expired token'}), 401

        uid = decoded_token['uid']

        user_doc = db.collection('users').document(uid).get()
        if not user_doc.exists:
            return jsonify({'error': 'User profile not found'}), 401

        g.uid = uid
        g.role = user_doc.to_dict().get('role', 'student')

        return f(*args, **kwargs)
    return decorated