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

- A documented key lifecycle (generation, secure storage, backup, rotation, loss and recovery).
- A crash-safe plaintext-to-encrypted migration with a verified backup, staged encrypted copy, integrity and row-count checks, atomic switch, restart recovery, and rollback.
- Failure-injection tests proving the original database remains recoverable after interruption at each migration stage.
- Validation of WAL/journal sidecars, database close/reopen, concurrency, corruption and backup behavior.
- A separate Web decision covering the exact `sqlite3mc.wasm` asset, worker setup, IndexedDB persistence, reload/reopen, multi-tab behavior and wrong-key rejection.
- Platform-specific secure-storage and physical-device tests for every platform actually claimed as supported.

## Release rule

Until all required evidence exists, keep Issue #3 open, keep the feature matrix at **Not implemented**, and do not describe EduNivora's local database as encrypted. No production driver switch or data migration is authorized by this evaluation.
