# SQLite at-rest encryption decision

**Date:** 2026-11-15  
**Status:** Evaluation only — production encryption is not implemented  
**Scope:** Native SQLite encryption and the separate Web runtime

## Decision

Do **not** change the production database driver, add a `PRAGMA key` call to the existing factory, or migrate any user database in this change set.

The current implementation does not encrypt the database. During startup, `AppInitializer` calls `SecureStorageService.getDatabasePassword()`, which creates or reads a value stored under `academic_os_db_password`. `AuthSecureStorageService` also exposes a helper for the same key, but neither service passes that value into the production `DatabaseHelper` or an encrypted SQLite engine. Issuing `PRAGMA key` to the current unencrypted engine would not establish encryption and must not be treated as a security fix.

The candidate for an isolated compatibility proof is **SQLite3 Multiple Ciphers (SQLite3MC)** through the `sqlite3` v3 build hook and `sqflite_common_ffi`. This is a candidate, not an approved production architecture.

## Evidence from the current branch

The application lockfile currently resolves:

- `sqflite` 2.4.2
- `sqlite3` 2.9.4
- `sqflite_common_ffi` 2.3.6
- `sqflite_common_ffi_web` 1.0.1+1

The production database factory currently routes:

- Android/iOS use the `sqflite` platform plugin factory.
- Windows/Linux/macOS use `databaseFactoryFfi`.
- Web through `databaseFactoryFfiWeb`.

The FFI factory is therefore **not** the current Android database engine. Selecting SQLite3MC for the FFI package alone would not encrypt Android databases while Android continues using the native `sqflite` plugin.

## Candidate compatibility evidence

The upstream `sqlite3` package documents native builds for Android, iOS, macOS, Linux and Windows, and documents encrypted builds using the `sqlite3mc` source in its build-hook configuration. It also publishes a separate `sqlite3mc.wasm` asset for Web.

The upstream `sqflite_common_ffi` documentation states that its 2.4.0+ line uses `sqlite3` 3.x and supports Android/iOS as well as desktop platforms. This makes a controlled FFI proof plausible, but does not prove that this application's factory, file locations, migrations, background execution, or platform packaging are correct.

The Web path is separate. This repository currently pins `sqflite_common_ffi_web` 1.0.1+1 and `sqlite3` 2.9.4. The package changelog records that 1.0.2 uses the SQLite 2.9.4 generation, while 1.1.1 moves to SQLite 3.1.x and requires Dart 3.10. Later 1.2.1/1.2.2 releases require Dart 3.12 and include fixes to the custom WASM URL setup option. The current CI experiment pins Dart 3.11.5. The existing worker-setup failure with SQLite 3 build hooks is an additional unresolved compatibility concern. Consequently, Web encryption is not accepted by the native FFI proof.

References:

- https://pub.dev/packages/sqlite3
- https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html
- https://pub.dev/packages/sqflite_common_ffi
- https://pub.dev/packages/sqflite_common_ffi_web/changelog
- https://pub.dev/packages/sqflite_common

## Executed isolated-proof evidence — 2026-11-15

