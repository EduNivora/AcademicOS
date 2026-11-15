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

- Course-material records in the JSON backup are metadata only; attachment bytes are not packaged.
- The current material UI copies files into `Directory.systemTemp/academic_os_materials`, not a durable app-owned documents/support directory. The OS or runtime may purge this temporary location.
- Deleting a material currently removes its database row but does not remove the copied file, so orphaned files can accumulate.
- The Web picker path currently rejects the bytes-only result instead of storing it in browser-owned persistent storage.
- The backup validator currently checks `file_path` only as a non-empty string. The PDF viewer consumes the stored path directly; imported absolute or traversal paths are not yet constrained to an app-owned attachment root. Treat material paths from imported backups as untrusted metadata and do not open them until attachment ownership/path containment is implemented.
- Checksummed attachment archives, safe generated names, canonical-path containment, staged file restoration, database/file rollback, and end-to-end failure-injection coverage remain unimplemented.
- Cross-device and real-browser file picker behavior still require platform validation.

A JSON export must not be represented as a complete device backup until its referenced attachment files are included and verified.

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
