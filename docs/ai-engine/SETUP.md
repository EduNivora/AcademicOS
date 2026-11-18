# EduNivora AI Gateway Setup

## Backend requirements
- Node.js 22+
- PostgreSQL 14+
- Google OAuth Web Client ID used as the audience for Google ID tokens
- OpenAI API key (server secret)

## Backend setup
```bash
cd backend/ai
cp .env.example .env
npm install
psql "$DATABASE_URL" -f migrations/001_ai_chat.sql
npm run typecheck
npm test
npm run dev
```

Set these values in `backend/ai/.env`:
- `DATABASE_URL`: PostgreSQL connection string.
- `GOOGLE_OAUTH_CLIENT_ID`: exact Google Web OAuth client ID expected in the ID token audience.
- `OPENAI_API_KEY`: provider secret. Never put this in Flutter or GitHub.
- `OPENAI_MODEL`: model identifier; defaults to `gpt-4.1-mini`.
- `ALLOWED_ORIGINS`: comma-separated browser origins where applicable.

The SQL migration is intentionally explicit; do not expose the gateway before applying it and configuring TLS at the hosting layer.

## Flutter build configuration
Supply the deployed HTTPS base URL and the same Google Web OAuth Client ID as Dart compile-time values:

```bash
flutter run \
  --dart-define=EDUNIVORA_AI_BASE_URL=https://YOUR-AI-HOST \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID
```

For release builds, pass the same values through the secure build pipeline. These values are not provider secrets. The OpenAI key remains on the backend only.

## Authentication compatibility
Google ID token authentication is currently supported. Local username/password sessions are device-local and cannot be verified by the backend. Do not weaken authentication to accept a username or user ID sent by the client. To support local accounts, first introduce a proper server-side identity provider and issue signed short-lived access tokens.

## Deployment checklist
1. Provision managed PostgreSQL and enable TLS.
2. Store `OPENAI_API_KEY`, `DATABASE_URL`, and `GOOGLE_OAUTH_CLIENT_ID` in the hosting platform's secret manager.
3. Apply the SQL migration.
4. Deploy the Node service behind HTTPS.
5. Configure Google OAuth Android/iOS/Web clients and verify ID-token audience matches `GOOGLE_OAUTH_CLIENT_ID`.
6. Build Flutter with the HTTPS base URL and Web client ID.
7. Test an authenticated chat request, a rejected invalid token, conversation ownership isolation, timeout, and rate limiting.
8. Confirm APK/IPA artifacts do not contain the OpenAI key.
