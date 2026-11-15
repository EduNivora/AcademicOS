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
| Student workspace and academic setup | Present / unverified | Local-first Flutter application; student data models and settings exist | First-run flow, create/edit/delete academic terms and student-defined structure, empty states, data ownership and reset behavior |
| Courses | Present / partially verified | Course model/use-case tests; database schema tests | Full CRUD UI integration, course relationships, validation, duplicate handling, migration coverage |
| Tasks and deadlines | Present / partially verified | Task model and use-case tests; database tests | Recurrence, priorities, overdue transitions, reminders, course linkage, offline/error states |
| Weekly schedule | Present / unverified | Schedule persistence and UI are present in source | Conflict detection, recurring events, timezone/DST behavior, notification scheduling and permission denial |
| Exams | Present / partially verified | Exam model tests and academic report tests | CRUD lifecycle, course association, past/upcoming filtering, timezone and boundary-date tests |
| Grades and GPA tools | Present / unverified | GPA/grade screens and calculation code are present | Formula validation, credit weighting, rounding, edge cases, empty/incomplete grades and regression tests |
| Study planning and focus | Present / unverified | Study planner and focus timer screens are present | Persisted sessions, pause/resume, timer lifecycle, schedule integration, app background/foreground behavior |
| Course materials | Incomplete | Material metadata model and database table are present | File bytes lifecycle, safe file storage, orphan cleanup, attachment integrity, backup/restore and permissions |
| Academic dashboard and reports | Present / partially verified | Dashboard and report service tests | Reconciliation against source records, empty-state behavior, date boundaries and large datasets |
| Academic AI assistant | Present / partially verified | Assistant service and dashboard tests; intent/action code exists | Malformed-input safety, deterministic action execution, confirmation for destructive actions, permissions, offline behavior and action auditability |
| Notifications and reminders | Present / unverified | Local notification/timezone dependencies and feature code exist | Android notification permission/channel tests, exact-fire-time checks, reboot behavior, timezone/DST, iOS/Web/Desktop support claims |
| Settings, themes and localization | Present / unverified | Settings and Arabic/English theme/localization code exist | RTL/LTR visual acceptance, accessibility, responsive layouts, persistence and complete translation audit |

## Identity, security, persistence and recovery

| Domain | Current status | Existing evidence | Acceptance still required |
|---|---|---|---|
| Local account authentication | Present / partially verified | Argon2id verifier tests, legacy SHA-256 migration tests, auth cleanup tests | Real-device KDF performance, malformed/corrupt storage behavior, credential replacement, account reset and platform secure-storage tests |
| Google sign-in/session lifecycle | Present / partially verified | Auth gate and session cleanup implementation/tests | Real OAuth configuration, revoke/sign-out semantics, cached identity recovery, network failure and physical-device testing |
| App lock / PIN | Present / partially verified | Argon2id PIN verification, legacy migration and throttling tests | Biometric enrollment/removal, lifecycle lock timing, device tests and clock-tampering resilience |
| Persistent SQLite storage | Present / partially verified | Database helper, schema versioning and database tests; startup fails closed | Migration from every supported schema, crash recovery, concurrent access, corruption handling and device/browser persistence tests |
| SQLite encryption at rest | **Not implemented** | Production key is still not connected to an encrypted engine. Isolated SQLite3MC FFI proof passed on Linux host and Android emulator in PR #12 / run `43665384937`, but its Android test uses `databaseFactoryFfi`, not the production Android `sqflite` factory | Prove full-app Android factory/plugin integration, desktop runtime, Web `sqlite3mc.wasm` + IndexedDB, key lifecycle, and crash-safe plaintext migration/rollback before production adoption |
| JSON backup validation | Present / partially verified | Strict payload validator and malformed/duplicate/orphan-reference tests | Fuzzing, schema compatibility guarantees, large payload handling and end-to-end rollback/failure injection |
| Backup export/import | Incomplete | JSON file-picker save/import and transactional academic-record replacement exist; Draft PR #13 adds a canonical owned-directory guard against imported absolute paths, traversal and symlink escapes (CI pending) | Durable app-owned storage, attachment bytes, checksums, safe archive paths, staged file/DB restore, cross-device restore, cleanup and Web/browser acceptance |
| Cloud sync and multi-device conflict resolution | **Not implemented** | No verified sync backend or conflict-resolution implementation | Product decision, threat model, sync protocol, conflict strategy, encryption/key lifecycle and offline queue semantics |

