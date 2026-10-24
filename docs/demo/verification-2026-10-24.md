# Verification — 24 October 2026

Branch: fix/firebase-config-and-demo
Starting commit: 0649ef066f07535ab0434a89ed9e7813cb9d212b.

## Passed
- Backend baseline: 33 tests.
- Backend after credential-path changes: 33 tests.
- Flutter login-screen test: 1 passed after deferring Firebase access
  and correcting two login layout overflows.
- Backend startup and GET /health.
- Chrome app startup and login.
- General study advice: successful after retry.
- Fictional document upload and listing.
- Direct document question: correct library hours and filename citation.
- Paraphrased question: four books for fourteen days, with citation.
- Unsupported scholarship question: no invented deadline.
- Conversation history retained all three exchanges.
- Temporary document upload/list/delete; main demo guide preserved.

## Failed, then resolved
- Original Flutter test failed because Firebase was accessed during
  AuthService construction.
- Subsequent test exposed two login layout overflows.
- Initial live chat failed: Gemini returned 503; retry succeeded.

## Remaining / unconfirmed
- Latest recorded Flutter analysis: 23 informational notices.
  Analysis has not yet been repeated after the layout edits.
- Clean-environment dependency installation has not been verified.
- pip install / pip check No broken requirements found .
- Paraphrased retrieval in a separate fresh conversation is unconfirmed.
- Student-only admin visibility has not been explicitly verified.
- Android setup instructions have not been tested today.

## Demo questions and expected criteria
1. When does Example Horizon University's library open on weekdays?
   Monday–Friday, 08:30–18:00; cite fictional-university-guide.txt.
2. At Example Horizon University, how many library books can I take
   home, and how long can I keep them?
   Four books, fourteen days; cite the guide.
3. What is Example Horizon University's scholarship application deadline?
   Admit the information is unavailable; invent no deadline.
4. How can I plan revision for three exams next week?
   Practical general advice; invent no university policy.

## Following days
- Retrieval: evaluate fresh conversations, paraphrases, unsupported
  questions, distractor documents, and citation accuracy.
- Reliability: distinguish Gemini outages from connection errors;
  consider bounded retries and verify history-save failure behavior.
- Security: review role enforcement, per-user access, upload validation,
  Firestore rules, and secret handling.
- Deployment: verify fresh installation and production configuration
  before choosing hosting.

## Recommended 25 October task
Evaluate retrieval and citations with a small repeatable question set,
then improve misleading chat error messages.

PR #15 opened. No deployment or Firestore-record deletion performed.