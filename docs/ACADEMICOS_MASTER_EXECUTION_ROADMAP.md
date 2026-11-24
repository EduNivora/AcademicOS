# AcademicOS — Master Execution Roadmap

**Updated:** 2026-11-22  
**Repository:** `EduNivora/AcademicOS`  
**Product boundary:** local-first academic workspace; accounts are optional; academic records and attachments stay on the user's device. No academic cloud sync is in scope.

This document is the continuity record for implementation. A feature is not complete because its screen exists or a local unit test passes. It is accepted only when the end-to-end workflow, data integrity, permissions, failure behavior, and supported-platform behavior have evidence tied to an exact commit.

## Current integration snapshot — revalidated 2026-11-24

- Repository: `EduNivora/AcademicOS`. Main baseline is `989ad5212971097df868dabab557c1c076d91720`. QA candidate includes PR #56's strict Bash `set -euo pipefail` fix, merged as `b0faf98777d482baf01cee18df198611ebe420e5` after exact-head CI run #45439852629 succeeded, including native Android SQLite verification.
- PR #55's prior branch is retained as historical source, not merged: it diverged from the updated QA base. This rebased candidate reapplies its seven application/test/documentation files on top of the current QA head and deliberately retains QA's stronger Flutter workflow unchanged. The new candidate requires its own exact-head CI; no earlier test result is being carried forward as proof.
- PR #47 Gemini quota work: backend run #44909953287 passed 39/39 tests and built the AI Function bundle. Its Flutter run #44909953393 was cancelled during Android SQLite verification; a retry is running. Migration 0003 was checked on an isolated Neon child branch only. Production schema remains untouched; do not deploy before migration review and authenticated acceptance.
- PR #53 guest-metrics gateway: exact-head backend run #45271485684 and Flutter run #45271485543 both succeeded, including native Android SQLite, Android Debug APK, and Web Release builds. It remains a deployment-gated draft: live Cloudflare Worker is still the older counter implementation, Worker/Neon shared secrets are not configured, and the coordinated proxy smoke tests have not been completed. Do not merge or deploy the client URL change yet.
- PR #57 fixes the `main` Flutter test pipefail behavior. Exact head `2fdafc0aa7ef95c6e49e0e95038e396152482a08`; run #45441851211 passed analysis and Flutter tests but Android SQLite verification is still running. Do not merge until the full run succeeds.
- PR #58 strengthens attachment persistence by closing SQLite before reading the BLOB back. Exact head `877e7c637c263c0c3eedfd984aa26e8d260f8faf`; run #45442534122 passed analysis and Flutter tests, while native Android SQLite verification is still running. No merge until exact-head CI completes.
- Mainline baseline run #45433357599 succeeded for Dart analysis, Flutter tests, Android SQLite emulator, Android Debug APK, and Web Release. It did not produce a signed production ARM64 APK; signing remains owner-gated.
- Real-account Android authentication, production Gemini requests, first-admin bootstrap, production migrations/deployments, physical-device notification delivery, Web runtime persistence, and production signing remain unaccepted. No production secrets, migrations, or deployments were changed in this session.

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
| Read-after-write verification | PR #52 exact head `944cb8b6870dad9be35610305a458bcfafdf3b37` passed runs [#45228506846](https://github.com/EduNivora/AcademicOS/actions/runs/45228506846) and [#45228491790](https://github.com/EduNivora/AcademicOS/actions/runs/45228491790): 202 Flutter tests and Dart analysis. Tests cover persisted course/task updates, task completion/deletion, and exact attachment-byte comparison with corruption rejection | Expand negative verification coverage for every mutation; review stacked integration and run Android SQLite emulator/release gates before merge |
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

- PR #54 (`test/durable-course-attachment-persistence`) corrected its BLOB regression test to pass `Uint8List` to SQLite FFI and its Flutter test step now uses explicit Bash `pipefail`, so test failures cannot be hidden by `tee`. Exact-head run [#45230823383](https://github.com/EduNivora/AcademicOS/actions/runs/45230823383) passed analysis and unit tests; native Android SQLite emulator verification remains in progress.
