# Android QA Release (ARM64)

## Purpose

The QA workflow produces an obfuscated Flutter **release-mode** APK for ARM64 without using the production upload keystore or production GitHub secrets. It is a test artifact, not a Play Store or production distribution package.

## Build configuration

- Android application ID and namespace remain `com.arfatalkamli.academicos`.
- Display label is verified as `EduNivora`.
- Flutter version in CI: `3.41.8`; Java: `17`; Android NDK: `28.2.13676358`.
- Build flags: `--release --target-platform android-arm64 --split-per-abi --obfuscate`.
- Dart symbols are written outside the APK to `build/symbols/qa` and included in the Actions artifact.
- Existing R8 minification and resource shrinking remain enabled.
- The APK must be no larger than **31,457,280 bytes (30 MiB)**. The workflow fails closed and uploads no APK if the limit is exceeded.
- The workflow verifies the package ID, app label, APK signature, exact byte size, and SHA-256 checksum before upload.
- The verified APK, checksum, package metadata, signature report, and obfuscation symbols are retained as a GitHub Actions artifact for 30 days.

## QA signing isolation

The QA build explicitly sets:

```bash
ORG_GRADLE_PROJECT_qaRelease=true
```

Gradle signs this QA artifact with the Android Gradle Plugin's local **debug** signing configuration. The QA path rejects the presence of any non-empty production signing input:

- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

No production signing secrets are passed to the QA workflow. The production release path remains separate and continues to require its configured production keystore. Do not use a QA-signed APK for Google Play or as a production update.

## Installation warning

The QA APK deliberately keeps the production `applicationId`, as required for identity compatibility. Its debug certificate is different from the production upload certificate. Therefore Android will reject it as an in-place update over an installed production-signed EduNivora app (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`).

**Do not uninstall an existing production installation just to test this APK.** Uninstalling would remove that app's local data. Use a clean, separate Android test device or emulator that does not contain the production-signed app. No database backup, restore, migration, or production database change is part of this QA workflow.

## CI checks and limitations

The workflow runs the repository's changed-Dart-file formatting gate, the same analyzer policy used by the main Flutter quality workflow (errors and warnings fail; info-level lints are reported but do not fail the gate), and the Flutter unit/widget test suite before building.

The independent QA workflow does not claim a physical-device test or a release-mode Android emulator smoke test. Android integration coverage remains in the main Flutter quality workflow. A successful artifact build and signature verification do not, by themselves, prove production runtime acceptance of R8/resource shrinking; release runtime acceptance remains a separate gate.
