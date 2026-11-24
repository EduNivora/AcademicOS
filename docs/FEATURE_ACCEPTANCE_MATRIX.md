# EduNivora / AcademicOS — Feature Acceptance Matrix

**Audit basis:** repository source and tests on the unified execution branch as of 2026-11-15.  
**Important:** “Present in source” is not equivalent to accepted, production-ready, or verified on every platform. The latest CI result applies only to its recorded commit SHA.

## Status definitions

- **Present / partially verified:** implementation exists and some automated tests cover the domain; end-to-end acceptance is still required.
- **Present / unverified:** implementation or UI exists, but reliable acceptance evidence is not yet recorded.
- **Incomplete:** a meaningful part of the workflow is missing.
- **Not implemented:** no production implementation is present in this repository.

## Student academic workflows

| Domain | Current status | Existing evidence | Acceptance still required |
|---|---|---|---|
| Student workspace and academic setup | Implemented / not fully verified | Local SQLite academic-term schema v12, validated term model, transactional create/edit/activate/delete operations, student-facing semester screen, and exact-head Flutter quality gate on `8904bf0af783c7f01d24bbbd70922a69af680e15` (run `43753940254`) | Fresh-install and upgrade migration tests, duplicate-name and single-active-term constraints, linked-course rename/delete behavior, full UI workflow and platform acceptance |
| Courses | Present / partially verified | Course model/use-case tests; database schema tests | Full CRUD UI integration, course relationships, validation, duplicate handling, migration coverage |
| Tasks and deadlines | Present / partially verified | Task model and use-case tests; database tests | Recurrence, priorities, overdue transitions, reminders, course linkage, offline/error states |
| Weekly schedule | Present / unverified | Schedule persistence and UI are present in source | Conflict detection, recurring events, timezone/DST behavior, notification scheduling and permission denial |
| Exams | Present / partially verified | Exam model tests and academic report tests | CRUD lifecycle, course association, past/upcoming filtering, timezone and boundary-date tests |
| Grades and GPA tools | Present / unverified | GPA/grade screens and calculation code are present | Formula validation, credit weighting, rounding, edge cases, empty/incomplete grades and regression tests |
| Study planning and focus | Present / unverified | Study planner and focus timer screens are present | Persisted sessions, pause/resume, timer lifecycle, schedule integration, app background/foreground behavior |
| Course materials | Implemented / CI verified; runtime acceptance pending | PR #17 is merged into the Release 1 integration branch. SQLite BLOB migration, bytes-only picker import, guarded legacy-temp migration, attachment-byte persistence and regression coverage are present; exact integration head `8904bf0af783c7f01d24bbbd70922a69af680e15` passed Flutter analysis/tests and Android Debug build in run `43753940254` | Android/Web persistence runtime checks, large-file behavior, legacy migration fixtures, viewer lifecycle and restart/upgrade persistence on supported platforms. Backup inclusion remains Release 2 |
| Academic dashboard and reports | Present / partially verified | Dashboard and report service tests | Reconciliation against source records, empty-state behavior, date boundaries and large datasets |
| Academic AI assistant | Present / partially verified | Assistant service and dashboard tests; intent/action code exists | Malformed-input safety, deterministic action execution, confirmation for destructive actions, permissions, offline behavior and action auditability |
| Notifications and reminders | Present / unverified | Local notification/timezone dependencies and feature code exist | Android notification permission/channel tests, exact-fire-time checks, reboot behavior, timezone/DST, iOS/Web/Desktop support claims |
| Settings, themes and localization | Present / unverified | Settings and Arabic/English theme/localization code exist | RTL/LTR visual acceptance, accessibility, responsive layouts, persistence and complete translation audit |

## Identity, security, persistence and recovery

