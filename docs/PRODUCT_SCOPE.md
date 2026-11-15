# EduNivora — Approved Product Scope

**Decision date:** 2026-11-15  
**Status:** Approved product direction  
**Repository:** `EduNivora/AcademicOS`

## 1. Product definition

EduNivora is a guest-first, local-first personal academic workspace. It helps an individual student organize their own academic life. It is not a university information system, institutional ERP, or student administration platform.

**Core rule:** academic data belongs to the student and remains on the student's device. For Release 1, network services are limited to optional account identity and public notices with minimal delivery/read receipts. Personal Google Drive backup is deferred to Release 2.

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

## 5. Release 2 — deferred personal backup

**Decision (2026-11-15): Google Drive backup and restore are explicitly excluded from Release 1 and deferred to Release 2.** This is a deliberate release-scope decision, not a claim that backup is complete.

The following approved product decisions remain the target for Release 2:
- Destination: a normal, visible `EduNivora` folder in each student's own Google Drive.
- Backup is student-initiated and is backup/restore only, never live sync.
- A complete archive must include the database snapshot, attachment bytes, required settings, a versioned manifest and integrity checks.
- Encrypt before upload using a student-chosen password, a memory-hard KDF such as Argon2id, a random data-encryption key and authenticated encryption. Never persist plaintext passwords or keys.
- Restore must validate the archive and all content before mutation, stage files, support rollback/recovery, and require explicit overwrite confirmation.
- Release 2 acceptance must include cross-device/reinstall restore, platform tests, interrupted transfer/corruption/wrong-password/no-space failure tests, and evidence tied to the release candidate.

Any backup-related code already present on feature branches is retained as unaccepted work-in-progress. It must not be merged into the Release 1 branch, surfaced as an available Release 1 feature, or represented as production-ready. Reassess and rebase it when Release 2 planning begins.

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
5. Registered notice receipts are name-linked; guest reports are anonymous aggregates.
6. Delivery, device receipt and view are measured separately; offline/permission-denied limitations are accurately shown.
7. Operator interface is limited to notice publishing/reporting.
8. Automated and platform-specific tests pass on the exact release candidate SHA.

Google Drive backup, encrypted archives, upload and restore are Release 2 acceptance gates only; they are not Release 1 blockers.

## 9. Authoritative related documents

- [Architecture](../ARCHITECTURE.md)
- [Feature Acceptance Matrix](FEATURE_ACCEPTANCE_MATRIX.md)
- [README](../README.md)


## 10.1 Release 1 cloud provider decision — 2026-11-15

The Release 1 cloud metadata provider is the dedicated Neon project `edunivora`
(PostgreSQL 17, AWS Europe Central / Frankfurt). Neon Managed Auth (Better Auth)
is enabled for optional identity. This provider decision does not change the
local-first rule: academic records and files remain in local SQLite.

The app-owned cloud schema is restricted to profile/role projection, public
announcements, registered delivery/read receipts, anonymous daily guest event
counters, and notice-admin audit metadata. Password hashes, OAuth credentials,
academic records, attachments, and academic reports are not stored in the
app-owned tables.

Implementation status must be reported accurately: Neon Auth and the schema are
provisioned, and the Notices API is deployed to the Neon default branch with
health, public-feed and unauthenticated-admin smoke checks passing. The Flutter
client now contains the Neon email/password and OTP authentication adapter,
native secure session-cookie storage, Web credential-cookie transport, and
Bearer-token receipt integration. These client paths have automated unit tests,
but real-account Android/Web end-to-end acceptance is still open. Production
Google OAuth credentials, production SMTP, the final Web trusted origin,
controlled first-admin bootstrap, retention policy, guest metric abuse controls,
and end-to-end platform verification remain open gates.
