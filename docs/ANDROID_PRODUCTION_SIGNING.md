# Android production signing and release

This repository builds both a production APK and an Android App Bundle (AAB) with the same dedicated upload keystore. The keystore and its passwords must never be committed to Git.

## 1. Generate the upload keystore on a trusted computer

Run this in PowerShell on the computer where you will keep the offline backup:

```powershell
keytool -genkeypair -v `
  -keystore edunivora-upload.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -alias edunivora-upload
```

Choose strong passwords when prompted. Keep the keystore file and both passwords in a secure offline backup. Losing the upload key can interrupt future updates; do not regenerate it for subsequent releases.

## 2. Add GitHub Actions repository secrets

Open: https://github.com/EduNivora/AcademicOS/settings/secrets/actions

Choose New repository secret and add these four secrets:

| Secret name | Value |
|---|---|
| ANDROID_KEYSTORE_BASE64 | Base64 encoding of the complete edunivora-upload.jks file |
| ANDROID_KEYSTORE_PASSWORD | Keystore password |
| ANDROID_KEY_ALIAS | edunivora-upload |
| ANDROID_KEY_PASSWORD | Password for the key alias |

To copy the Base64 value to the clipboard in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\edunivora-upload.jks))) | Set-Clipboard
```

Paste the clipboard value directly into the ANDROID_KEYSTORE_BASE64 secret. Do not paste any password or keystore contents into a chat, issue, source file, or commit.

## 3. Run the production workflow

Open: https://github.com/EduNivora/AcademicOS/actions/workflows/android-production-release.yml

After this workflow is available on the repository's default branch, choose Run workflow and select the release branch. Alternatively, merge the approved branch and push a version tag such as v1.0.0.

The workflow verifies the keystore and alias, runs Flutter analysis and tests, builds app-release.apk and app-release.aab, verifies both signatures, records SHA-256 checksums, uploads both files as a 30-day Actions artifact, and attaches both files to a GitHub Release when triggered by a v* tag.

## Google Play signing note

The generated keystore is the upload key. For Google Play distribution, enroll the app in Play App Signing and register this certificate as the upload certificate. Google Play then signs delivered APKs with the app-signing key managed by Play. Keep the upload keystore unchanged for future updates.