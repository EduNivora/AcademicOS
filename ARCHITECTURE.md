# EduNivora / AcademicOS — Architecture

## 1. Product and system boundaries

EduNivora is a student-owned personal academic operating system. A student creates and manages their own academic structure; the application is not dependent on a university portal, institutional administrator, or centrally provisioned course catalog.

The current repository is a Flutter client with local persistence. It is not yet a cloud-synchronized multi-device system. Do not describe local SQLite, secure storage, or Google sign-in as server-side synchronization.

## 2. Runtime architecture

The codebase uses a pragmatic Clean Architecture separation:

- `lib/presentation/`: screens, forms, navigation, and user interaction.
- `lib/providers/`: Riverpod state wiring.
- `lib/domain/`: academic entities, repository contracts, AI intent/action logic, and use cases.
- `lib/data/`: persistence models, local data sources, repository implementations, database access, and backup validation.
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

A successful local write means data was written to the configured local database; it does not imply remote replication or backup.

## 5. Authentication and application lock

Authentication-related secure-storage operations are implemented in `AuthSecureStorageService` and `AuthLocalDataSource`.

- New local account password verifiers and app-lock PIN verifiers use versioned Argon2id parameters.
- Legacy SHA-256 verifiers are accepted only for migration: after a successful credential check, the verifier is upgraded to Argon2id before the session is activated.
- Logout persists a logout-required marker, clears active session state and cached Google identity, and retains the local account verifier for a later explicit login.
- Auth-state read failures are handled fail-closed by the auth gate.
- App-lock failed-attempt state is persisted and exponentially throttled after repeated failures.

These controls protect credential verification and session transitions; they do not encrypt the SQLite database.

## 6. Database encryption status — release blocker

**SQLite database-at-rest encryption is not implemented.**

The application currently opens SQLite through sqflite/FFI factories. A database password value is generated and stored in secure storage, but it is not passed to an encrypted SQLite engine. The database file must therefore be treated as plaintext at rest.

Do not claim SQLCipher, SQLite encryption, or encrypted backups until an encrypted driver is integrated and verified with wrong-key tests, on-disk inspection, platform coverage, and a crash-safe migration from existing plaintext databases.

## 7. Backup and restore

Backup UI and serialization live in `lib/presentation/settings/backup_export_screen.dart`; validation lives in `lib/data/services/backup_payload_validator.dart`.

Current flow:

1. Read academic records from the local database.
2. Serialize a versioned JSON payload.
3. Save or select a backup through `file_picker`.
4. Validate the payload schema, row types, identifiers, dates, supported enums, schedule ranges, and course references before mutation.
5. Replace academic records through a database transaction.

Current limitations and security boundaries:

- The current implementation branch adds a SQLite `file_bytes BLOB` column and stores imported attachment bytes in the local database, which is persistent on the configured SQLite backend and also accepts bytes-only picker results.
- Existing native records are migrated on database open only when their canonical source path remains inside the legacy `systemTemp/academic_os_materials` directory; symlink escapes and unrelated absolute paths are rejected. Failed/missing legacy files remain metadata-only and are not silently treated as backed up.
- New JSON backup schema v3 serializes attachment bytes as base64 and validates/decodes them before the database transaction. Export refuses to label a backup complete when any legacy attachment has no stored bytes.
- PDF preview currently materializes a short-lived temporary copy from the persisted database bytes for the native viewer; that temporary preview is not the source of truth. Web document preview remains unsupported.
- The Release 1 integration branch passed its Flutter quality gate on exact head `8904bf0af783c7f01d24bbbd70922a69af680e15` (run `43753940254`): dependency resolution, Dart analysis, Flutter tests, Android Debug APK build, and artifact upload all succeeded. This CI result does not validate backup workflows or platform runtime behavior. Google Drive folder creation/upload, password-based archive encryption, checksums/manifest, encrypted restore staging/rollback, and end-to-end platform/failure-injection coverage remain Release 2 work.
- Cross-device and real-browser file picker behavior still require platform validation.