| Domain | Current status | Existing evidence | Acceptance still required |
|---|---|---|---|
| Local account authentication | Present / partially verified (legacy compatibility) | Argon2id verifier tests, legacy SHA-256 migration tests, auth cleanup tests; local credentials remain available for existing users | Real-device KDF performance, malformed/corrupt storage behavior, credential replacement, account reset and platform secure-storage tests |
| Neon Managed Auth — email/password + OTP | Implemented / end-to-end unverified | Flutter REST adapter, native secure session-cookie persistence, Web credential-cookie transport, sign-up/sign-in/OTP/session/token tests and email verification screens | Exact-head Flutter CI, real-account sign-up/sign-in/OTP/resend/session-restore/sign-out on Android, Web trusted-origin/CORS acceptance, offline transitions and production SMTP |
| Google sign-in/session lifecycle | Implemented / unit-verified; live device login pending | Native Google OAuth with Neon Auth adapter, loopback server with state/nonce validation, Chrome Custom Tabs launcher, deep-link callback, and session exchange implemented. Comprehensive unit test suite (test/neon_google_auth_test.dart) passes | Physical device sign-in with live Google credentials and production GOOGLE_SERVER_CLIENT_ID configuration |
| App lock / PIN | Present / partially verified | Argon2id PIN verification, legacy migration and throttling tests | Biometric enrollment/removal, lifecycle lock timing, device tests and clock-tampering resilience |
| Persistent SQLite storage | Present / partially verified | Database helper, schema versioning and database tests; startup fails closed | Migration from every supported schema, crash recovery, concurrent access, corruption handling and device/browser persistence tests |
| SQLite encryption at rest | **Not implemented** | Production database key is not connected to an encrypted SQLite engine. PR #12 remains an isolated compatibility proof only; it does not encrypt the production database. The Release 1 integration branch still uses the ordinary SQLite factories | Production driver integration, complete plugin/platform compatibility, on-disk ciphertext inspection, wrong-key rejection, key lifecycle and crash-safe migration/rollback are required before claiming encryption |
| JSON backup validation | Present / partially verified | Strict payload validator and malformed/duplicate/orphan-reference tests | Fuzzing, schema compatibility guarantees, large payload handling and end-to-end rollback/failure injection |
| Backup export/import | Deferred to Release 2; excluded from Release 1 | Legacy JSON export/import code and backup validation remain in the repository as unaccepted work-in-progress; backup screens must not be exposed in Release 1. PR #13 remains a separate Draft security mitigation and is not part of Release 1 acceptance | Reassess during Release 2: encrypted archive, complete database/settings/attachment payload, manifest/checksums, staged restore, rollback, cross-device recovery, cleanup and Web/browser acceptance |
| Cloud sync and multi-device conflict resolution | **Not implemented** | No verified sync backend or conflict-resolution implementation | Product decision, threat model, sync protocol, conflict strategy, encryption/key lifecycle and offline queue semantics |

| Registered announcement receipts | Implemented / end-to-end unverified | Flutter obtains Neon JWTs and sends Bearer-authenticated delivery/read receipts; repository tests cover registered-versus-guest routing | Exact-head Flutter CI, live JWT verification and idempotent database receipts, session expiry, and Web CORS |
| Admin announcement console | Implemented / end-to-end unverified | Role-gated Flutter console supports draft list/create/edit, publish, archive and aggregate reports; role is read from authenticated `GET /v1/me` and API authorization remains server-side | Bootstrap first verified admin with the operator-only SQL script, live JWT/role checks for all actions, audit trail verification, Web CORS and device acceptance |
| First administrator bootstrap | Implemented as controlled operator procedure / not executed | One-time SQL script verifies the target email and refuses if an admin already exists | Execute only after the intended owner account completes email OTP; confirm admin role and test unauthorized account remains blocked |
| Guest announcement metrics | Present / partially verified | Anonymous aggregate counters; no guest ID/IP/device fingerprint; persistent local delivery dedupe and retry tests | Abuse controls, rate limiting, retention/purge policy, and exact-head platform acceptance |

## Build, platform and operational acceptance

| Target / gate | Current status | Acceptance evidence required |
|---|---|---|
| Android | Verified locally and in CI: Debug APK built, 134/134 tests pass, 0 analyzer errors/warnings | Debug APK built successfully (`build/app/outputs/flutter-apk/app-debug.apk`), AAPT badging verified ('EduNivora' label, 'com.arfatalkamli.academicos' package, launcher icons). Native SQLite emulator test integrated in CI (`flutter-quality.yml`). Release signing workflow configured (`android-production-release.yml`) | Physical device installation, production release signing with owner upload key |
| Web | Build/runtime acceptance unverified on the Release 1 integration head | Historical PR #9 worker/Web build evidence is from a separate feature branch and is not evidence for the current integration head. Current browser persistence, refresh/reopen, offline behavior, file-picker behavior and supported-browser tests are not accepted. The current source tree must be inspected and validated on the exact release candidate before Web support is claimed | Synchronize and verify the Web worker/WASM runtime on the current integration branch, then test IndexedDB persistence, refresh/reopen, offline mode, file picker and supported browsers |
| Windows | Configured in repository; runtime acceptance unverified | Windows release build, installer/runtime dependencies, database persistence and file access tests |
| iOS | Not established by current repository configuration | Add/verify platform project, build, signing, secure storage, notifications and device tests before claiming support |
| macOS / Linux | Not established by current repository configuration | Add/verify platform projects, FFI database behavior, builds and runtime tests before claiming support |
| CI reproducibility | Current integration head verified by CI; documentation follow-up pending | Integration head `8904bf0af783c7f01d24bbbd70922a69af680e15` passed run #211 (`43753940254`): dependency resolution, Dart analysis, Flutter tests, Android Debug APK build and artifact upload. Documentation commits updating architecture and this matrix require their own exact-head CI run before being marked verified |
| Release signing/distribution | Incomplete | Production signing, secrets management, versioning, release pipeline, install/upgrade validation |
| Privacy and operations | Incomplete | Threat model, privacy/data-retention documentation, dependency/security scans, crash reporting review and recovery procedures |

