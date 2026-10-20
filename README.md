# UniAssist

An AI assistant for university students. Students chat with UniAssist about courses and campus information; admins upload official documents (policies, timetables, handbooks), and the assistant answers from those documents using retrieval-augmented generation (RAG). When the documents don't contain the answer, it says so instead of guessing.

> Portfolio project built to practise full-stack development, AI integration and testing.

<!-- TODO: add 3 screenshots to docs/screenshots/, then delete this line and the two comment markers around the table
| Home | Chat | Manage documents (admin) |
|---|---|---|
| ![Home](docs/screenshots/home.png) | ![Chat](docs/screenshots/chat.png) | ![Admin](docs/screenshots/admin-documents.png) |
-->


## Features

**Students**
- Email/password sign-up and login (Firebase Authentication)
- Chat with an assistant that answers from uploaded documents and admits uncertainty when it has no source
- Conversation history saved per user, with a full history screen and a recent-conversations list on Home

**Admins**
- Upload `.txt` and `.pdf` documents (validated, chunked, embedded and indexed)
- List indexed documents with upload date and chunk count
- Delete a document (all of its chunks are removed)
- Admin screen is reachable only for admin accounts in the UI, and every `/admin` route is also enforced on the backend

## How it works

```
Flutter app (Chrome / Android)
        |  HTTPS + Firebase ID token (Authorization: Bearer ...)
        v
Flask REST API  --->  Firebase Auth (verify token)  --->  Firestore (users, roles, chat history)
        |
        +--->  ChromaDB (document chunks + embeddings, all-MiniLM-L6-v2)
        |
        +--->  Gemini API (answer generation, google-genai SDK)
```

1. An admin uploads a document. The backend extracts the text, splits it into 500-character chunks with 80 characters of overlap, embeds each chunk with `all-MiniLM-L6-v2`, and stores them in ChromaDB. Every upload gets its own `document_id` stored in each chunk's metadata, so two uploads with the same filename stay separate.
2. A student asks a question. The backend embeds it, retrieves the closest chunks (filtered by a distance threshold), and sends them to Gemini with a prompt that tells the model to say it doesn't know when the context doesn't cover the question.
3. The conversation is saved in Firestore, written by the backend only.

## Tech stack

| Layer | Tools |
|---|---|
| Frontend | Flutter (Dart), `http`, `file_picker` |
| Backend | Python, Flask REST API |
| Auth and data | Firebase Authentication, Cloud Firestore |
| AI | Gemini API (`google-genai` SDK), RAG |
| Retrieval | `sentence-transformers` (`all-MiniLM-L6-v2`), ChromaDB |
| Testing | pytest (29 tests) |

## API overview

All routes except `/health` require a Firebase ID token.

| Method | Route | Access | Purpose |
|---|---|---|---|
| GET | `/health` | public | Health check |
| POST | `/chat` | signed-in | Ask a question (RAG-enabled) |
| GET | `/conversations` | signed-in | List my conversations |
| GET | `/conversations/<id>` | signed-in | Messages of one conversation |
| POST | `/admin/documents/upload` | admin | Upload and index a `.txt` / `.pdf` |
| GET | `/admin/documents` | admin | List indexed documents |
| DELETE | `/admin/documents/<doc_id>` | admin | Delete a document (404 if unknown) |

## Getting started

<!-- TODO: verify every command in this section on a clean checkout -->

### Prerequisites
- Python 3.13, Flutter SDK, a Firebase project (Authentication + Firestore), a Gemini API key

### Backend
```bash
cd backend
python -m venv venv
source venv/Scripts/activate      # Windows (Git Bash). On macOS/Linux: source venv/bin/activate
pip install -r requirements.txt   # TODO: confirm this file exists
```
Create `backend/.env` (never commit it):
```
GEMINI_API_KEY=your-key-here
# TODO: add the variable your Firebase Admin setup reads (service account path?)
```
Run it:
```bash
flask run
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

The Firebase client config (`firebase_options.dart`) is generated with FlutterFire for your own Firebase project.

### Running on an Android phone
`localhost` on a phone means the phone itself, so the app needs a route to your computer.

- **USB (no network needed):** plug the phone in with USB debugging on, then
  ```bash
  adb reverse tcp:5000 tcp:5000
  flutter run -d <device-id>
  ```
- **Same Wi-Fi or hotspot:** start Flask with `flask run --host=0.0.0.0`, then
  ```bash
  flutter run -d <device-id> --dart-define=API_BASE_URL=http://<your-computer-ip>:5000
  ```

### Making an account an admin
Admin accounts are set manually: in Firestore, open `users/<uid>` and set the string field `role` to `admin`. New sign-ups default to `student`.

## Testing

```bash
cd backend
pytest -v
```

29 tests cover auth middleware, chat, conversations, text extraction, chunking, the vector store, and document management. The delete tests run against a real in-memory ChromaDB, so the real delete code executes (a mocked delete would pass even if the code were broken). I also checked that a deliberately broken delete makes the test fail.

## Design decisions

- **Documents are identified by a generated `document_id`, not the filename.** ChromaDB stores chunks, so each upload gets a UUID in every chunk's metadata. Duplicate filenames can't be confused, and delete removes exactly one upload.
- **The backend is the security boundary.** The Flutter UI hides admin features from students for convenience only; `@require_admin` checks the role on every admin request.
- **Fail closed on roles.** If the app can't read the role, it behaves as a student.
- **Uploads send file bytes, not paths**, so the same code works on web and mobile.
- **Honest answers over confident ones.** The prompt tells the model to say it lacks information when no retrieved chunk is relevant.

## Known limitations

- The document list groups chunks in Python on every request; at larger scale, keep a documents collection in Firestore
- The retrieval distance threshold (0.8) was tuned against a single document and should be re-tuned with more data
- No conversation deletion
- No email verification at sign-up
- The Gemini free tier can rate-limit; the app then shows a generic error
- Backend runs locally; no deployment yet

## Roadmap
- Deploy the backend and point `API_BASE_URL` at it
- Conversation deletion and rename
- Email verification and password reset
- Retrieval evaluation set to tune the threshold properly

## Project workflow
One feature per Git branch, merged into `main` by pull request once tested.