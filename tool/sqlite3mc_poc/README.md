# SQLite3MC isolated proof

This is a disposable proof package. It is not imported by the AcademicOS application and does not change the production database driver or existing user data.

The package pins the SQLite 3 generation and selects the SQLite3 Multiple Ciphers build through the `sqlite3` build hook:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

The shared probe exercises the `sqflite_common` API through `databaseFactoryFfi`. It creates a database with a test-only key, inserts a unique canary, closes the database, checks that neither the normal SQLite file header nor the canary is visible in the file, verifies that a wrong key cannot read `sqlite_master`, and finally verifies correct-key reopen.

## Run locally

From this directory, with Flutter 3.41.8 / Dart 3.11.5 or later:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The Android integration test is intended to run on an emulator or physical Android device:

```sh
flutter test integration_test/sqlite3mc_android_test.dart -d <device-id>
```

## CI status and resource note

The first hosted Android emulator attempt reached the emulator provisioning step but the runner ran out of disk while installing the Android 35 x86_64 system image. The workflow now frees unused runner space before emulator setup. Do not count Android runtime compatibility as verified until a subsequent emulator test completes successfully.

## Explicit limitations

- The fixed keys are test fixtures only; this package contains no production key lifecycle or secure-storage integration.
- A host test and Android emulator test do not prove iOS, macOS, Linux, or Windows release compatibility.
- An Android build alone is packaging evidence, not runtime encryption evidence.
- No existing plaintext AcademicOS database is opened or migrated.
- No crash-safe migration, rollback, backup/restore, WAL recovery, key rotation, or key-loss recovery is implemented here.
- This does not validate the WebAssembly worker, IndexedDB persistence, or `sqlite3mc.wasm`.
- A passing proof is necessary compatibility evidence only; it is not authorization to switch the production factory.