## Current automated test evidence

The earlier run on commit `fc493b366c81f1cd6f47ac811a5209f310b442ff` failed at Android APK build because the runner lacked Android NDK `27.0.12077973`. The workflow was updated to provision the Android SDK/NDK and CMake.

The current code head `8904bf0af783c7f01d24bbbd70922a69af680e15` passed Flutter quality run #211 (`43753940254`): dependency resolution, Dart analysis, Flutter tests, Android Debug APK build and artifact upload. Subsequent documentation-only updates to `ARCHITECTURE.md` and this matrix are not covered by run #211; the latest documentation head must be checked independently. Earlier successful runs remain historical evidence tied to their own exact SHAs. PR #12 is an isolated SQLite encryption proof, not production integration. PR #13 remains separate work and is not part of Release 1. Browser runtime acceptance, physical-device acceptance, production database encryption and release signing remain outstanding. CI results must always be tied to the exact commit SHA.

## Release acceptance rule

A domain moves to **Accepted** only when:
1. Its user-facing acceptance criteria are documented.
2. Unit/widget/integration tests cover normal, boundary, error, offline and recovery paths as appropriate.
3. Platform-specific behavior is tested on every platform claimed as supported.
4. Data integrity, privacy and security constraints are verified.
5. Evidence is linked to the exact commit/release candidate.

Do not calculate an overall completion percentage from screen count or source-file presence. The matrix must be updated with test evidence, platform results and unresolved defects before any release-readiness claim.


## Approved product decisions — 2026-11-15

The following decisions are binding scope for future implementation and acceptance. They supersede any older wording in this matrix that implies mandatory login, academic cloud sync, or server-side academic data storage.

| Area | Approved decision | Acceptance criteria |
|---|---|---|
| App entry | Guest-first; no login required to open or use core academic features | Fresh install opens to usable app; guest CRUD works offline; account prompts are optional |
| Accounts | Optional Google or email/password account | Central database contains only minimum account identity/profile fields; no academic records or files |
| Academic data | Local-only | Terms, courses, schedule, tasks, exams, notes, settings, materials and reports remain on device; no remote academic sync |
| Attachments | Durable app-owned local storage | File bytes persist across restart/upgrade; backup inclusion is a Release 2 gate |
| Google Drive backup | Deferred to Release 2; excluded from Release 1 | Do not merge or expose backup UI in Release 1; Release 2 must meet full encryption, completeness, restore and platform acceptance |
| Backup trigger | Release 2 only | Explicit user-initiated backup; no scheduled/automatic backup requirement unless separately approved |
| Backup cryptography | Release 2 only | Student-chosen password, memory-hard KDF, wrapped random key, authenticated encryption, tamper/wrong-password rejection |
| Backup completeness and restore | Release 2 only | Full database, attachments, settings, manifest/checksums, staged restore, rollback, cross-device recovery and failure-injection tests |
| Notices | Public notices for all app installations, guests and accounts | Notice appears in app; online installations can acknowledge delivery and opening |
| Notice analytics | Named receipts for registered accounts; anonymous aggregates for guests | No guest identity or stable guest profile; delivery and read events are distinct and timestamped |
| Operator tooling | Minimal notice publishing/reporting only | Separate protected interface; no student/lecturer/attendance/finance/university administration |
| Cloud sync | Excluded | No academic records/files replicated or synchronized to EduNivora servers |

Notice delivery is not guaranteed while a device is offline or notifications are disabled. Anonymous guest analytics must remain aggregate and must not be used to reconstruct a guest identity. The encrypted Drive archive does not satisfy the separate production SQLite-at-rest encryption requirement.

