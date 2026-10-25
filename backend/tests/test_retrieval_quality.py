from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.services import gemini_service, vector_store


def test_new_collection_uses_cosine(tmp_path, monkeypatch):
    monkeypatch.setattr(vector_store, "CHROMA_PERSIST_DIR", str(tmp_path))
    monkeypatch.setattr(vector_store, "_client", None)
    monkeypatch.setattr(vector_store, "_collection", None)

    collection = vector_store.get_collection()

    assert collection.configuration["hnsw"]["space"] == "cosine"


def test_empty_collection_does_not_load_embedding_model(monkeypatch):
    collection = MagicMock()
    collection.count.return_value = 0
    model_loader = MagicMock()

    monkeypatch.setattr(vector_store, "get_collection", lambda: collection)
    monkeypatch.setattr(vector_store, "get_model", model_loader)

    assert vector_store.query_chunks("Any question")["documents"] == [[]]
    model_loader.assert_not_called()
    collection.query.assert_not_called()


def test_query_caps_results_to_available_chunks(monkeypatch):
    collection = MagicMock()
    collection.count.return_value = 2
    model = MagicMock()
    model.encode.return_value.tolist.return_value = [[1.0, 0.0]]

    monkeypatch.setattr(vector_store, "get_collection", lambda: collection)
    monkeypatch.setattr(vector_store, "get_model", lambda: model)

    vector_store.query_chunks("Library hours?", top_k=5)

    assert collection.query.call_args.kwargs["n_results"] == 2


def test_cutoff_is_inclusive_and_preserves_source_identity(monkeypatch):
    cutoff = vector_store.DISTANCE_THRESHOLD
    results = {
        "ids": [["chunk-a", "chunk-b", "chunk-c"]],
        "documents": [["Below", "At cutoff", "Above"]],
        "metadatas": [[
            {
                "filename": "handbook.txt",
                "document_id": "doc-1",
                "chunk_index": index,
            }
            for index in range(3)
        ]],
        "distances": [[cutoff - 0.01, cutoff, cutoff + 0.01]],
    }
    monkeypatch.setattr(
        vector_store, "query_chunks", lambda *args, **kwargs: results
    )

    chunks = vector_store.get_relevant_chunks("Question")

    assert [chunk["chunk_id"] for chunk in chunks] == ["chunk-a", "chunk-b"]
    assert chunks[1]["document_id"] == "doc-1"
    assert chunks[1]["chunk_index"] == 1


def fake_gemini(monkeypatch, text):
    client = MagicMock()
    client.models.generate_content.return_value = SimpleNamespace(text=text)
    monkeypatch.setattr(gemini_service, "_get_client", lambda: client)
    return client


def test_no_context_still_sends_grounding_policy(monkeypatch):
    client = fake_gemini(monkeypatch, "Try spaced repetition.")

    gemini_service.get_chat_reply("How should I study?", context_chunks=[])

    instruction = (
        client.models.generate_content.call_args.kwargs["config"]
        .system_instruction
    )
    assert instruction.startswith(gemini_service.SYSTEM_PROMPT)
    assert "No document excerpts are available" in instruction


def test_valid_citation_gets_filename(monkeypatch):
    fake_gemini(monkeypatch, "Appeal within 14 days [S1].")

    reply = gemini_service.get_chat_reply(
        "When can I appeal?",
        context_chunks=[{
            "text": "Appeals must be submitted within 14 days.",
            "filename": "appeals.txt",
            "document_id": "doc-1",
            "chunk_id": "chunk-1",
        }],
    )

    assert "Sources:\n[S1] appeals.txt" in reply


def test_nonexistent_citation_is_rejected(monkeypatch):
    fake_gemini(monkeypatch, "The deadline is Friday [S2].")

    with pytest.raises(gemini_service.GeminiServiceError):
        gemini_service.get_chat_reply(
            "What is the deadline?",
            context_chunks=[{
                "text": "No deadline stated.",
                "filename": "handbook.txt",
            }],
        )
        
def test_grouped_citations_are_normalized_and_listed(monkeypatch):
    fake_gemini(monkeypatch, "Borrow four books for fourteen days [S1, S2].")

    reply = gemini_service.get_chat_reply(
        "What are the borrowing rules?",
        context_chunks=[
            {
                "text": "Students may borrow four books.",
                "filename": "borrowing.txt",
            },
            {
                "text": "The loan period is fourteen days.",
                "filename": "loan-period.txt",
            },
        ],
    )

    assert "fourteen days [S1] [S2]." in reply
    assert "[S1] borrowing.txt" in reply
    assert "[S2] loan-period.txt" in reply
    assert "[S1, S2]" not in reply


def test_grouped_citation_with_unknown_source_is_rejected(monkeypatch):
    fake_gemini(monkeypatch, "Borrow four books [S1, S2].")

    with pytest.raises(gemini_service.GeminiServiceError):
        gemini_service.get_chat_reply(
            "How many books?",
            context_chunks=[{
                "text": "Students may borrow four books.",
                "filename": "borrowing.txt",
            }],
        )