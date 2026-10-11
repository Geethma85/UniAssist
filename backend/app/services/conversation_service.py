from firebase_admin import firestore

TITLE_MAX = 40
PREVIEW_MAX = 80
VALID_ROLES = {"user", "assistant"}


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


def save_message(uid, conversation_id, role, content):
    """Save one message and update the conversation's preview, atomically."""
    if role not in VALID_ROLES:
        raise ValueError(f"Invalid role: {role}")

    convo_ref = _conversations_ref(uid).document(conversation_id)
    msg_ref = convo_ref.collection("messages").document()

    batch.set(msg_ref, {
        "role": role,
        "content": content,
        "createdAt": firestore.SERVER_TIMESTAMP,
    })
    batch.update(convo_ref, {
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "lastMessagePreview": content[:PREVIEW_MAX],
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
    messages = [{"role": d.get("role"), "content": d.get("content")} for d in docs]    
    messages.reverse()  # we fetched newest-first, Gemini wants oldest-first
    return messages

def _iso(ts):
    # Firestore timestamps aren't JSON-serialisable, so convert to a string.
    return ts.isoformat() if ts else None


def list_conversations(uid, limit=50):
    """Return the user's conversations, newest first. Empty list if none."""
    docs = (
        _conversations_ref(uid)
        .order_by("updatedAt", direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )
    result = []
    for d in docs:
        data = d.to_dict()
        result.append({
            "id": d.id,
            "title": data.get("title", ""),
            "lastMessagePreview": data.get("lastMessagePreview", ""),
            "updatedAt": _iso(data.get("updatedAt")),
        })
    return result


def get_conversation(uid, conversation_id):
    """Return one conversation with all its messages, or None if it
    doesn't exist under this user."""
    convo_ref = _conversations_ref(uid).document(conversation_id)
    snap = convo_ref.get()
    if not snap.exists:
        return None

    docs = convo_ref.collection("messages").order_by("createdAt").stream()
    messages = []
    for d in docs:
        data = d.to_dict()
        messages.append({
            "id": d.id,
            "role": data.get("role"),
            "content": data.get("content"),
            "createdAt": _iso(data.get("createdAt")),
        })
    return {"id": snap.id, "title": snap.to_dict().get("title", ""), "messages": messages}