### Current CI baseline
- PR #1 remains open and Draft; current head at this audit: `8904bf0af783c7f01d24bbbd70922a69af680e15`.
- Workflow run #211 (`43753940254`) completed successfully on that exact SHA: dependency resolution, Dart analysis, Flutter tests, Android Debug APK build, and artifact upload all passed.
- This is CI evidence only; it does not establish physical-device, browser, release-signing, production-encryption or complete Release 1 acceptance.
- No PR merge is implied by this documentation update.


## Release boundary decision — 2026-11-15

Google Drive backup, encrypted archive export/import, upload/download and backup-specific UI are **deferred to Release 2**. They are not Release 1 acceptance gates and must not delay the core academic application, optional accounts, public notices, local persistence, security hardening or Release 1 validation.

Existing PRs/branches for backup are parked as draft work. Do not merge them into the Release 1 integration branch. Reassess their code, dependencies and security assumptions during Release 2 planning; passing isolated tests does not change the release boundary.


## Neon account and public-notice backend — implementation status (2026-11-15)

| Area | Current status | Remaining acceptance evidence |
|---|---|---|
| Neon PostgreSQL project | **Provisioned and inspected** — dedicated `edunivora` project, PostgreSQL 17, Frankfurt region | Monitor actual free-tier consumption and verify production quotas |
| Neon Managed Auth | **Enabled/configured** — email/password with mandatory OTP email verification; organization plugin disabled | Flutter client integration, sign-up/sign-in/sign-out/session restoration tests, production SMTP, production Google OAuth credentials and trusted origins |
| Cloud schema | **Provisioned and inspected** — profile projection, notices, registered delivery/read receipts, anonymous daily guest counters, admin audit | Migration CI on a clean child branch, retention policy and production data-access review |
| Notices API | **Deployed; smoke-tested** — Hono/Node.js 24 Function; health and public feed return HTTP 200; unauthenticated admin route returns HTTP 401 | Verify JWT acceptance, registered delivery/read idempotency, admin publish/report, guest POST metrics, CORS for production Web origin and abuse controls against the live branch |
| Flutter account integration | **Implemented / end-to-end unverified** — Neon Managed Auth REST adapter, email/password, OTP verification, native cookie persistence, browser credential-cookie transport, session restore, and JWT retrieval are present with unit tests | Exact-head Flutter CI; real-account sign-up, sign-in, OTP, session restore/sign-out and offline transitions on Android/Web; production trusted origin and credentialed CORS acceptance |
| Operator bootstrap | **Procedure implemented / not executed** — protected SQL bootstrap and role-gated admin console are present | Run only after owner account email verification; confirm first admin and prove ordinary users remain denied |
| Guest analytics | **Schema/API implementation** — aggregate counters only; no guest identifier persisted | Verify aggregate semantics, abuse controls and approved retention period |

The current Neon Auth configuration reports a shared Google OAuth provider and
shared SMTP sender. These are development configuration only; production
release requires the project's own Google OAuth client credentials, verified
redirect/trusted origins, and a production SMTP sender. Do not report Google
or email sign-in as production-ready until the Flutter flows and delivery are
tested end to end.

| Flutter public notices feed | **Implemented in branch** — public feed screen, offline cache, guest delivery/view aggregate events | Flutter analyze/tests, Android/Web builds, live CORS from actual Web origin, offline cache behavior and API error handling |

## Execution addendum — 2026-11-15 21:54 UTC

This addendum supersedes stale CI/PR references above where they conflict with the current Release 1 execution branch.

