def chunk_text(text: str, chunk_size: int = 500, overlap: int = 80) -> list[str]:
    """Split text into overlapping chunks, preferring paragraph/sentence breaks."""
    text = text.strip()
    if not text:
        return []

    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))

        # If we're not at the end of the text, try to cut at a natural break
        if end < len(text):
            window = text[start:end]
            # Look for the last paragraph break, then sentence end, in the window
            cut = max(window.rfind("\n\n"), window.rfind(". "))
            # Only use it if it's not too early (keeps chunks reasonably sized)
            if cut > chunk_size // 2:
                end = start + cut + 1

        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)

        if end >= len(text):
            break
        # Step forward, keeping `overlap` characters from the previous chunk
        start = max(end - overlap, start + 1)

    return chunks

"""
in plain terms:
Take a 500-character window.
Try to shorten it so it ends at a paragraph break or the end of a sentence (". "), as long as that doesn't make the chunk 
less than half the target size.
Save the chunk, then move the start point forward, but step back by 80 characters so the next chunk overlaps the previous one.
The max(..., start + 1) is a safety guard so the loop always moves forward and can never get stuck.
"""

