# AcademicOS — Master Execution Roadmap

**Updated:** 2026-11-22  
**Repository:** `EduNivora/AcademicOS`  
**Product boundary:** local-first academic workspace; accounts are optional; academic records and attachments stay on the user's device. No academic cloud sync is in scope.

This document is the continuity record for implementation. A feature is not complete because its screen exists or a local unit test passes. It is accepted only when the end-to-end workflow, data integrity, permissions, failure behavior, and supported-platform behavior have evidence tied to an exact commit.

## Current integration snapshot

- `main` baseline: `50dc34a2` (PR #44 merged).
- PR #50 (`qa/uiux-release-candidate`) is the current integration candidate. It contains the assistant preflight/ledger stack and responsive/accessibility work, including the fixes from PR #51. Its Flutter GitHub Actions run `44962687231` was still in progress at this update.
- PR #47 contains durable per-account Gemini quota enforcement. Its backend checks passed locally: 39 tests, 0 failures. Its Flutter workflow was cancelled, so it is not an accepted full CI result.
- PR #52 (`feat/assistant-postcondition-verification`) is stacked on the PR #50 candidate and adds read-after-write verification before the assistant ledger marks a mutation successful.
- No production migration, Neon deployment, APK/release build, or merge was performed as part of this work.

## Three engineering stages

### Stage 1 — Functional academic foundation and data lifecycle

**Goal:** every visible academic workflow must operate on durable, correctly related local data.

| Workstream | Current evidence | Remaining acceptance |
|---|---|---|
| Courses, tasks, exams, weekly schedule | Existing SQLite repositories, use cases, migrations and CRUD tests | Cross-module workflows, old-schema upgrade fixtures, error/retry behavior and device persistence |
| Course materials | Attachment bytes are stored as SQLite BLOBs; legacy temp-path migration copies verified bytes into the database; viewer consumes bytes | Restart/upgrade acceptance on Android and Web, large-file memory behavior, missing/corrupt legacy files and viewer tests |
| Backup/restore | Strict payload validation and v3 attachment-byte decoding exist in source | Backup UI/export/restore is Release 2 scope; do not expose it as accepted Release 1 functionality. Complete staged restore and failure injection before Release 2 acceptance |
| Notifications | Reminder scheduling is connected to tasks/courses/lectures | Deterministic scheduling tests, permission denial, reboot/restart, timezone/DST and physical-device delivery |
| Reports and study planning | Local report/planner code exists | Reconcile outputs to source records, date-boundary tests, persistence and lifecycle behavior |

**Exit condition:** representative student workflows create, update, link, reopen and delete the right records without orphaning data or losing attachment bytes.

### Stage 2 — Assistant as a safe execution engine

**Goal:** the assistant plans and executes allowed actions through application services, verifies persisted results, and never reports unverified success.

| Workstream | Current evidence | Remaining acceptance |
|---|---|---|
| Plan parsing and preflight | PR #45 validates allowlisted actions, references, conflicts and destructive operations before writes | Full regression on exact integrated head; test stale data between preflight and execution |
| Durable execution ledger | PR #48 records run/step states and recovers interrupted work without automatic replay | Verify restart recovery, partial failure, cancellation and user-visible history |
| Read-after-write verification | PR #52 adds stable affected-record IDs and re-reads courses, tasks, attachments, schedule, exams and profile before success | CI on the exact head; broaden negative tests for every mutation and prove the ledger stops dependent steps when verification fails |
| Gemini quotas | PR #47 reserves minute/day quotas atomically in PostgreSQL and fails closed | Apply migration only after review; verify deployment IDs, authenticated real-account requests, 429/503 behavior and cross-instance concurrency |
| Real Gemini operation | AI endpoint and Flutter integration exist | Configure secrets and trusted origins, test a real authenticated session, model response, tool plan, local execution, quota and failure behavior end to end |
| Permissions | Assistant is constrained to the signed-in user's app-level permissions | Verify each tool against account/role boundaries; no student assistant may gain university-wide administrative authority |

**Exit condition:** one user request can safely execute a multi-step local academic workflow, with confirmation for destructive actions, persisted-state verification, interruption recovery, and truthful reporting.

### Stage 3 — Security, reliability, UX and platform acceptance

**Goal:** make the integrated product safe, accessible and dependable on every platform it claims to support.

| Workstream | Current evidence | Remaining acceptance |
|---|---|---|
| UI/UX and accessibility | PR #49 and PR #51 fixes; 9 targeted accessibility tests pass locally | Physical screen sizes, Android screen reader, keyboard/focus navigation, localization and moderated usability review |
| Password storage | Argon2id verifier and legacy migration tests exist | Benchmark slow supported Android devices and browsers; verify secure-storage behavior on real targets |
| SQLite encryption at rest | **Not implemented in production.** Stored key is not wired to an encrypted production database engine | P0: choose a supported engine per platform, prove full app compatibility, key lifecycle and crash-safe migration/rollback. Never claim the current DB is encrypted |
| Backup security | Release 2 design boundary is documented | Encrypted complete archive, attachment bytes, checksums, atomic staged restore, rollback and cross-device recovery |
| Guest metrics abuse controls | Anonymous aggregate metrics exist | Rate limiting/abuse controls and monitoring without storing guest IDs, IPs or device fingerprints |
| API/auth isolation | Neon auth/JWT and role checks exist in source/tests | Live authenticated acceptance, account isolation, CORS/origin validation and deployment verification |
| Performance and stability | Automated tests and existing performance work | Measure cold start, memory, large attachments, database contention, offline/reconnect and long-running assistant plans |

**Exit condition:** all security-critical risks are either resolved with evidence or explicitly excluded from the supported release scope without misleading product claims.

## Mandatory release gates — do not skip

1. Exact-head GitHub Actions pass for the integration stack and all stacked PRs.
2. Full Flutter tests, backend tests, database migration tests and native SQLite emulator tests pass.
3. Real Android device acceptance: guest-first use, optional auth, offline persistence, attachments, reminders, assistant actions, app restart and accessibility.
4. Real authenticated Gemini acceptance with the approved server-side secret, quota migration and account isolation.
5. Web acceptance only if Web remains a supported target: IndexedDB persistence, refresh/reopen, offline behavior, file handling and CORS.
6. No unresolved P0 security issue may be silently waived. In particular, production SQLite encryption remains unimplemented and must be treated honestly.
7. Production signing, APK size and release artifact inspection happen only after all functional and security gates pass.

## Open blockers to retain in the work queue

- **#3 — P0 SQLite encryption at rest:** not implemented in production; no driver switch or user-data migration without a separate verified plan.
- **#4 — main branch protection:** repository-owner decision and configuration required; do not silently change policy.
- **#5 — backup/restore recovery:** Release 2 scope; attachment and database recovery must be proven together before acceptance.
- **#6 — Argon2id target performance:** implementation/tests exist; real-device/browser benchmarks remain.
- **#15 — attachment durability:** current source stores new attachment bytes in SQLite BLOBs and migrates eligible legacy temp files; verify old missing files, upgrade/restart behavior and Web limitations before closing.
- **#24 — guest announcement metrics abuse:** privacy-preserving abuse controls remain separate from Gemini quotas.
- **#37 — AI intelligence engine:** real provider configuration and authenticated end-to-end acceptance remain required.

## Working rules

- Do not build an APK just to demonstrate progress. Build/release work is deferred until the gates above are satisfied.
- Do not repeat completed work. Inspect the exact branch and tests before changing a module.
- Do not merge stacked PRs out of order. Preserve the dependency chain and validate the exact merged candidate.
- Do not apply Neon migrations or deploy functions to production without an explicit reviewed migration/deployment step.
- Do not store prompts, academic context, file bytes, or raw error text in the assistant execution ledger.
- A failed postcondition means the step is failed/uncertain, changed-data status is preserved, and dependent steps stop. Never blindly replay an interrupted write.
- Update this roadmap and the feature acceptance matrix whenever a workstream changes status.
