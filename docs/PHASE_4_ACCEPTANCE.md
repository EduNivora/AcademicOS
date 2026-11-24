# Phase 4 — Academic Assistant Acceptance

Target branch: feat/phase4-secure-academic-assistant-execution  
Base: Phase 3 branch feat/phase3-document-viewer-rearchitecture  
Product boundary: local-first academic records; Gemini is a remote planner/answering service, not a database executor.

## Acceptance matrix

| Requirement | Implementation in this branch | Status / evidence required |
|---|---|---|
| Inspect current assistant and PR #59 | Reviewed PR #59 and ported postcondition verification without importing its stacked QA preflight/ledger changes wholesale | Implemented; exact-head CI required |
| Model cannot access database directly | Gemini returns an untrusted plan; local allowlisted executor uses existing repositories/SQLite only | Implemented by architecture and code review |
| Fixed action allowlist | Executor switch plus per-action argument-key allowlist; unknown/identity/owner fields rejected | Implemented; unit tests cover identity-field rejection |
| Input validation | Bounded strings, attachment bytes, numeric/date/boolean type checks | Implemented; exact-head CI required |
| Postcondition verification | Read-after-write checks for courses, profile, attachments, tasks, lectures, exams and deletes | Implemented; exact-head CI required |
| Truthful success reporting | succeeded state plus postcondition check; failed steps stop the remaining action plan | Implemented; exact-head UI and test evidence required |
| Destructive confirmation | Course cascade, task, lecture and exam deletion require confirmation | Implemented in executor |
| Major update confirmation | Profile, course, task, lecture and exam updates require confirmation | Implemented; regression tests updated for profile/course/exam |
| Duplicate protection | Equivalent task, attachment, lecture and exam creation is checked before insert; course duplicate guard already existed | Implemented with targeted tests; not a durable execution ledger |
| Local data ownership | Mutations stay in local SQLite and use existing application services; model-supplied owner IDs are rejected | Implemented within local-first boundary; does not provide server-side tenant isolation |
| Server identity | Neon AI function verifies Neon Auth JWT signature/issuer/audience/expiry/UUID subject | Existing verifier retained; server tests required |
| Gemini key isolation | Runtime secret remains on Neon Function; no client key added | Implemented by existing server boundary; no secret was created or changed |
| Per-account quotas | Atomic PostgreSQL minute/day reservations, fail-closed database behavior, 429 + Retry-After | Implemented in source; migration 0003 not applied and function not deployed |
| Cloudflare guest metrics | Not used for academic assistant execution or quota enforcement | Kept separate; no Cloudflare change |
| Prompt injection | Document content is not sent to Gemini; action output remains constrained by allowlists and confirmations | Implemented at current data boundary; adversarial tests should be expanded |
| Conversation history | Current chat messages are in-memory for the screen session | Not implemented as durable history; not claimed |
| Durable action ledger | No persisted operation receipt across process death | Not implemented; follow-up before crash-safe multi-step execution |
| Real account / production acceptance | Requires real Neon Auth session and configured Gemini runtime | Not run; owner-gated |

## Test commands

The following are the CI commands configured for this branch; they are not claimed as locally executed:

- flutter pub get
- dart format --output=none --set-exit-if-changed .
- flutter analyze --no-pub --no-fatal-infos
- flutter test --no-pub
- npm run check
- npm test
- npm run build:ai

The backend test suite uses an injected fake PostgreSQL pool; it does not connect to production. Flutter database tests use the repository's test database path.

## Owner approvals and remaining gates

1. Review migration 0003 and apply it only to an approved Neon branch after isolated child-branch validation.
2. Deploy the updated Neon AI function only after the migration is present and required runtime variables are verified.
3. Test a real authenticated account through /health, /v1/chat, and /v1/schedule/parse; verify 429 and fail-closed 503 behavior.
4. Confirm that the product's local-first account model is acceptable. If multiple accounts can share one installation, implement local data partitioning before claiming account-level isolation.
5. Decide whether durable chat history and a crash-safe assistant action ledger are required for Release 1.
6. Expand adversarial tests for ambiguous entities, malformed model plans, stale references, and partial multi-step failure.

No production migration, secret mutation, Neon deployment, Cloudflare deployment, or main-branch merge is performed by this PR.
