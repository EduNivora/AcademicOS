# EduNivora / AcademicOS — Architecture

## 1. Product and system boundaries

EduNivora is a student-owned personal academic operating system. A student creates and manages their own academic structure; the application is not dependent on a university portal, institutional administrator, or centrally provisioned course catalog.

The current repository is a Flutter client with local persistence. It is not yet a cloud-synchronized multi-device system. Do not describe local SQLite, secure storage, or Google sign-in as server-side synchronization.

## 2. Runtime architecture

The codebase uses a pragmatic Clean Architecture separation:

- `lib/presentation/`: screens, forms, navigation, and user interaction.
- `lib/providers/`: Riverpod state wiring.
- `lib/domain/`: academic entities, repository contracts, AI intent/action logic, and use cases.
- `lib/data/`: persistence models, local data sources, repository implementations, and database access.
- `lib/core/`: application initialization, platform decisions, security, notifications, themes, and cross-cutting academic services.
- `lib/features/`: feature-specific modules where present.

The intended dependency direction is Presentation → Domain contracts/use cases ← Data implementations. Shared infrastructure belongs in Core. Some legacy areas may not yet follow this boundary consistently; new work should not expand those violations.

## 3. Startup and persistence lifecycle

Startup is coordinated by `AppInitializer`:

1. On platforms with native secure storage, initialize/read the secure-storage value before opening the database.
2. Select the database factory for the current platform.
3. Open the persistent database and apply schema configuration/migrations.
4. Propagate initialization errors to the startup boundary. The app displays a retryable failure state rather than silently substituting an in-memory database.

Database implementation: `lib/data/database/database_helper.dart`.

- Android/iOS use the sqflite platform implementation where available.
- Windows/Linux/macOS select `sqflite_common_ffi`.
- Web selects `sqflite_common_ffi_web`.
- Foreign-key enforcement and WAL journal mode are enabled in database configuration.
- Schema creation and upgrades are versioned in `DatabaseHelper`.

The repository currently declares Android, Web, and Windows as configured targets in its README. Other platform directories/builds must be verified before claiming support.

## 4. Data model and integrity

The local academic database currently stores core student records including:

- Academic terms
- Courses
- Tasks
- Exams
- Weekly schedule entries
- Course materials metadata

Persistence models live in `lib/data/models/`. Database operations and transactions are centralized in `DatabaseHelper`. Academic workflows should validate relationships (for example, course references) at the boundary and preserve referential integrity in storage.

A successful local write means data was written to the configured local database; it does not imply remote replication.

## 5. Authentication and application lock

Authentication-related secure-storage operations are implemented in `AuthSecureStorageService` and `AuthLocalDataSource`.

- New local account password verifiers and app-lock PIN verifiers use versioned Argon2id parameters.
- Legacy SHA-256 verifiers are accepted only for migration: after a successful credential check, the verifier is upgraded to Argon2id before the session is activated.
- Logout persists a logout-required marker, clears active session state and cached Google identity, and retains the local account verifier for a later explicit login.
- Auth-state read failures are handled fail-closed by the auth gate.
- App-lock failed-attempt state is persisted and exponentially throttled after repeated failures.

These controls protect credential verification and session transitions; they do not encrypt the SQLite database.

## 6. Local database security status — Release 1 decision

**SQLite database-at-rest encryption is intentionally deferred to Release 2.**

Release 1 continues to use the existing sqflite/FFI database implementation. The database file is not encrypted at rest; secure storage protects selected credentials and secrets only. This is a documented product-scope decision, not a completed encryption feature or a Release 1 blocker.

Do not introduce an encrypted SQLite driver or plaintext-to-encrypted migration into Release 1. Reassess platform-specific database encryption as part of Release 2.

## 7. Academic reports

Academic reporting is a standalone local feature:

- UI: `lib/presentation/reports/academic_reports_screen.dart`.
- Service: `lib/core/academic/academic_report_service.dart`.
- Entry point: the home screen opens `AcademicReportsScreen`.
- Inputs are read from the existing local database through `DatabaseHelper`: courses, tasks, exams and weekly schedule.
- The service generates daily, weekly, monthly and final text reports. It does not infer attendance, grades or GPA from missing source data.
- The screen previews the generated text and supports saving a TXT file and copying the report to the clipboard.
- Report generation is independent of database mutation and whole-workspace replacement.

**Product boundary:** AcademicOS has no backup, restore, archive, cloud-drive transfer, or whole-database replacement capability. Report export is a text-report output only and must never be described as a backup.

## 8. Quality and verification

The GitHub Actions workflow `.github/workflows/flutter-quality.yml` runs:

- Dependency resolution with the committed lockfile
- Dart analysis
- Flutter tests
- Android debug APK build
- APK artifact upload

