# AcademicOS — Phase 1 Readiness Audit

**Date:** 2026-11-21  
**Repository:** `EduNivora/AcademicOS`  
**Audited branch:** `feat/phase1-materials-unification`  
**Audited head before this report:** `a11e8a25d94eaff6a9b3d40d6846021110ba6fcb`  
**Base:** `main` at `a7b3a582d31ef9c381d5887cd09866ee51a87fe8`  
**Pull request:** [#44](https://github.com/EduNivora/AcademicOS/pull/44)

## 1. Executive result

The branch is six commits ahead of `main`, zero commits behind, and the comparison reports 58 changed files. PR #44 is open, mergeable, and still Draft. No review threads were returned at audit time. No merge or production deployment was performed.

The latest CI runs for head `a11e8a25d94eaff6a9b3d40d6846021110ba6fcb` both completed successfully:

- Flutter quality gate: [run 44824284873](https://github.com/EduNivora/AcademicOS/actions/runs/44824284873)
- Neon backend quality: [run 44824284895](https://github.com/EduNivora/AcademicOS/actions/runs/44824284895)

Flutter CI evidence:
- Dart analyzer: 0 errors, 0 warnings, 43 informational findings.
- Flutter automated tests: 161 passed.
- Native Android SQLite integration test: 1 passed on the emulator.
- Android Debug APK build: passed; package and launcher icon verification passed.
- Web Release build: passed.
- Production signed ARM64 APK: skipped because `PRODUCTION_SIGNING_READY=false`.
- CI artifact upload succeeded. The uploaded artifact archive size is not the same as the APK file size; the actual APK size has not been verified in this audit.

Neon backend CI completed syntax checks and backend tests successfully.

## 2. Implemented areas confirmed in the branch

- Academic profile model and profile-related fields.
- Materials naming/consolidation and stable material IDs used by related academic records.
- Weekly timetable image parsing path with review-oriented client flow and conflict validation.
- In-app document viewer integration for PDF/Word/PowerPoint formats.
- Task start/completion timestamp model changes and reminder-related fields.
- Notification service changes for task, course, and lecture reminders.
- Unified student Communications screen with notifications and announcements tabs.
- Academic report periods (daily, weekly, monthly, final) based on supplied local data.
- Assistant action executor covering profile, materials/files, tasks, lectures, and report actions, including confirmation paths for destructive operations.
- AI backend endpoint and Flutter remote data source integration.
- Removed/hidden grade-distribution and GPA presentation screens per the agreed Release 1 scope.

This inventory confirms code presence, not full end-to-end or physical-device correctness.

## 3. Confirmed gaps and release risks

### A. Gemini assistant is not production-ready yet
- `backend/neon/functions/ai/README.md` explicitly states `GEMINI_API_KEY` is not configured.
- The backend health endpoint only reports whether a key is configured; it does not prove model generation or action execution.
- The README lists durable per-account quota/rate limiting, Google AI usage limits, production web origin configuration (if Web is shipped), and real-session end-to-end tests as remaining gates.
- Local supported assistant actions exist, but Gemini-driven planning has not been verified against a real authenticated session and configured provider.

### B. Notification behavior lacks automated test coverage
- No notification-specific test file was found in the branch tree.
- Notification service initializes timezone data and sets the timezone to `Asia/Riyadh`; behavior must be verified against the intended device/user timezone policy.
- CI's SQLite emulator test does not verify notification delivery, reboot persistence, Android permission behavior, or exact-alarm fallback.
- These require deterministic unit tests plus physical-device acceptance tests.

### C. Document rendering is not device-verified
- Viewer code delegates to `offline_document_viewer` and has explicit PDF text extraction logic.
- No document-viewer-specific automated test file was found.
- PDF, DOC/DOCX, and PPT/PPTX rendering, large files, encrypted/corrupt files, and low-memory behavior remain device acceptance gates.

### D. Communications scope is intentionally limited
- `docs/communications-readiness.md` explicitly says contact reports create an email draft or copy a structured report; they are not submitted to a server.
- Official support channels remain pending approval/configuration.
- Do not implement a speculative ticket/chat backend in the next phase without an approved workflow specification.
- Announcements and student reminders are unified in the UI, but remain separate underlying data paths.

### E. SQLite at-rest protection is incomplete
- README explicitly states the local SQLite database is not encrypted in Release 1.
- Credentials/secrets use secure storage, but that does not encrypt the database file.
- Treat this as a documented security limitation and perform a threat/compatibility assessment before selecting an encryption migration. Do not change the DB engine or migrate user data without a tested backup/restore and migration plan.

### F. Database migration and relationship behavior need targeted regression coverage
- Database schema version is 13.
- Upgrade path adds `completed_at` for older databases and includes historical migrations through version 12.
- Course deletion currently removes dependent rows in an explicit transaction; do not assume SQL foreign-key cascade constraints exist merely because foreign-key enforcement is enabled.
- Add upgrade-path tests from representative older schema versions and verify preservation of existing student data before any schema change.

### G. Documentation is stale relative to the agreed Release 1 UI scope
- README still lists Grade Simulator, GPA Calculator, Target Grade Calculator, Grade Distribution, and academic-term management as current features/paths.
- These conflict with the PR's stated Release 1 scope where grade/GPA screens and triple-term UI are deferred/removed.
- Update documentation only after checking the actual routes and retained data model; do not delete valid historical schema solely to make the README match.

### H. Analyzer and CI maintenance
- Analyzer has 43 informational findings (no errors or warnings). They are non-blocking, but should be triaged separately rather than hidden.
- Workflow logs include GitHub Actions Node 20 deprecation warnings for some actions. This is maintenance work, not a current build failure.
- Existing CI enforces a 60 MiB limit only for the optional signed ARM64 APK path. The requested 35–50 MB target is not yet demonstrated.

## 4. Test coverage inventory

Present evidence:
- 161 Flutter automated tests passed in CI.
- 1 native Android SQLite integration test passed.
- Backend quality workflow passed.
- No notification-specific test file found.
- No document-viewer-specific test file found.
- No broad UI/navigation/widget acceptance suite identified in the branch tree for all critical workflows.

Next tests should be added narrowly around uncovered risks; do not duplicate existing tests.

## 5. Dependency map and execution boundaries

1. **Baseline audit (this document):** inventory, CI baseline, gaps and protected boundaries.
2. **Assistant activation:** configure server-side Gemini secret, validate real Neon Auth session, generation, structured action plan, allowlisted execution, confirmation, quota/rate limiting, and failure behavior. Do not rewrite the existing action executor unless a reproducible defect requires it.
3. **Data lifecycle integration:** only after the action contract is stable, test material/task/lecture/reminder/report links and migration/backward compatibility.
4. **UI and feature acceptance:** document viewer, timetable import, communications boundaries, all visible critical controls.
5. **Security, reliability and performance:** threat review, account isolation, offline/online behavior, timezone policy, measured performance.
6. **Physical-device acceptance:** notification delivery, document formats, auth, assistant, persistence, and restart/offline cases.
7. **Release and merge:** signing, APK size verification, release artifact validation, final CI, PR review, then merge only after gates pass.

Parallel work is limited to read-only reviews and independent test authoring. Do not concurrently alter database schema, assistant contracts, and notification scheduling. Keep all changes on the feature branch; do not force-push or modify `main`.

## 6. Phase 1 exit decision

**Audit completed; implementation changes intentionally not made during the audit.**

The branch has a successful automated baseline, but it is not release-ready. The next blocking work is Gemini activation and authenticated end-to-end assistant verification, followed by data-lifecycle and uncovered notification/document tests. Production signing and physical-device acceptance remain later release gates.

No claim is made that all UI, notifications, documents, AI actions, database upgrade paths, or performance have been verified end-to-end.


## Phase 1 implementation addendum — 2026-11-24

- A dedicated academic reports screen already exists at `lib/presentation/reports/academic_reports_screen.dart` and is opened from the home screen. It is preserved rather than recreated.
- The report service's backup payload serialization was separated from report generation by removing only backup-specific APIs.
- Restore-only `replaceAcademicData`, backup payload validation, and the combined backup/report screen are being removed. Ordinary academic CRUD, SQLite attachment BLOB persistence and report TXT export are retained.
- Acceptance remains pending until exact-head Flutter CI, analyzer and regression tests pass.
