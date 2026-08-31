# UniAssist 🎓

An AI-powered university student assistant that answers general academic questions and provides accurate, source-grounded answers from institutional documents using Retrieval-Augmented Generation (RAG).

---

##  Overview

UniAssist lets students chat with an AI assistant about academic and university-related questions. It combines two response modes:

- **General questions** → answered directly by an LLM (Google Gemini)
- **University-specific questions** (module handbooks, academic regulations, exam guidelines, etc.) → answered using a **RAG pipeline**, where admin-uploaded documents are chunked, embedded, and retrieved to ground the AI's answer in real institutional content, with sources shown

The app supports two roles — **Student** and **Admin** — with role-based access control enforced on both the frontend and backend.

---

##  Features

- 🔐 Secure authentication (Firebase Auth) with role-based access control
- 💬 Conversational AI chatbot with context-aware, multi-turn conversations
- 📚 Retrieval-Augmented Generation (RAG) for document-grounded answers with cited sources
- 🗂️ Admin document management (upload, view, delete institutional documents)
- 🕘 Persistent chat history per user
- 🛡️ Firestore security rules preventing unauthorized data access and role self-escalation
- ✅ Backend test coverage (pytest) for auth, validation, and core logic

> Some features above are in progress — see [Project Status](#-project-status) for what's shipped vs. planned.

---

##  Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Python, Flask (REST API) |
| Authentication | Firebase Authentication |
| Database | Firebase Firestore |
| AI / LLM | Google Gemini API (free tier) |
| RAG / Embeddings | `sentence-transformers` (local embeddings) |
| Vector Database | ChromaDB |
| API Testing | Postman |
| Backend Testing | pytest |
| Version Control | Git / GitHub |

---

##  Architecture

```
Flutter App
     ↓
Flask REST API  (@require_auth / @require_admin middleware)
     ↓
Service Layer
     ↓
AI / RAG Layer  →  Gemini API + ChromaDB (vector search)
     ↓
Firebase (Auth + Firestore)
```

The frontend never exposes secret API keys — all AI/service calls are routed through the Flask backend, which holds credentials in environment variables.

---

##  Project Structure

```
uniassist/
├── backend/
│   ├── app/
│   │   ├── routes/        # API route definitions
│   │   ├── services/      # Business logic (auth, chat, RAG)
│   │   └── models/        # Data models
│   ├── tests/              # pytest test suite
│   ├── .env                # Environment variables (gitignored)
│   ├── requirements.txt
│   └── run.py
├── frontend/
│   └── lib/
│       ├── screens/        # App screens (login, chat, profile, admin, etc.)
│       ├── widgets/        # Reusable UI components
│       └── services/       # API/Firebase client calls
├── docs/                   # Additional project documentation
└── README.md
```

---

##  Security

- API keys and service account credentials stored in environment variables, never committed to source control
- Firestore security rules restrict users to reading/writing only their own data, with the `role` field locked from client-side modification after account creation (prevents self-promotion to admin)
- Backend routes protected by custom `@require_auth` and `@require_admin` decorators that verify Firebase ID tokens server-side
- Input validation on all endpoints (message length, empty input, file type/size on uploads)
- Generic, non-revealing error messages returned to clients; detailed errors logged server-side only
- Login errors intentionally generic (e.g. wrong password vs. unknown account) to prevent user enumeration

---

##  Getting Started

### Prerequisites
- Flutter SDK
- Python 3.10+
- A Firebase project (Authentication + Firestore enabled)
- A free [Google Gemini API key](https://aistudio.google.com/)

### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file in `backend/`:
```
GEMINI_API_KEY=your_key_here
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FLASK_ENV=development
```

Place your Firebase service account key at `backend/serviceAccountKey.json` (never committed — see `.gitignore`).

Run the server:
```bash
python run.py
```

### Frontend Setup
```bash
cd frontend
flutter pub get
flutterfire configure   # connects the app to your Firebase project
flutter run
```

---

##  Testing

Backend logic is tested with `pytest` as each feature is built, covering:
- Authentication middleware (missing/invalid/malformed tokens)
- Input validation
- Core API endpoint behavior

Run tests:
```bash
cd backend
pytest
```

API endpoints are additionally tested manually via **Postman** for request/response correctness, authorization enforcement, and error handling.

---

##  Project Status

This project is being built incrementally over a ~2-week MVP sprint. Current progress:

**✅ Done**
- Project structure and Git repository
- Firebase Authentication (register, login, logout) — Flutter ↔ Firebase
- Firestore security rules deployed and verified
- Flask backend token verification middleware (`@require_auth`, `@require_admin`)
- User profile screen wired to real Firestore data
- Basic pytest coverage for auth middleware

**✅ Done**
- Chatbot endpoint (Gemini API integration) and chat UI

**📋 Planned**
- RAG pipeline: document upload, chunking, embeddings, ChromaDB retrieval
- Chat history persistence (Firestore)
- Admin panel (document management, basic stats)
- Expanded test coverage and Postman collection
- Deployment

---

##  Known Limitations

- Uses the Gemini API free tier, which has request-rate limits unsuitable for high-traffic production use
- Google Sign-In and password reset are UI placeholders, not yet functional
- Firestore free tier / test-mode constraints mean this is a prototype, not a production-hardened deployment

---

##  Future Improvements

- Add automated CI test runs on push
- Expand RAG to support more document types beyond PDF/text
- Add real-time chat sync
- Performance testing under concurrent load
- Migrate to a paid LLM tier for production-grade rate limits

---

## 📄 License

This project is for educational and portfolio purposes.
