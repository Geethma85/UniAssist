from firebase_admin import firestore

TITLE_MAX = 40
PREVIEW_MAX = 80
VALID_ROLES = {"user", "model"}


def _conversations_ref(uid):
    # uid must come from the verified token, never from the request body.
    db = firestore.client()
    return db.collection("users").document(uid).collection("conversations")


def create_conversation(uid, first_message):
    """Create a new conversation doc and return its id."""
    ref = _conversations_ref(uid).document()  # auto-generated id
    ref.set({
        "title": first_message.strip()[:TITLE_MAX],
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "lastMessagePreview": "",
    })
    return ref.id


def save_message(uid, conversation_id, role, text):
    """Save one message and update the conversation's preview, atomically."""
    if role not in VALID_ROLES:
        raise ValueError(f"Invalid role: {role}")

    convo_ref = _conversations_ref(uid).document(conversation_id)
    msg_ref = convo_ref.collection("messages").document()

    batch = firestore.client().batch()
    batch.set(msg_ref, {
        "role": role,
        "text": text,
        "createdAt": firestore.SERVER_TIMESTAMP,
    })
    batch.update(convo_ref, {
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "lastMessagePreview": text[:PREVIEW_MAX],
    })
    batch.commit()
    
def get_recent_messages(uid, conversation_id, limit=20):
    """Return the last `limit` messages oldest-first, or None if the
    conversation doesn't exist under this user."""
    convo_ref = _conversations_ref(uid).document(conversation_id)
    if not convo_ref.get().exists:
        return None  # route turns this into a 404

    docs = (
        convo_ref.collection("messages")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )
    messages = [{"role": d.get("role"), "text": d.get("text")} for d in docs]
    messages.reverse()  # we fetched newest-first, Gemini wants oldest-first
    return messages