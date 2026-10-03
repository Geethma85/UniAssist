import pytest
from app.services.text_extraction import extract_text, ExtractionError


def test_rejects_wrong_file_type():
    with pytest.raises(ExtractionError, match="Unsupported"):
        extract_text("notes.docx", b"hello")


def test_rejects_empty_file():
    with pytest.raises(ExtractionError, match="empty"):
        extract_text("notes.txt", b"")


def test_rejects_oversized_file():
    big = b"a" * (10 * 1024 * 1024 + 1)
    with pytest.raises(ExtractionError, match="10MB"):
        extract_text("big.txt", big)


def test_reads_a_txt_file():
    assert extract_text("policy.txt", b"Appeals within 14 days.") == "Appeals within 14 days."


def test_rejects_fake_pdf():
    with pytest.raises(ExtractionError, match="PDF"):
        extract_text("fake.pdf", b"this is not really a pdf")