A JSON export must not be represented as a complete device backup until its referenced attachment files are included and verified.

**Release boundary:** Google Drive backup, password-protected backup archives and their upload/restore integrations are deferred to Release 2. Backup feature branches are parked and must not be merged into the Release 1 integration branch. Any existing backup UI must remain hidden/disabled in Release 1; do not claim that the current JSON export or in-progress integrations constitute a complete backup solution. The Release 1 team must still preserve durable local attachment storage because it is core local data persistence, not a backup feature.\n\n## 8. Quality and verification

The GitHub Actions workflow `.github/workflows/flutter-quality.yml` runs:

- Dependency resolution with the committed lockfile
- Dart analysis
- Flutter tests
- Android debug APK build
- APK artifact upload

Every result applies only to the exact commit SHA shown in the workflow run. Passing analysis/tests does not establish that an APK was built, and a successful debug build does not establish release readiness or physical-device compatibility.

## 9. Known architectural gaps

The following are explicit engineering work items, not implemented capabilities:

- Encrypted SQLite storage and a safe plaintext-to-encrypted migration.
- Portable attachment-aware backup/restore with checksums and rollback.
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
- Add regression tests with every persistence, authentication, migration, or backup change.


## 11. Approved product scope — Local-first student application

The Release 1 product direction is **Local-First + Optional Account + Public Notices**. Personal Google Drive backup is deferred to Release 2. The application must open and remain useful without authentication or network access.

### Guest and account flows
- A student may enter the application immediately as a guest; account creation is optional.
- Students may create/sign in to an account using Google or email/password.
- The central account database stores only the minimum identity/account fields required for authentication and account-linked notice receipts (for example, internal account ID, display name, email, provider identifier, and account timestamps/status).
- Academic records and academic files remain on the student's device. They are not uploaded to an EduNivora-operated cloud database and are not synchronized between devices.
- A guest can use local academic features and receive public notices without creating an account.

### Local academic data
Courses, terms, schedules, tasks, exams, notes, materials, attachments, preferences, and derived academic reports are local-only. Store attachments in durable app-owned storage, never a temporary directory. All routine academic CRUD must work offline.

### Release 2 — personal Google Drive backup (deferred; not part of Release 1)
- Backup destination: a normal, user-visible folder named `EduNivora` in the student's own Google Drive.
- Each student authorizes their own Google account; do not use a shared organization Drive or an application-owned pooled storage account.
- Backup is explicitly initiated by the student. Automatic/scheduled backup is not approved as a required behavior in this scope.
- A complete backup includes the local database, attachment bytes, and required app settings/metadata, with a versioned manifest and integrity checks.
- Encrypt the archive before upload. Use a student-chosen backup password and additional key protection (envelope/key-wrapping design); never store the password or plaintext encryption keys on the server or inside the backup.
- Derive a key-encryption key using a memory-hard password KDF (Argon2id with versioned parameters), generate a random data-encryption key, and wrap that key. Encrypt backup content using an authenticated encryption mode such as AES-256-GCM. Record only non-secret KDF/encryption parameters, salts, nonces, wrapped key material, version, and checksums needed for restore.
- A forgotten backup password means the encrypted backup cannot be recovered; explain this clearly before the first backup.
- Restore must validate the manifest, authentication tag, checksums, schema version, attachment paths, and all payload data before committing. Stage files first and use a recoverable/atomic database-and-file replacement strategy. Never overwrite current data silently.
- Google Drive is a personal backup destination only; it is not a live sync engine or a source of routine application reads/writes.

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
Encrypted Google Drive backups do not imply that the live SQLite database is encrypted at rest. Production database encryption remains a separate security/release gate and must not be claimed until implemented and tested.


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
Flutter integration, production OAuth/SMTP setup, trusted origins, admin
bootstrap, and receipt-retention policy are not yet accepted. Existing Flutter
authentication remains local until the managed client is implemented and
verified. Guest academic use remains available without a network connection.

Google Drive backup remains deferred to Release 2. No academic cloud sync is
introduced by this backend.
