from flask import Blueprint, request, jsonify
from app.middleware.auth import require_admin  # adjust import if your path differs
from app.services.text_extraction import extract_text, ExtractionError
from app.services.chunking import chunk_text
from app.services.vector_store import store_document_chunks, list_documents

documents_bp = Blueprint("documents", __name__)


@documents_bp.route("/admin/documents/upload", methods=["POST"])
@require_admin
def upload_document():
    if "file" not in request.files:
        return jsonify({"error": "No file provided."}), 400

    uploaded = request.files["file"]
    if uploaded.filename == "":
        return jsonify({"error": "No file selected."}), 400

    file_bytes = uploaded.read()

    try:
        text = extract_text(uploaded.filename, file_bytes)
    except ExtractionError as e:
        return jsonify({"error": str(e)}), 400
    except Exception:
        # unexpected failure — don't leak internals
        return jsonify({"error": "Could not process file."}), 500

    chunks = chunk_text(text)
    if not chunks:
        return jsonify({"error": "No content to index after processing."}), 400

    try:
        document_id = store_document_chunks(uploaded.filename, chunks)
    except Exception:
        return jsonify({"error": "Could not store document."}), 500

    return jsonify({
        "message": "Document uploaded and indexed successfully.",
        "document_id": document_id,
        "filename": uploaded.filename,
        "chunk_count": len(chunks),
    }), 201


@documents_bp.route("/admin/documents", methods=["GET"])
@require_admin
def get_documents():
    try:
        documents = list_documents()
    except Exception:
        return jsonify({"error": "Could not load documents."}), 500
    return jsonify({"documents": documents}), 200