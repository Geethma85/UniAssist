from pypdf import PdfReader
import io

MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_EXTENSIONS = {".txt", ".pdf"}


class ExtractionError(Exception):
    """Raised when a file can't be validated or read."""
    pass


def validate_file(filename: str, file_bytes: bytes) -> None:
    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise ExtractionError(f"Unsupported file type '{ext}'. Only .txt and .pdf are allowed.")
    if len(file_bytes) == 0:
        raise ExtractionError("Uploaded file is empty.")
    if len(file_bytes) > MAX_FILE_SIZE_BYTES:
        raise ExtractionError("File exceeds the 10MB size limit.")


def extract_text(filename: str, file_bytes: bytes) -> str:
    validate_file(filename, file_bytes)
    ext = filename.rsplit(".", 1)[-1].lower()

    if ext == "txt":
        try:
            text = file_bytes.decode("utf-8")
        except UnicodeDecodeError:
            raise ExtractionError("Could not read text file (unsupported encoding).")
    else:  # pdf
        try:
            reader = PdfReader(io.BytesIO(file_bytes))
            text = "\n".join(page.extract_text() or "" for page in reader.pages)
        except Exception:
            raise ExtractionError("Could not read PDF file (corrupt or unsupported format).")

    text = text.strip()
    if not text:
        raise ExtractionError("No readable text found in file (scanned PDF with no text layer?).")

    return text