- Repository: `EduNivora/AcademicOS`
- PR: #21, base `chore/edunivora-phase0-execution`, head `feat/neon-managed-auth-and-notices`
- Exact latest source SHA at this audit: `f0c9f9c11b6001e4366208080ac1210fef35d975`
- PR state: open, Draft, not merged; 82 commits and 48 changed files at the time of inspection.
- Backend quality on exact SHA: run `43765880243` completed successfully (dependency install, syntax check, backend tests).
- Neon Function bundle on exact SHA: run `43765875238` completed successfully; artifact `notices-function-bundle-f0c9f9c11b6001e4366208080ac1210fef35d975` was produced.
- Flutter quality on exact SHA: run `43765880248` was pending/queued at this audit. The preceding SHA `bd6f6f5a04ac31ae5ecdc98f5bfb43257be4c606` passed Dart analysis and Flutter tests, and had reached Android Debug APK build; Android and Web build completion were not yet observed.
- Flutter workflow concurrency now uses `cancel-in-progress: false` so an active quality run is not terminated by a newer commit. This serializes runs and can delay the newest run until the active one finishes.
- API source changes for explicit CORS allowlisting and normalized JWT verifier failures are in the exact SHA above. The live Neon Function remains deployment ID 7; this source bundle has not been deployed. Live `/v1/me`, real JWT, receipts, admin publishing, and production CORS are therefore not accepted.
- Neon Auth config inspection confirms email/password with required email verification configured as OTP, but no production trusted origins, no project-owned Google OAuth credentials, and a shared development email sender. Flutter auth tests are adapter-level mocks, not real-account end-to-end tests.
- The first-admin bootstrap SQL is an operator-only procedure and has not been executed. No admin account or app user records were present at the last database inspection.
- Guest analytics remain aggregate event counters, not unique guest counts. Rate limiting/abuse controls and retention/purge policy remain incomplete.
- Google Drive backup, encrypted archive, restore and scheduled backup remain deferred to Release 2 by approved scope. Production SQLite encryption is not accepted for Release 1.

Do not mark Release 1 ready from the backend or bundle checks alone. The exact-head Flutter gate, real auth/JWT flows, deployed API verification, Web origin/CORS, first-admin bootstrap, and platform runtime acceptance remain release blockers.


## Assistant postcondition verification — current QA stack

- Active PR: [#55](https://github.com/EduNivora/AcademicOS/pull/55), based on the current QA candidate. Exact head `fff3a21ae7fa59646e1324b91d0dd098a4b1f37a` passed [run #45232872758](https://github.com/EduNivora/AcademicOS/actions/runs/45232872758): **203 Flutter tests and Dart analysis passed**.
- Verified postconditions cover course updates/credit normalization, task creation/course linkage/update/completion/deletion, attachment BLOB bytes (including same-length corruption rejection), lecture add/update/confirmed deletion, exams, and profile changes.
- Fixed schedule persistence to match the real SQLite schema: `course_name` is derived through `course_id`, not written as a nonexistent column. The schedule-image import now strips this derived field before batch insert.
- Failed postconditions preserve the action as uncertain/failed and stop dependent plan steps. Do not blindly replay interrupted writes.
- Old PR #52 remains preserved for history but is superseded due to a stale/diverged QA base. Do not merge it.
- Release acceptance still requires the parent QA native Android SQLite emulator, Android Debug/Web builds, production signing availability where required, and the separate backend deployment smoke tests. No production release or deployment is implied.


## Live evidence addendum — 2026-11-24

This addendum supersedes older CI references above wherever they conflict. Evidence is tied to exact heads:

- QA workflow hardening: PR #56 merged to QA as `b0faf98777d482baf01cee18df198611ebe420e5`; exact-head run #45439852629 succeeded, including native Android SQLite. The strict Bash `set -euo pipefail` step is preserved in the current QA workflow.
- Assistant postcondition verification: the previous PR #55 head is not accepted for merge because its base diverged. Its application changes are being reapplied on the current QA base; this rebased candidate must pass fresh exact-head analysis, tests, and Android integration before acceptance.
- Guest metrics gateway: PR #53 exact-head backend and Flutter runs #45271485684 and #45271485543 succeeded, including Android SQLite, Android Debug APK and Web Release. Deployment remains blocked until the Cloudflare proxy and Neon guard are configured with the same newly generated secret and all public-feed, authenticated-route, guest-write, direct-call rejection, quota and failure-mode smoke tests pass.
- Gemini quotas: backend run #44909953287 passed 39/39 tests and built the AI Function bundle. Flutter run #44909953393 was cancelled during Android SQLite verification; retry is pending/in progress. Migration 0003 has only been checked on an isolated Neon child branch, not production.
- Main workflow pipefail: PR #57 exact head `2fdafc0aa7ef95c6e49e0e95038e396152482a08` has passed analysis and Flutter tests; Android SQLite verification is not yet complete.
- Attachment durability: PR #58 exact head `877e7c637c263c0c3eedfd984aa26e8d260f8faf` has passed analysis and Flutter tests; Android SQLite verification is not yet complete. Its added close/reopen assertion still requires exact-head CI success.
- Mainline run #45433357599 passed analysis, Flutter tests, Android SQLite emulator, Android Debug APK and Web Release. No signed production ARM64 artifact was produced.
- Physical-device behavior, real authenticated account flows, production signing, production migrations/deployments, notification delivery after process restart, and Web persistence runtime acceptance remain open gates.

