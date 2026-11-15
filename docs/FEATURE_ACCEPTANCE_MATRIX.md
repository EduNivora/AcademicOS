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
| Course materials | Implemented in feature branch / awaiting CI | SQLite BLOB migration, bytes-only picker import, guarded legacy-temp migration, and attachment-byte backup schema v3 added with regression tests | CI analysis/tests, Android/Web persistence runtime checks, large-file behavior, legacy migration fixtures, viewer lifecycle, and backup/restore round-trip on supported platforms |
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
| SQLite encryption at rest | **Not implemented** | Production key is still not connected to an encrypted engine. Current isolated PR #12 head `0b71a102b13ec27460dbdbc8e880d89c61f92d8f` passed native proof run #15 (`43669623653`): Linux host encryption, wrong-key rejection, correct-key reopen, `PRAGMA integrity_check`, Android Debug APK and Android emulator integration. The root Flutter quality run #145 (`43669500715`) also passed dependency resolution, Dart analysis, Flutter tests, Android Debug APK and artifact upload on the same exact SHA. The proof artifact is `sqlite3mc-android-proof-debug` (79,139,067 bytes; SHA-256 `cfe530e0ce3c785d79b250e81e58eb0d278e2e631ac9aef1499f685f1462f395`; expires 2026-11-22) | Prove the full app's Android FFI factory integration with its complete plugin set, desktop runtime, Web `sqlite3mc.wasm` + IndexedDB, key lifecycle, and crash-safe plaintext migration/rollback before production adoption. The isolated proof branch is stale relative to current PR #1 head `fa7c52c84328f1408cc8a3658638711388f8bc00`: comparison reports 21 commits unique to the proof branch and 21 unique to PR #1; synchronize/revalidate before integration |
| JSON backup validation | Present / partially verified | Strict payload validator and malformed/duplicate/orphan-reference tests | Fuzzing, schema compatibility guarantees, large payload handling and end-to-end rollback/failure injection |
| Backup export/import | Incomplete | JSON file-picker save/import, transactional academic-record replacement, and attachment-byte JSON schema v3 are being implemented in `feat/durable-attachment-storage` (not yet CI-verified); Draft PR #13 adds a canonical owned-directory guard against imported absolute paths, traversal and symlink escapes; exact head `45e083c9ab604387f194ac8acf8dd3e544b541c6` passed run #143 (`43668156477`) for dependency resolution, analysis, Flutter tests, Android Debug APK and artifact upload. It remains a separate unmerged Draft PR and is diverged from current PR #1 head `fa7c52c84328f1408cc8a3658638711388f8bc00`: comparison reports 5 commits unique to PR #13 and 12 unique to PR #1; synchronize/revalidate before integration. The materials directory is still temporary, not durable | Durable app-owned storage, attachment bytes, checksums, safe archive paths, staged file/DB restore, cross-device restore, cleanup and Web/browser acceptance |
| Cloud sync and multi-device conflict resolution | **Not implemented** | No verified sync backend or conflict-resolution implementation | Product decision, threat model, sync protocol, conflict strategy, encryption/key lifecycle and offline queue semantics |

## Build, platform and operational acceptance

