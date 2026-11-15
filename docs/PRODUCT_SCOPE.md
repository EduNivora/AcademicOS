# EduNivora — Approved Product Scope

**Decision date:** 2026-11-15  
**Status:** Approved product direction  
**Repository:** `EduNivora/AcademicOS`

## 1. Product definition

EduNivora is a guest-first, local-first personal academic workspace. It helps an individual student organize their own academic life. It is not a university information system, institutional ERP, or student administration platform.

**Core rule:** academic data belongs to the student and remains on the student's device. Network services are limited to optional account identity, public notices and their minimal delivery/read receipts, and student-initiated backup to that student's own Google Drive.

## 2. Entry and identity

- The application opens directly without requiring authentication.
- Guest users can use the core academic features.
- Account creation/sign-in is optional and supports Google and email/password.
- The central account database stores only minimum identity/account data: internal account identifier, display name, email, authentication provider identifier, account timestamps and status.
- Do not store courses, schedules, tasks, exams, grades, notes, materials, attachments, or academic reports in the central account database.
- Account creation must not silently upload or synchronize local academic data.

## 3. Local academic workspace

The following data is local-only:
- Academic terms/semesters and student-defined structure.
- Courses and course metadata.
- Weekly schedule and personal events.
- Tasks, assignments, deadlines and exams.
- Notes and study plans.
- Grades, GPA inputs and derived reports.
- Course materials, documents, images and attachment bytes.
- Application preferences and local notification settings.

Requirements:
- Core academic operations work without internet.
- SQLite is the local structured store.
- Files use durable app-owned storage, not temporary directories.
- Local writes and file imports must be validated and recoverable.
- Data migrations and app upgrades must preserve user data.
- No academic cloud synchronization or server-side academic data storage is in scope.

## 4. Optional account and notices

Accounts are optional, but public notices are available to all installations, including guests.

### Notice behavior
- A minimal protected operator interface can create, edit, publish and retire notices, and inspect their reports.
- Notices are delivered to registered and guest installations through the available online delivery mechanism.
- Track three separate stages: server acceptance/publication, device delivery acknowledgement, and opening/viewing the notice.
- For registered users, delivery/read reports may show account name and event timestamps.
- For guests, retain anonymous aggregate counts only. Do not create a named guest profile or expose a stable identity.
- Delivery depends on internet availability, notification permission, platform capabilities and client check-in. Offline devices cannot provide real-time delivery/read confirmation.
- Collect the minimum event data required; apply a documented retention period and access control to reports.

The operator interface is strictly for notices. It is not an administration portal and has no student management, lecturer management, attendance, finance, institutional messaging, or university operations.

## 5. Personal Google Drive backup

### Approved destination and ownership
- Destination is a normal, visible folder named `EduNivora` in the student's own Google Drive.
- Each student connects and authorizes their own Google account.
- Use the narrowest practical OAuth scope and only access files created/selected by this app as permitted by the chosen Drive integration.
- Do not use a shared organizational Drive or central pooled storage.
- Backup is explicitly initiated by the student. Scheduled/automatic backup is not a required approved behavior at this stage.
- This feature is backup/restore only, not live sync.

### Backup contents
A complete backup includes:
- A versioned SQLite database snapshot.
- All attachment/document bytes referenced by local records.
- Required app settings and backup metadata.
- A manifest with schema version, file inventory, sizes and cryptographic checksums.

### Encryption and key protection
- The student chooses a backup password.
- Use a versioned memory-hard password KDF such as Argon2id with unique salt and documented parameters to derive a key-encryption key.
- Generate a cryptographically random data-encryption key and protect/wrap it with the derived key.
- Encrypt backup content with authenticated encryption such as AES-256-GCM, using unique nonces.
- The backup may contain non-secret metadata required for recovery (format version, KDF parameters, salt, nonce, wrapped data key and checksums), but never the plaintext password or plaintext encryption keys.
- EduNivora servers must never receive or store the backup password or plaintext encryption keys.
- Clearly warn that forgetting the backup password makes the backup unrecoverable.
- Reject incorrect passwords and tampered/corrupted archives before modifying local data.

### Restore safety
- Validate archive format, manifest, authentication tags, checksums, schema compatibility, record relationships and attachment paths.
- Extract into a staging area; reject traversal, symlink escapes and unsafe paths.
- Restore files and database as one recoverable operation. Use staging, atomic replacement where supported, rollback/recovery markers, and failure-injection tests.
- Never silently overwrite the current workspace. Show the target account/device and backup timestamp and require confirmation.
- Test restore after reinstall and on a different supported device/platform.

## 6. Explicit exclusions

The current scope excludes:
- University or institutional administration portals.
- Lecturer portals or lecturer accounts.
- Managing other students or student rosters.
- Official university attendance and university-system integrations.
- Institutional email, chat or correspondence.
- Tuition, fees, invoices and payments.
- University-level dashboards and ERP functions.
- Academic data cloud sync, multi-device conflict resolution and server-side academic file storage.
- Paid services or dependencies that require payment for core operation.

## 7. Security and privacy boundaries

- Account identity data, notice delivery/read events and backup authorization metadata are the only approved server-side data categories in this scope.
- Guest notice analytics are anonymous aggregates; do not retain a stable cross-session guest identifier for named tracking.
- Use access control for operator notice tools and audit publication/report access.
- Minimize notice event retention and document the retention period before production release.
- Encrypting a Google Drive backup does not mean the active SQLite database is encrypted at rest. Production database encryption remains a separate release gate.
- Never log OAuth access/refresh tokens, backup passwords, plaintext keys, or academic record contents.

## 8. Release acceptance gates

1. Fresh install opens without login and guest academic CRUD works offline.
2. Optional Google and email account flows work without uploading academic records.
3. Central database inspection confirms only approved account and notice metadata exists.
4. Attachments persist in durable app-owned storage across restart and upgrade.
5. Complete backup includes database and all attachment bytes.
6. Backup is written to the student's visible Google Drive `EduNivora` folder.
7. Wrong password, tampering, truncated upload and insufficient Drive quota fail safely.
8. Restore succeeds after reinstall and preserves relationships and file bytes; injected failures do not leave a mixed or corrupted state.
9. Registered notice receipts are name-linked; guest reports are anonymous aggregates.
10. Delivery, device receipt and view are measured separately; offline/permission-denied limitations are accurately shown.
11. Operator interface is limited to notice publishing/reporting.
12. Automated and platform-specific tests pass on the exact release candidate SHA.

## 9. Authoritative related documents

- [Architecture](../ARCHITECTURE.md)
- [Feature Acceptance Matrix](FEATURE_ACCEPTANCE_MATRIX.md)
- [README](../README.md)