Every result applies only to the exact commit SHA shown in the workflow run. Passing analysis/tests does not establish that an APK was built, and a successful debug build does not establish release readiness or physical-device compatibility.

## 9. Known architectural gaps

The following are explicit engineering work items, not implemented capabilities:

- Release 2: evaluate local SQLite encryption and a safe migration strategy; it is intentionally out of Release 1 scope.
- Platform-by-platform build and runtime verification.
- Real-device Argon2id performance measurements.
- Release signing and distribution configuration.
- A verified cloud sync architecture, conflict resolution, and multi-device data lifecycle (if/when sync is added).
- A complete feature acceptance matrix covering all student workflows.

## 10. Change discipline

- Preserve student ownership and local-first operation.
- Never silently fall back from persistent storage to ephemeral memory.
- Validate imported data before mutation; use transactions for multi-record replacement.
- Keep secrets out of logs and source control.
- Do not claim encryption, synchronization, platform support, or release readiness without reproducible evidence.
- Add regression tests with every persistence, authentication, or migration change.


## 11. Approved product scope — Local-first student application

The product direction is **Local-First + Optional Account + Public Notices**. Backup and restore are excluded from AcademicOS. The application must open and remain useful without authentication or network access.

### Guest and account flows
- A student may enter the application immediately as a guest; account creation is optional.
- Students may create/sign in to an account using Google or email/password.
- The central account database stores only the minimum identity/account fields required for authentication and account-linked notice receipts (for example, internal account ID, display name, email, provider identifier, and account timestamps/status).
- Academic records and academic files remain on the student's device. They are not uploaded to an EduNivora-operated cloud database and are not synchronized between devices.
- A guest can use local academic features and receive public notices without creating an account.

### Local academic data
Courses, terms, schedules, tasks, exams, notes, materials, attachments, preferences, and derived academic reports are local-only. Store attachments in durable app-owned storage, never a temporary directory. All routine academic CRUD must work offline.

### Public notices and minimal operator console
- Notices are centrally authored and published to all application installations, including guests and registered accounts.
- Delivery/read tracking is distinct: server acceptance, device delivery acknowledgement, and user opening the notice are separate events.
- For registered accounts, the operator's notice report may show the student's account name and timestamps for delivery/read receipts.
- For guests, retain anonymous aggregate delivery/read counts only; do not expose a guest identity or stable personal profile.
- A minimal, separately protected operator interface may create/edit/publish notices and inspect notice reports only. It is not a university administration portal and must not grow into student, lecturer, attendance, finance, or institutional management.
- Actual delivery depends on connectivity, notification permission, platform push capability, and the installation checking in; never claim guaranteed instantaneous delivery to offline devices.

### Explicit exclusions
No institutional portal, lecturer portal, student administration, official university attendance integration, institutional messaging/email, tuition/fees/payments, university dashboards, academic cloud sync, or server-side storage of student academic records/files.

### Security distinction
Backup and restore are excluded from AcademicOS. Local SQLite-at-rest encryption remains a separate security decision.


## 12. Release 1 cloud metadata backend — Neon

The dedicated Neon project `edunivora` is the PostgreSQL provider for optional
accounts and public notices only. Neon Managed Auth (Better Auth) owns the
`neon_auth` schema, password verification, OAuth identities, email
verification, and sessions. The app-owned `public.app_users` table is only a
minimal profile/role projection linked by UUID to `neon_auth."user"(id)`; it
does not store passwords or session tokens.

App-owned cloud tables:
- `app_users`: profile and notice-operator role projection.
- `announcements`: plain-text public notices.
- `announcement_deliveries` and `announcement_reads`: registered account
  acknowledgements.
- `announcement_guest_daily_metrics`: aggregate guest delivery/view counters
  with no guest identifier.
- `announcement_admin_audit`: narrow audit events for notice administration.

The intended API is a Neon Function (Hono + Node.js 24 + PostgreSQL `pg`
pool). It verifies Managed Auth JWTs using the branch JWKS and performs
server-side role checks. The database URL and Auth keys must never be shipped
inside the Flutter client.

Current implementation boundary: Neon Auth and database schema are provisioned,
and the Notices API is deployed to the Neon default branch. Health and public
feed smoke tests pass; unauthenticated admin access is rejected. The API source,
tests and deployment artifact are on `feat/neon-managed-auth-and-notices`.
The Flutter client now contains the Managed Auth REST adapter and email/OTP
screens, with unit tests for request routing and session handling. Real-account
end-to-end tests on Android and Web remain unaccepted. Production OAuth/SMTP,
trusted origins, admin bootstrap, guest-metric abuse controls, and receipt
retention policy remain open release gates. Guest academic use remains available
offline.

Backup and restore are excluded from AcademicOS. No academic cloud sync is
introduced by this backend.
