# AcademicOS — Defect & Risk Register

**Baseline:** `989ad5212971097df868dabab557c1c076d91720`  
**Snapshot:** 2026-11-25

| ID | Finding | Severity | Evidence / impact | Required action | Status |
|---|---|---|---|---|---|
| CI-01 | Flutter test pipeline used `flutter test ... | tee` without pipefail on main | Critical | A failing Flutter process could be masked by successful tee. Strict Bash pipefail is applied to all seven `tee` pipelines in `flutter-quality.yml`; related workflows use direct commands without tee. | IMPLEMENTED — VERIFIED on PR #68 exact-head run 45531164225 |
| CI-02 | Android emulator integration failed on #57/#58 exact heads | Medium / environment | Unit/widget Flutter tests and analysis passed; emulator logs show debug connection reader stopped and system_server/Android runtime crash. | Rerun exact SHA on fresh emulator; preserve emulator logs. Do not mark as app test failure without a Flutter assertion/stack trace. | BLOCKED |
| PR-01 | QA PR #50 reports mergeable=false | High | It touches workflow, database, assistant and UI files; downstream #59 is based on its head. | Resolve conflict against current main; re-run full CI; then rebase dependent work. | BLOCKED |
| PR-02 | PR #59 green on QA but not based on main | High | Base is `qa/uiux-release-candidate`, head `d6759a3...`. | Do not treat as main-ready; integrate only after QA candidate is resolved. | BLOCKED |
| PR-03 | PR #47 backend green but Flutter run cancelled | High | Backend tests/build passed; Flutter run #44909953393 cancelled during Android verification. | Fresh exact-head Flutter gate; review migration 0003 before any deployment. | BLOCKED |
| PR-04 | PR #53 passes CI but deployment prerequisites remain | High | Worker/Neon secret coordination and live proxy smoke tests are outside CI. | Keep deployment gated; do not rotate secrets or deploy without owner approval. | BLOCKED |
| DB-01 | Attachment BLOB persistence is implemented in current mainline, but PR #58 is still unmerged | Medium | PR #58 adds a close/reopen assertion; emulator evidence is inconclusive due runner crash. | Retest on stable emulator; retain bytes integrity and reopen checks. Do not redesign attachments in this task. | BLOCKED |
| RPT-01 | Report service previously contained backup serialization methods | High | Baseline SHA confirmed `buildBackupPayload/encodeBackupJson` were in `AcademicReportService`. Phase 1 removes them while retaining daily/weekly/monthly/final report generation; report unit tests pass on the exact PR #68 head. | Exact-head run 45531164225 passed. | IMPLEMENTED — VERIFIED |
| BK-01 | Combined backup/report screen | High | Baseline screen was unreferenced by navigation; home already opened `AcademicReportsScreen`. The combined screen is deleted in PR #68; the standalone report screen widget tests pass. | Exact-head run 45531164225 passed analysis, tests and builds. | IMPLEMENTED — VERIFIED |
| BK-02 | Restore validator and database replacement method | High | Baseline code search found `BackupPayloadValidator` and `replaceAcademicData` only in restore UI/tests. Both APIs and their restore-specific tests are deleted in PR #68; ordinary CRUD and attachment BLOB persistence remain. | Exact-head run 45531164225 passed the Flutter regression suite and Android SQLite integration test. | IMPLEMENTED — VERIFIED |
| DOC-01 | Product/architecture scope previously described backup as a future release feature | High | The current owner decision explicitly excludes backup/restore. README, architecture, product scope, roadmap, acceptance matrix and legal copy were updated in PR #68. | Exact-head review confirms the documented exclusion; run 45531164225 passed. | IMPLEMENTED — VERIFIED |

## Confirmed non-defects / do not misclassify

- PR #57 was closed unmerged as superseded by #60. Its Flutter test step passed; its emulator sizing and readiness improvements are now incorporated in #60. The historical “log reader stopped unexpectedly” message is not evidence of Flutter test failure.
- PR #58: Flutter test step passed on exact head; emulator logs include system_server crash and DeadSystemException. This is not proof of attachment BLOB regression.
- Android manifest `android:allowBackup="false"` is an OS-level application backup opt-out. Preserve it; it is not the in-app Backup/Restore feature being removed.
- Academic reports are an active, separate screen under `lib/presentation/reports/academic_reports_screen.dart`, launched from the home screen. Preserve this route and the local report service.


| CI-03 | Repository-wide Dart format check finds 74 pre-existing unformatted files | Medium | The initial full-repository `dart format --output=none --set-exit-if-changed .` run reported 74 files requiring formatting, including unrelated legacy files. The scoped changed-file formatter gate passed on PR #68 exact head. | Do not mass-format unrelated files in this task; track repository-wide formatting debt separately. | IMPLEMENTED — SCOPED GATE VERIFIED; REPOSITORY-WIDE DEBT REMAINS |