## Build, platform and operational acceptance

| Target / gate | Current status | Acceptance evidence required |
|---|---|---|
| Android | CI Debug build verified on commit `27da42483a259fe99193a169f98748bc373a1775` | Workflow run `43666349593` (#137) completed successfully on this exact SHA: dependency resolution, Dart analysis, Flutter tests, Android Debug APK build, and artifact upload. Physical application install, runtime, upgrade, and release-signing tests remain outstanding |
| Web | Build and worker setup verified; browser runtime acceptance unverified | PR #9 exact head `cdc33b03b2c5cf30ed3069423c9dea14ce78bb3a`, run `43651209709` (#117) passed dependency resolution, SQLite WebAssembly worker setup, analysis, tests, Android Debug APK, Web release build, and artifact uploads. Browser persistence, file picker, refresh/reopen, offline and supported-browser tests remain outstanding |
| Windows | Configured in repository; runtime acceptance unverified | Windows release build, installer/runtime dependencies, database persistence and file access tests |
| iOS | Not established by current repository configuration | Add/verify platform project, build, signing, secure storage, notifications and device tests before claiming support |
| macOS / Linux | Not established by current repository configuration | Add/verify platform projects, FFI database behavior, builds and runtime tests before claiming support |
| CI reproducibility | Verified on the unified execution head; follow-up PR pending | PR #1 head `27da42483a259fe99193a169f98748bc373a1775` passed run #137 (`43666349593`). The attachment-path security follow-up PR #13 is separately awaiting CI on `3305997c31637a49ed34229521683bc94bad0304` |
| Release signing/distribution | Incomplete | Production signing, secrets management, versioning, release pipeline, install/upgrade validation |
| Privacy and operations | Incomplete | Threat model, privacy/data-retention documentation, dependency/security scans, crash reporting review and recovery procedures |

## Current automated test evidence

The earlier run on commit `fc493b366c81f1cd6f47ac811a5209f310b442ff` failed at Android APK build because the runner lacked Android NDK `27.0.12077973`. The workflow was updated to provision the Android SDK/NDK and CMake.

The subsequent run `43646657252` on commit `5b9935817cc0080ad9e8ee9b1037e1312b6c0a8d` and run #113 (`43650825614`) on `5c119d427a9469c8e6fe8aa95b10bc5b284163f3` completed successfully. The latest unified-branch run #137 (`43666349593`) also completed successfully on exact head `27da42483a259fe99193a169f98748bc373a1775`: dependency resolution, Dart analysis, all Flutter tests, Android Debug APK build and artifact upload. The uploaded Debug APK artifact is 97,515,796 bytes and expires on 2026-11-29. Separately, PR #12 run #8 (`43665384937`) passed the isolated SQLite3MC Linux host and Android emulator proof; it does not prove the production Android factory is encrypted. PR #9 run #117 (`43651209709`) passed the Web worker setup and Web release build, but browser persistence and runtime acceptance remain unverified. These are CI results only; physical-device app acceptance, production encryption, backup attachment recovery, and release signing remain outstanding. Results must remain tied to their exact commit SHA.

## Release acceptance rule

A domain moves to **Accepted** only when:
1. Its user-facing acceptance criteria are documented.
2. Unit/widget/integration tests cover normal, boundary, error, offline and recovery paths as appropriate.
3. Platform-specific behavior is tested on every platform claimed as supported.
4. Data integrity, privacy and security constraints are verified.
5. Evidence is linked to the exact commit/release candidate.

Do not calculate an overall completion percentage from screen count or source-file presence. The matrix must be updated with test evidence, platform results and unresolved defects before any release-readiness claim.