| Target / gate | Current status | Acceptance evidence required |
|---|---|---|
| Android | CI Debug build verified on latest code/evidence head `0b51ca5c3b3efd5d269a3eb2aaa9bc2b2d8a47f0` | Workflow run `43673014737` (#149) completed successfully on this exact SHA: dependency resolution, Dart analysis, Flutter tests, Android Debug APK build, and artifact upload. Artifact `academicos-android-debug-apk`: 97,515,797 bytes; SHA-256 `1b8d2556e563530e6e2a1ef89d1f121bb9958775f2326a7577c1d34291ca7d2d`; expires 2026-11-29. Physical application install, runtime, upgrade, and release-signing tests remain outstanding |
| Web | Build/worker CI passed on a stale, diverged Draft branch; browser runtime acceptance unverified | PR #9 exact head `cdc33b03b2c5cf30ed3069423c9dea14ce78bb3a`, run `43651209709` (#117), passed dependency resolution, SQLite WebAssembly worker setup, analysis, tests, Android Debug APK, Web release build, and artifact uploads. Compared with current PR #1 head `fa7c52c84328f1408cc8a3658638711388f8bc00`, the histories diverged: 23 commits are unique to PR #1 and 3 to PR #9. The PR #9 branch therefore needs synchronization and fresh validation before integration. The current PR #1 source still contains a 47-byte placeholder `web/sqlite3.wasm` and a 309-byte message-only `web/sqflite_sw.js`; PR #9 generated the worker/WASM only during its CI build. Synchronize/rebase and rerun CI before treating the Web build as current. Browser persistence, file picker, refresh/reopen, offline and supported-browser tests remain outstanding |
| Windows | Configured in repository; runtime acceptance unverified | Windows release build, installer/runtime dependencies, database persistence and file access tests |
| iOS | Not established by current repository configuration | Add/verify platform project, build, signing, secure storage, notifications and device tests before claiming support |
| macOS / Linux | Not established by current repository configuration | Add/verify platform projects, FFI database behavior, builds and runtime tests before claiming support |
| CI reproducibility | Latest documentation head verified by CI | Commit `cc73f8a2928ae7d9bcaebfacb33bb845cf7b1635` passed run #152 (`43674055636`): dependency resolution, Dart analysis, Flutter tests, Android Debug APK build and artifact upload all succeeded. The uploaded artifact is 97,515,795 bytes (SHA-256 `297cba0e844085e1e425ac417ded4f8a9de2b3c2a0669e58f3b29ec61d150772`), expires 2026-11-29. The latest documentation-only audit commit `4943108e7661ba484986083ca278028b14661746` had CI run #158 (`43733158641`) cancelled during Flutter setup; the current head `fa7c52c84328f1408cc8a3658638711388f8bc00` has a new Flutter quality run #160 (`43733372487`) pending, so no CI acceptance is claimed for the current head. PR #13 head `45e083c9ab604387f194ac8acf8dd3e544b541c6` passed run #143 (`43668156477`) for analysis, Flutter tests, Android Debug APK build and artifact upload, but requires synchronization with the current base |
| Release signing/distribution | Incomplete | Production signing, secrets management, versioning, release pipeline, install/upgrade validation |
| Privacy and operations | Incomplete | Threat model, privacy/data-retention documentation, dependency/security scans, crash reporting review and recovery procedures |

## Current automated test evidence

The earlier run on commit `fc493b366c81f1cd6f47ac811a5209f310b442ff` failed at Android APK build because the runner lacked Android NDK `27.0.12077973`. The workflow was updated to provision the Android SDK/NDK and CMake.

The subsequent run `43646657252` on commit `5b9935817cc0080ad9e8ee9b1037e1312b6c0a8d` and run #113 (`43650825614`) on `5c119d427a9469c8e6fe8aa95b10bc5b284163f3` completed successfully. The latest unified-branch run #137 (`43666349593`) passed on `27da42483a259fe99193a169f98748bc373a1775`; run #139 (`43667443100`) passed on `e80a17ccd53c47eba6a42773de38320ded56a26c`; run #144 (`43668568601`) passed on `bda8c81f69b3f5221b462e1b7630a373f634466d`; run #148 (`43669922625`) passed on `8ddf3537a5db711b85de23ce5787a404788678db`; run #149 (`43673014737`) passed on code/evidence head `0b51ca5c3b3efd5d269a3eb2aaa9bc2b2d8a47f0`; and docs-only head `cc73f8a2928ae7d9bcaebfacb33bb845cf7b1635` passed run #152 (`43674055636`); later documentation-only commits are not covered by that run. The subsequent audit-only head `4943108e7661ba484986083ca278028b14661746` was checked by CI run #158 (`43733158641`), but the job was cancelled during Flutter setup; dependency resolution, analysis, tests and builds were skipped. The current head `fa7c52c84328f1408cc8a3658638711388f8bc00` has Flutter quality run #160 (`43733372487`) pending; wait for completion before claiming CI acceptance. Each passed dependency resolution, Dart analysis, Flutter tests, Android Debug APK build and artifact upload. Run #149 artifact is 97,515,797 bytes (SHA-256 `1b8d2556e563530e6e2a1ef89d1f121bb9958775f2326a7577c1d34291ca7d2d`) and expires 2026-11-29. PR #12 current head `0b71a102b13ec27460dbdbc8e880d89c61f92d8f` passed native proof run #15 (`43669623653`), including host encryption, Android emulator integration, wrong-key rejection, correct-key reopen and integrity check. Its root Flutter quality run #145 (`43669500715`) also passed on the same SHA. The proof APK artifact is 79,139,067 bytes and expires 2026-11-22. PR #13 head `45e083c9ab604387f194ac8acf8dd3e544b541c6` passed run #143 (`43668156477`) but is diverged from the current PR #1 base by 5 commits unique to PR #13 and 12 unique to PR #1. PR #9 run #117 (`43651209709`) passed Web worker setup and Web release build, but its branch is diverged from the latest tested PR #1 line (23 commits unique to PR #1 and 3 unique to PR #9); the current PR #1 Web files remain placeholders. Browser persistence and runtime acceptance remain unverified. These are CI results only; physical-device app acceptance, production encryption, backup attachment recovery, and release signing remain outstanding. Results must remain tied to their exact commit SHA.

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
| Attachments | Durable app-owned local storage | File bytes persist across restart/upgrade and are included in a complete backup |
| Google Drive | Student-owned, normal visible folder named `EduNivora` | OAuth uses least-privilege access; each student writes only to their own Drive; backup is not sync |
| Backup trigger | Explicit user-initiated backup; automatic backup is not a committed requirement | User chooses account, confirms backup password, sees progress/result and backup metadata |
| Backup cryptography | Student-chosen password plus additional key protection | Versioned memory-hard KDF, random data key, wrapped key, authenticated encryption, no plaintext password/key persistence, wrong-password rejection |
| Backup completeness | Database + attachment bytes + required settings/manifest | Checksums, version compatibility, safe paths, staged restore, atomic/recoverable file+DB replacement, failure-injection tests |
| Notices | Public notices for all app installations, guests and accounts | Notice appears in app; online installations can acknowledge delivery and opening |
| Notice analytics | Named receipts for registered accounts; anonymous aggregates for guests | No guest identity or stable guest profile; delivery and read events are distinct and timestamped |
| Operator tooling | Minimal notice publishing/reporting only | Separate protected interface; no student/lecturer/attendance/finance/university administration |
| Cloud sync | Excluded | No academic records/files replicated or synchronized to EduNivora servers |

Notice delivery is not guaranteed while a device is offline or notifications are disabled. Anonymous guest analytics must remain aggregate and must not be used to reconstruct a guest identity. The encrypted Drive archive does not satisfy the separate production SQLite-at-rest encryption requirement.

### Current CI baseline at decision adoption
- PR #1 remains open and Draft; current head: `a3ba380e9e6bf52c36d5a3c55409c4331a1c200a`.
- Workflow run #161 (`43733424952`) completed successfully on that exact SHA: dependency resolution, Dart analysis, Flutter tests, Android Debug APK build, and artifact upload all passed.
- Artifact `academicos-android-debug-apk`: 97,515,795 bytes; SHA-256 `cb9dbc7a7ae803aff094abe6efea26a8664ae74d81be306d04610f99883d70d4`; expires 2026-11-29.
- This CI run predates the documentation commit recording these approved decisions; rerun CI on the resulting documentation commit before claiming that new head is verified.
- No PR merge is implied by this documentation update.
