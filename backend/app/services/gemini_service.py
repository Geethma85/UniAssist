"""
gemini_service.py

All communication with the Gemini API lives here, separate from the Flask
route. Reasons:
  - the route only has to worry about HTTP concerns (auth, validation, JSON)
  - this file only worries about "how do I talk to Gemini"
  - in tests, we mock this whole module instead of mocking the Gemini SDK
    directly, which keeps tests decoupled from SDK internals
"""

import os
import logging

from google import genai
from google.genai import types
from google.genai.errors import APIError

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
MODEL_NAME = "gemini-3.6-flash"

# Why flash (not flash-lite): flash-lite is cheaper/faster but noticeably
# weaker at following instructions and reasoning. For an assistant students
# will judge on answer quality, flash is worth the small extra cost/latency
# at MVP scale. Free tier covers this comfortably for a portfolio demo.

SYSTEM_PROMPT = (
    "You are UniAssist, a helpful assistant for university students. "
    "Answer clearly and concisely, in a friendly, encouraging tone. "
    "If you are not sure about something, or the question depends on "
    "information you don't actually have (a specific university's policies, "
    "deadlines, a student's personal records, etc.), say so plainly instead "
    "of guessing. Do not invent facts, dates, names, or policies. "
    "Keep answers focused — avoid unnecessary padding."
)

RAG_INSTRUCTIONS = (
    "\n\nYou have been given excerpts from official university documents "
    "below, relevant to the student's question. Base your answer only on "
    "this context. When you use it, mention which document it came from "
    "(e.g. 'According to handbook.pdf...'). If the excerpts do not actually "
    "answer the question, say plainly that you don't have that information "
    "in the university's documents — do not guess or fall back on general "
    "knowledge for anything document-specific."
)


def _build_context_block(context_chunks: list[dict]) -> str:
    lines = []
    for chunk in context_chunks:
        lines.append(f"[Source: {chunk['filename']}]\n{chunk['text']}")
    return "\n\n".join(lines)

class GeminiServiceError(Exception):
    """
    Raised for any failure calling Gemini that the route should turn into a
    clean JSON error response instead of a raw stack trace.
    """
    def __init__(self, message, status_code=502):
        super().__init__(message)
        self.status_code = status_code


# Client is created lazily (on first real call) rather than at import time.
# Reason: this module gets imported as soon as the Flask app is created
# (create_app -> routes/chat.py -> here), which means EVERY test in the
# project — even ones unrelated to chat — would fail at collection time
# if the API key weren't loaded yet. Building the client on first use avoids
# that, and tests that mock get_chat_reply() never trigger this at all.
_client = None


def _get_client():
    global _client
    if _client is None:
        _client = genai.Client(api_key=GEMINI_API_KEY)
    return _client


def _history_to_contents(history):
    """
    Convert our simple history format:
        [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    into the list of Content objects the Gemini SDK expects.

    Gemini calls the assistant's turns "model" rather than "assistant" —
    that's the one translation happening here.
    """
    contents = []
    for turn in history:
        text = (turn.get("content") or "").strip()
        if not text:
            continue
        role = "model" if turn.get("role") == "assistant" else "user"
        contents.append(types.Content(role=role, parts=[types.Part.from_text(text=text)]))
    return contents


def get_chat_reply(message: str, history: list | None = None, context_chunks: list | None = None) -> str:
    """
    Send one user message plus prior turns to Gemini, return the reply text.
    If context_chunks is provided (from RAG retrieval), they're appended to
    the system prompt with instructions to answer from them and cite the
    source. Raises GeminiServiceError on any failure.
    """
    history = history or []
    contents = _history_to_contents(history)
    contents.append(types.Content(role="user", parts=[types.Part.from_text(text=message)]))

    system_instruction = SYSTEM_PROMPT
    if context_chunks:
        context_block = _build_context_block(context_chunks)
        system_instruction = (
            SYSTEM_PROMPT + RAG_INSTRUCTIONS + "\n\n---\n" + context_block + "\n---"
        )

    try:
        response = _get_client().models.generate_content(
            model=MODEL_NAME,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                max_output_tokens=1024,
                temperature=0.7,
            ),
        )
    except APIError as e:
        logger.error("Gemini API error: %s", e)
        status = getattr(e, "code", None)
        if status == 429:
            raise GeminiServiceError(
                "AI service is busy right now — please try again in a moment.", 429
            )
        raise GeminiServiceError("AI service failed to respond.", 502)
    except Exception:
        logger.exception("Unexpected error calling Gemini")
        raise GeminiServiceError("AI service is temporarily unavailable.", 502)

    if not response or not getattr(response, "text", None):
        raise GeminiServiceError("AI service returned an empty response.", 502)

    return response.text

