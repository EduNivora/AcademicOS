# Android production release signing

Release 1 keeps two distinct Android outputs:

- **QA APK:** the existing release variant signed with the Android debug key. It is suitable for internal QA only and must not be uploaded to Google Play.
- **Production APK:** signed with the project-owned upload/release keystore. The Flutter quality workflow builds this artifact only when all required GitHub Actions secrets are configured.

## Required signing material

Create and retain the keystore in an owner-controlled secure location. Do not commit it to Git, attach it to an issue, or send it through chat.

Example keystore generation command (run locally in a trusted environment):

```bash
keytool -genkeypair -v \
  -keystore edunivora-upload-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias edunivora-upload
```

Back up the keystore and its passwords separately. Losing the upload key can complicate future app updates; do not regenerate it casually.

## GitHub Actions secrets

Configure all four secrets in the repository or its approved organization environment:

| Secret | Value |
|---|---|
| `EDUNIVORA_ANDROID_KEYSTORE_BASE64` | Base64 encoding of the complete `.jks` file |
| `EDUNIVORA_ANDROID_STORE_PASSWORD` | Keystore password |
| `EDUNIVORA_ANDROID_KEY_ALIAS` | Alias created in the keystore |
| `EDUNIVORA_ANDROID_KEY_PASSWORD` | Private-key password |

For a Linux/macOS terminal, create the Base64 value without line breaks:

```bash
base64 < edunivora-upload-key.jks | tr -d '\\n'
```

The workflow decodes the keystore into the ephemeral runner's temporary directory, passes the four values to Gradle as environment variables, and uploads a separate production-signed APK artifact. The secret values are not written to the repository or printed in workflow logs.

Gradle accepts these environment variables:

- `EDUNIVORA_ANDROID_KEYSTORE_PATH`
- `EDUNIVORA_ANDROID_STORE_PASSWORD`
- `EDUNIVORA_ANDROID_KEY_ALIAS`
- `EDUNIVORA_ANDROID_KEY_PASSWORD`

If only some signing values are present, Gradle fails rather than silently falling back to a debug key. When no production signing secrets are configured, the workflow produces only the explicitly labelled QA APKs.

## Release controls

1. Restrict access to the keystore and signing secrets to release maintainers.
2. Keep the application ID stable: `com.arfatalkamli.academicos`.
3. Increment `versionCode` for every Play Store upload.
4. Verify the APK signer before distribution.
5. Test the signed APK on physical Android devices before release.
6. Do not treat a successful CI build as device acceptance or Play Store approval.
