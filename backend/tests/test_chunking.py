from app.services.chunking import chunk_text


def test_empty_text_returns_no_chunks():
    assert chunk_text("") == []
    assert chunk_text("   ") == []


def test_short_text_is_a_single_chunk():
    assert chunk_text("Short policy text.") == ["Short policy text."]


def test_long_text_is_split_and_respects_size():
    text = " ".join(f"word{i}" for i in range(300))
    chunks = chunk_text(text, chunk_size=500, overlap=80)
    assert len(chunks) > 1
    assert all(len(c) <= 500 for c in chunks)


def test_neighboring_chunks_overlap():
    text = " ".join(f"word{i}" for i in range(300))
    chunks = chunk_text(text, chunk_size=500, overlap=80)
    # the end of chunk 0 must reappear at the start of chunk 1
    assert chunks[0][-30:] in chunks[1]