Draft [PR #12](https://github.com/EduNivora/AcademicOS/pull/12) now contains the separate package at `tool/sqlite3mc_poc/`.

- Exact proof dependencies: `sqlite3 3.1.7`, `sqflite_common_ffi 2.4.0+3`, `sqflite 2.4.2`, and `flutter_secure_storage 9.2.4`.
- SQLite3MC is selected through the `sqlite3` build hook (`source: sqlite3mc`).
- The probe uses `databaseFactoryFfi` and verifies the standard SQLite header and a plaintext canary are absent, a wrong key cannot read `sqlite_master`, and the correct key can reopen and read the schema/row.
- Proof head `fb0e5d1333c3c75bb6a5e7aaa84cfe8c8c857d6a` passed Linux host and Android emulator encryption tests in [run #8](https://github.com/EduNivora/AcademicOS/actions/runs/43665384937).
- Follow-up head `bacd1c0b7bd0d78506353081645a2c74caf1e4ea` adds same-process Android coexistence checks for the existing platform `sqflite` plugin, `flutter_secure_storage`, and the candidate FFI engine. Run #13 (`43667685824`) passed dependency resolution, analysis, host encryption, Android APK build and artifact upload; its Android emulator runtime test was still in progress at the time of this update.
- Follow-up commit `0b71a102b13ec27460dbdbc8e880d89c61f92d8f` adds `PRAGMA integrity_check` after the wrong-key attempt and correct-key reopen. New proof run [`43669623653`](https://github.com/EduNivora/AcademicOS/actions/runs/43669623653) is in progress, as is the root Flutter quality run [`43669500715`](https://github.com/EduNivora/AcademicOS/actions/runs/43669500715).

This proves only the isolated FFI candidate on the recorded host/Android paths. It does not prove that production Android's current `sqflite` factory is encrypted, nor that the full AcademicOS database helper can safely switch to FFI. No production dependency, factory, schema, key lifecycle or student database was changed.

## Production integration and migration gates

Before production adoption, the actual AcademicOS schema and database helper must be exercised through the proposed encrypted factory. At minimum:

1. Keep the current production factory unchanged while validating a test-only integration path against all schema version 10 tables and CRUD operations.
2. Prove Android FFI coexistence with the complete production plugin set, not only `sqflite` and secure storage; repeat on a physical device.
3. Verify Windows runtime/packaging and any other app target independently. A Linux host proof is not a Windows app proof.
4. Verify the exact `sqlite3mc.wasm` asset and worker integration, IndexedDB persistence, reload/reopen, offline and multi-tab behavior before any Web encryption claim.
5. Generate one cryptographically random key per database and persist it using the target platform's secure-storage mechanism. A missing key for an existing encrypted database must fail closed; never generate a replacement and create an empty database.
6. Apply the key before schema access. Verify wrong-key rejection at `sqlite_master`, on-disk ciphertext/canary absence, `PRAGMA integrity_check`, and `PRAGMA foreign_key_check`.
7. Define key loss, rotation and secure key recovery. AcademicOS does not provide archive export or cross-device restore; never expose the raw database key.
8. Migrate through a verified staging database: close handles, checkpoint/resolve WAL safely, preserve the original file until the staged database passes verification, compare schema and row counts, run integrity/foreign-key checks, reopen with the correct key and reject a wrong key.
9. Switch only after verification using a durable migration marker and atomic file transition. Keep the original recoverable until a successful post-migration launch.
10. Inject failures before and after every migration state transition, close, checkpoint, write and rename. Prove restart recovery selects either the intact original or the verified encrypted copy; never leave the user with neither.
11. Test concurrent access, WAL recovery, process termination, corruption and insufficient disk space.

Do not use a raw file copy of an active WAL database as the migration mechanism. This is an internal migration-safety procedure, not a user-facing data export or restore feature. Do not treat `PRAGMA key` success by itself as evidence of encryption.

## Isolated proof required before production selection

The isolated proof must not alter the production `pubspec.yaml`, production database factory, database schema, or existing user data. It must use a separate package/branch and an explicit `sqlite3mc` build-hook selection.

Minimum proof assertions:

1. Create a database only after applying a key through the candidate encrypted engine.
2. Insert a unique plaintext canary, close the database, and verify the database file does not expose the SQLite plaintext header or canary.
3. Reopen with the correct key and successfully query `sqlite_master` and the canary row.
4. Reopen with a wrong key and prove that reading `sqlite_master` fails. Merely executing `PRAGMA key` is not evidence.
5. Exercise the same `sqflite_common` API path proposed for the app, not only a standalone SQLite API.
6. Build the Android application with the candidate native library; separately run an Android emulator/device integration test before claiming Android runtime compatibility.
7. Record exactly which OS/architectures were built and executed. Do not infer iOS, macOS, Linux or Windows acceptance from an Android build.

A passing proof is still not production approval. Production work additionally requires:

- A documented key lifecycle (generation, secure storage, rotation, loss and recovery).
- A crash-safe plaintext-to-encrypted migration with a verified staging database, integrity and row-count checks, atomic switch, restart recovery, and rollback.
- Failure-injection tests proving the original database remains recoverable after interruption at each migration stage.
- Validation of WAL/journal sidecars, database close/reopen, concurrency and corruption.
- A separate Web decision covering the exact `sqlite3mc.wasm` asset, worker setup, IndexedDB persistence, reload/reopen, multi-tab behavior and wrong-key rejection.
- Platform-specific secure-storage and physical-device tests for every platform actually claimed as supported.

## Release rule

Until all required evidence exists, keep Issue #3 open, keep the feature matrix at **Not implemented**, and do not describe EduNivora's local database as encrypted. No production driver switch or data migration is authorized by this evaluation.
