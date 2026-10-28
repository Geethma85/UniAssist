# Retrieval and answer-quality evaluation

Verified during 25–26 October 2026.

## Implementation

- Explicit cosine distance, with incompatible-collection detection.
- Active collection: `documents_cosine_v1`.
- Empty collections handled; requested results capped to available chunks.
- Source document and chunk identifiers preserved.
- Grounding rules apply with and without retrieved context.
- General study advice allowed without university evidence.
- Source labels validated and mapped to filenames.
- Grouped citations normalized before validation.

## Verification

Backend suite: 42 passed.

Manual checks using fictional demo documents:

| Scenario | Observed result |
|---|---|
| General exam advice | General guidance without unnecessary campus rules |
| Unsupported 2027 tuition fee | No invented fee or misleading citation |
| Book borrowing question | Four books for fourteen days, with source labels |
| Incorrect borrowing premise | Corrected five books/three weeks to the documented limit |
| Borrowing plus missing late fee | Answered supported portion; acknowledged missing fine |
| Unsupported tuition assumption in history | Did not treat the assumption as confirmed |
| Instructions embedded in uploaded document | Used help-desk fact; ignored tuition instruction |
| Question after deleting test document | No longer supplied the deleted help-desk hours |
| Scholarship deadline plus study advice | Acknowledged missing deadline and provided general advice |

Screenshots demonstrate observed answer behavior. Citation-to-excerpt support has not yet been independently audited for every answer.

## Index migration

For an existing installation using the original `documents` collection:

1. Stop the backend and back up `backend/chroma_data`.
2. Activate the backend virtual environment.
3. From `backend`, run `python migrate_cosine.py`.
4. Confirm source and destination chunk counts match.
5. Start the backend using `documents_cosine_v1`.

The script preserves the original collection and copies existing embeddings, text, IDs, and metadata. It is a one-time migration: an existing destination causes creation to fail. If interrupted, do not delete either collection blindly; inspect the partial destination before retrying.

Fresh installations create the cosine collection automatically.

## Remaining work

- Cutoff 0.8 is provisional; lower distance means closer matches, not confidence.
- Top-k remains 3. Alternative cutoffs and top-k values have not been compared.
- Expand the evaluation corpus and add held-out questions.
- Investigate two visibly incomplete live replies.
- Improve migration rerun/recovery handling.
- Complete chat validation and service-failure handling, then conversation deletion.