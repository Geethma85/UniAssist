# UniAssist

An AI assistant for university students. Students chat with UniAssist about courses and campus information; admins upload official documents (policies, timetables, handbooks), and the assistant answers from those documents using retrieval-augmented generation (RAG). When the documents don't contain the answer, it says so instead of guessing.

> Portfolio project built to practise full-stack development, AI integration and testing.

| Home | Chat | Manage documents (admin) |
|---|---|---|
| ![Home](docs/screenshots/home.png) | ![Chat](docs/screenshots/chat.png) | ![Admin](docs/screenshots/admin-documents.png) |

## Live demo

[Open UniAssist](https://uniassist-5a787.web.app)

The web app works on desktop and mobile browsers. Sign up with email/password or continue with Google.

The demo uses eight fictional university PDFs. Their policies and dates are sample content, not official university information.

The backend scales to zero when idle, so the first request may take longer.

## Features

**Students**
- Email/password registration and login, plus Google sign-in on web and Android
- Chat with an assistant that answers from uploaded documents and admits uncertainty when it has no source
- Conversation history saved per user, with a full history screen and a recent-conversations list on Home

**Admins**
- Upload `.txt` and `.pdf` documents (validated, chunked, embedded and indexed)
- List indexed documents with upload date and chunk count
- Delete a document (all of its chunks are removed)
- Admin screen is reachable only for admin accounts in the UI, and every `/admin` route is also enforced on the backend

## How it works

```
Flutter app (Web / Android)
        |  HTTPS + Firebase ID token (Authorization: Bearer ...)
        v
Flask REST API (Azure Container Apps)
        |
        +--->  Firebase Auth (verify token)
        |
        +--->  Firestore (users, roles, chat history)
        |
        +--->  Azure AI Search (deployed) / ChromaDB (local)
        |      Document chunks + all-MiniLM-L6-v2 embeddings
        |
        +--->  Gemini API (answer generation)
```

1. An admin uploads a document. The backend extracts the text, splits it into 500-character chunks with 80 characters of overlap, embeds each chunk with `all-MiniLM-L6-v2`, and stores them in ChromaDB. Every upload gets its own `document_id` stored in each chunk's metadata, so two uploads with the same filename stay separate.
2. A student asks a question. The backend embeds it, retrieves the closest chunks (filtered by a distance threshold), and sends them to Gemini with a prompt that tells the model to say it doesn't know when the context doesn't cover the question.
3. The conversation is saved in Firestore, written by the backend only.

## Tech stack

| Layer | Tools |
|---|---|
| Frontend | Flutter (Dart), `http`, `file_picker`, `google_sign_in` |
| Backend | Python, Flask REST API, Gunicorn |
| Auth and data | Firebase Authentication (email/password and Google), Cloud Firestore |
| AI | Gemini API (`google-genai` SDK), RAG |
| Retrieval | `sentence-transformers` (`all-MiniLM-L6-v2`), Azure AI Search (deployed), ChromaDB (local) |
| Hosting | Firebase Hosting (web), Azure Container Apps (backend) |
| Container builds | Docker, GitHub Actions, GitHub Container Registry (GHCR) |
| Testing | pytest (54 tests passed with ChromaDB), Flutter tests, manual web and Android checks |

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
From the repository root, using Git Bash on Windows:

```bash
cd backend
python -m venv venv
./venv/Scripts/python.exe -m pip install -r requirements.txt
```

For a new setup, copy `.env.example` to `.env`. Keep an existing
`.env` rather than overwriting it.

Set these values in `backend/.env`:

```dotenv
GEMINI_API_KEY=your-key-here
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
```

Place your Firebase service-account JSON at the configured path.
Relative paths resolve from `backend/`. If the variable is blank or
unset, the default is `backend/serviceAccountKey.json`.

Never commit `.env` or the service-account file.

Start the backend:

```bash
./venv/Scripts/python.exe -m flask --app run run
```

In another terminal, verify startup:

```bash
curl http://127.0.0.1:5000/health
```

The response should contain `"status":"ok"`.

### Frontend

In a separate terminal, from the repository root:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```
This connects the local frontend to the deployed backend; local Flask is not required. For local backend development, use `--dart-define=API_BASE_URL=http://127.0.0.1:5000` instead.

The Firebase client config (`firebase_options.dart`) is generated with FlutterFire for your own Firebase project.

### Running on an Android phone

Enable Developer options and USB debugging, connect the phone, then run from `frontend/`:

```bash
flutter run --dart-define=API_BASE_URL=https://uniassist-backend-kr.salmonbay-88d80279.koreacentral.azurecontainerapps.io
```

If prompted, select the Android device. Once installed, the app connects to Azure over the internet and can be opened without the USB cable.

Google sign-in requires the Android package name and the signing certificate's SHA fingerprint to be registered in Firebase. The current Android setup was tested with a debug build.

- **USB (no shared Wi-Fi needed):** plug the phone in with USB debugging on, then
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
./venv/Scripts/python.exe -m pytest -v
```
The latest recorded backend run passed 54 tests using ChromaDB, covering authentication, chat, conversations, text extraction, chunking, retrieval and document management. Delete tests use a real in-memory ChromaDB.

Azure AI Search was checked manually through document upload, retrieval and deletion. Google sign-in and chat were also checked on web and Android.

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

## Roadmap
- Conversation deletion and rename
- Email verification and password reset
- Retrieval evaluation set to tune the threshold properly

## Project workflow
One feature per Git branch, merged into `main` by pull request once tested.