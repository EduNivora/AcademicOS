# EduNivora / AcademicOS — Execution Roadmap

## Product contract

EduNivora is a student-owned personal academic operating system. It is not tied to a university, institution, or administrator portal. Each student configures their own academic structure: terms, courses, schedules, tasks, exams, study plans, grades, materials, reminders, and preferences.

Product principles:
- Student-first: the student controls their workspace and academic structure.
- Offline-first: core academic workflows must remain usable without a network connection.
- Privacy-first: academic records are private and local by default.
- Security by design: fail closed on storage/authentication errors; encrypt sensitive persisted data.
- Modular: features remain independently testable and extensible.
- Cross-platform: supported platforms must be explicitly declared and tested; no claim of universal support without CI/device evidence.

## Current repository reality (2026-11-15)

The repository is a Flutter application with a local SQLite/sqflite data layer and a broad set of academic screens. Existing code includes tasks, courses, weekly schedules, exams, grades/GPA tools, study planning/focus, reminders, academic reporting/dashboard, local auth/Google auth integration, app lock, settings, and backup UI. Feature presence in source is not proof that every workflow is complete or production-ready.

### Recently implemented on the unified execution branch
- Brand identity unified as `EduNivora` across UI, app label, launcher icon, and splash screen, while preserving technical namespace `com.arfatalkamli.academicos`.
- Native SQLite on Android runs via `sqflite` platform channel with fail-closed initialization and no in-memory fallback.
- Native Google Sign-In and Neon Auth loopback / deep-link session authentication implemented and unit-tested (`test/neon_google_auth_test.dart`).
- Official EduNivora launcher icons generated for all densities (adaptive, round, monochrome).
- Kotlin build configuration fixed on Windows (`kotlin.incremental=false`) to ensure reproducible builds across drives.
- Flutter analyze reports 0 errors and 0 warnings.
- 134 automated unit and widget tests passing (100% pass rate).
- Android debug build passes and verified with AAPT (`package: com.arfatalkamli.academicos`, `application-label: 'EduNivora'`).
- Android production release workflow (`.github/workflows/android-production-release.yml`) established for signed APK and AAB.

### Explicitly not complete
- SQLite database-at-rest encryption is not implemented. The secure-storage database key is not connected to an encrypted SQLite engine.
- Backup currently does not package attachment bytes. Course-material metadata can contain device-local paths; that is not a portable attachment backup.
- Attachment import/export, file integrity checks, and cross-device restore are not complete.
- Cross-platform file-picker behavior and browser persistence have not been validated on real targets.
- CI on the newest unified head must complete analysis, all tests, and Android build before that head is considered verified.
- No physical-device, browser, desktop, release-signing, migration/rollback, or store-distribution validation has been recorded.
- PIN lockout is not a substitute for secure database encryption, OS-level protection, or a full threat model.

## Release gates (must all pass before 1.0)

### Gate A — Build and quality
- [ ] Pin Flutter/Dart and dependency versions; commit reproducible lockfile.
- [ ] Flutter analyze has zero errors/warnings and agreed info baseline.
- [ ] All unit, widget, integration, migration, and regression tests pass.
- [ ] Android debug and release builds pass.
- [ ] iOS, Windows, macOS, Linux, and Web builds pass for every platform declared supported.
- [ ] CI covers every supported target; artifacts are traceable to commit SHA.
- [ ] No unreviewed draft PRs or failing required checks.

### Gate B — Persistence and data integrity
- [ ] Schema migrations are versioned and tested from every supported prior schema.
- [ ] Foreign keys, indexes, constraints, transactions, and recovery behavior are verified.
- [ ] Database encryption at rest is implemented and cryptographically verified on each supported platform.
- [ ] Wrong-key open fails closed; key rotation and recovery are tested.
- [ ] Plaintext-to-encrypted migration has backup, integrity verification, atomic switch, and rollback.
- [ ] No database or attachment writes are silently redirected to ephemeral storage.

### Gate C — Backup and restore
- [ ] Versioned backup format and strict schema validation.
- [ ] Export/import through native and Web-supported file flows.
- [ ] Package attachment bytes with safe relative paths, size limits, checksums, and MIME validation.
- [ ] Restore stages into temporary storage, verifies all data/files/references, then atomically commits.
- [ ] Failure injection proves original data remains intact after any interrupted restore.
- [ ] Cross-device restore is verified, not just same-device JSON parsing.

### Gate D — Identity and application security
- [ ] Argon2id migration tests and real-device performance benchmarks.
- [ ] Persistent PIN retry throttling and corrupt-state fail-closed tests.
- [ ] Session lifecycle, logout, credential replacement, guest mode, Google sign-in/out tested.
- [ ] Secrets and tokens never logged; secure storage behavior verified on each OS.
- [ ] Threat model, privacy/data-retention policy, and security review completed.
- [ ] Dependency and static security scans pass.

### Gate E — Feature acceptance
- [ ] Every student workflow has acceptance criteria and unit/widget/integration coverage.
- [ ] Course/task/exam/schedule/grade/material relationships are validated.
- [ ] Time zones, daylight-saving transitions, recurring schedules, and notification permissions tested.
- [ ] Empty, loading, error, offline, and recovery states exist for every network/data workflow.
- [ ] Arabic RTL and English LTR, accessibility, responsive layouts, and theme behavior tested.
- [ ] AI assistant actions are deterministic, permission-scoped, explainable, and safe on malformed input.

### Gate F — Operational readiness
- [ ] Crash reporting is privacy-reviewed and does not capture academic content or secrets.
- [ ] Logging, diagnostics, exportable support bundle, and recovery instructions are ready.
- [ ] Release signing, versioning, changelog, store metadata, and rollback plan are complete.
- [ ] Performance, memory, battery, startup, and large-dataset tests meet agreed budgets.

## Platform policy

Do not claim all platforms based on a dependency's advertised support. Maintain a platform matrix for database, secure storage, notifications, biometrics, file import/export, and AI/network capabilities. A platform is supported only when its CI build and critical workflows pass on that platform.

## Working agreement

- Product owner: scope, student workflows, acceptance criteria, and product quality.
- Technical lead: architecture, implementation, database, security, CI, and technical validation.
- Decisions affecting data compatibility, security, supported platforms, or releases require joint review.
- Keep changes in reviewable pull requests. Do not merge to main until required checks pass and release blockers are resolved.
- Never report completion percentages without a traceable feature/acceptance matrix.
