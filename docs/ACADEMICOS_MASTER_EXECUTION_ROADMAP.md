# AcademicOS — Master Execution Roadmap

**Updated:** 2026-11-22  
**Repository:** `EduNivora/AcademicOS`  
**Product boundary:** local-first academic workspace; accounts are optional; academic records and attachments stay on the user's device. No academic cloud sync is in scope.

This document is the continuity record for implementation. A feature is not complete because its screen exists or a local unit test passes. It is accepted only when the end-to-end workflow, data integrity, permissions, failure behavior, and supported-platform behavior have evidence tied to an exact commit.

## Current integration snapshot — live revalidation 2026-11-23

- `main` baseline: `50dc34a2ae62d35e9d7eac0cbaa66f6a9b4538c0` (PR #44 merged). The mainline CI evidence remains historical and does not prove the newer stacked candidates.
- PR #50 (`qa/uiux-release-candidate`) current head `b3efbf629f6759f28da129ec176e20c1e8d8f683` contains the assistant preflight/ledger stack, responsive/accessibility work, 200% text-scale checks, Android attachment BLOB persistence integration, bounded emulator retries, and a strict `bash`/`pipefail` Flutter test step. Exact-head run [#45230841502](https://github.com/EduNivora/AcademicOS/actions/runs/45230841502) has passed analysis and the full unit test step; native Android SQLite emulator verification is still in progress. No signed release artifact is implied.
- PR #55 (`feat/assistant-postcondition-verification-current-qa`) is the active, cleanly restacked assistant candidate based on QA head `2280186caa59485047116a5123efc0febb070834`. Exact head `fff3a21ae7fa59646e1324b91d0dd098a4b1f37a` passed [Assistant safety quality run #45232872758](https://github.com/EduNivora/AcademicOS/actions/runs/45232872758): **203 Flutter tests passed** and Dart static analysis succeeded. It verifies persisted course/task/attachment/schedule/exam/profile changes, exact attachment bytes, task-course relationships, normalized reminder values, lecture add/update/confirmed-delete, and stops dependent plan steps when a postcondition fails. It also removes invalid `course_name` writes to the schedule table and sanitizes imported schedule rows before SQLite batch insert. PR #55 remains Draft pending the parent QA Android emulator and release build gates. Old PR #52 is preserved but superseded because its base diverged by seven commits; do not merge it.
- PR #47 (`feat/ai-durable-account-quotas`) head `ec52bd9d4cd8d96958729963b27774c9d8ed0de3` passed Neon backend CI [#44909953287](https://github.com/EduNivora/AcademicOS/actions/runs/44909953287): 39/39 Node tests and AI Function bundle build passed. Its Flutter run [#44909953393](https://github.com/EduNivora/AcademicOS/actions/runs/44909953393) was cancelled during native SQLite emulator verification after analysis/tests had passed. The quota migration was exercised on an isolated Neon child branch and its columns, primary key, foreign key, check constraints and indexes were verified. The production branch still has no `public.ai_usage_windows` table; do not deploy this function before a reviewed migration.
- PR #53 (`feat/guest-metrics-edge-gateway-mainline`) is a mainline-based draft. Its design uses atomic Durable Object transactions for per-announcement and global daily ceilings and stores aggregate counters only. Backend CI [#45230845771](https://github.com/EduNivora/AcademicOS/actions/runs/45230845771) passed on exact head `4511d567e371c890ea69f52a95d5614507b69853`; Flutter quality run [#45230845975](https://github.com/EduNivora/AcademicOS/actions/runs/45230845975) has passed analysis and unit tests and is still running native Android SQLite verification. Live Worker/Neon secret configuration and direct-call 403 smoke tests remain deployment blockers. Do not merge or deploy yet.
- Live Neon state: Notices Function deployment 8 is active with custom environment `APP_ORIGINS` only; AI Function deployment 3 is active with `GEMINI_API_KEY`. The Neon Auth configuration has email/password + OTP enabled and a Google OAuth provider entry; the only trusted origin currently listed is the local loopback origin. Real-account Android sign-in, production email delivery, and production Web-origin acceptance remain unverified.
- Live Cloudflare state: Worker `edunivora-guest-metrics` and its SQLite Durable Object exist, but the active Worker is the older standalone counter script. Its secret list is empty. The new proxy code is not deployed; the Neon guest metric routes are therefore still directly callable until the coordinated gateway rollout.
- Gemini model identifier `gemini-3.8-flash` is present in Google's current official API documentation. This confirms the model name only; it is not a live authenticated provider-response test.
- Production SQLite encryption remains **not implemented**. PR #12 is an isolated SQLite3MC compatibility proof only; the production factory remains unencrypted. The existing decision document explicitly forbids a production driver switch or user-data migration without a separate approved, crash-safe migration plan.
- Production signing remains owner-gated. The repository's Android audit records no local upload keystore; GitHub signing secrets and `GOOGLE_SERVER_CLIENT_ID` have not been verified from this session. No signed production APK/AAB has been built.
- The isolated Neon migration test branch `br-shy-wildflower-balwlu2e` (migration id `mcp-migration-2026-11-23T17-13-38`) remains after schema verification; it has not been discarded because the Neon migration-completion tool requires explicit owner authorization. Production was not touched.
- No PR in this stack has been merged to `main`, no production Neon migration/function deployment was performed, and no Cloudflare production Worker change was deployed.

This snapshot supersedes the 2026-11-22 status above. Update it again only with evidence tied to the exact new head SHA and workflow run.
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
