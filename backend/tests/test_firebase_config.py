from pathlib import Path
from unittest.mock import patch

from app import BACKEND_DIR, firebase_credential_path


def test_missing_path_uses_default():
    with patch.dict("os.environ", {}, clear=True):
        assert firebase_credential_path() == BACKEND_DIR / "serviceAccountKey.json"


def test_blank_path_uses_default():
    with patch.dict("os.environ", {"FIREBASE_SERVICE_ACCOUNT_PATH": "   "}):
        assert firebase_credential_path() == BACKEND_DIR / "serviceAccountKey.json"


def test_relative_path_resolves_from_backend():
    with patch.dict(
        "os.environ",
        {"FIREBASE_SERVICE_ACCOUNT_PATH": "keys/demo.json"},
    ):
        assert firebase_credential_path() == BACKEND_DIR / "keys/demo.json"


def test_absolute_path_is_preserved():
    absolute_path = Path.home() / "demo-key.json"
    with patch.dict(
        "os.environ",
        {"FIREBASE_SERVICE_ACCOUNT_PATH": str(absolute_path)},
    ):
        assert firebase_credential_path() == absolute_path