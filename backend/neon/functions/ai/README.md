# EduNivora AI Neon Function

Server-side Gemini boundary used by the Flutter academic assistant.

## Deployed endpoint

`https://br-late-bread-bajll3is-ai.compute.c-8.eu-central-1.aws.neon.tech`

- `GET /health` — deployment health; returns a non-secret `configured` boolean and was verified HTTP 200.
- `POST /v1/chat` — requires a valid Neon Auth JWT and a configured Gemini key.
- `POST /v1/schedule/parse` — accepts an authenticated base64 JPG/PNG/WebP timetable image (maximum 8 MiB) and returns validated weekly lecture rows.

Request JSON:

```json
{
  "message": "اشرح لي مفهوم قواعد البيانات العلائقية",
  "context": "بيانات أكاديمية اختيارية من التطبيق"
}
```

Send `Authorization: Bearer <Neon Auth JWT>`.
The provider request uses `store: false`; conversation history is not persisted by the provider.
The response contains `answer`, `model`, and usage metadata when available.

The schedule parser accepts `{ "image": "<base64>", "mimeType": "image/jpeg" }`. It sends the image and an extraction instruction to Gemini with `store: false`, validates the returned day names and 24-hour time ranges, and returns an `entries` array. The client must match every extracted subject name to an existing material ID and let the student review the proposed rows before saving.

## Runtime environment

- `DATABASE_URL` — injected by Neon for the function branch; used only for quota counters.
- `NEON_AUTH_BASE_URL` — injected by Neon Auth.
- `NEON_AUTH_JWKS_URL` — injected by Neon Auth.
- `GEMINI_API_KEY` — configured as a server-side Neon Function environment variable; never expose its value.
- `APP_ORIGINS` — comma-separated exact origins required by Flutter Web. Native Android requests do not rely on browser CORS.

Never place `GEMINI_API_KEY` in Flutter, GitHub source, SQL, or client-side build arguments.
The key is sent to Google only in the `x-goog-api-key` request header from the server.
The function validates Neon Auth JWT issuer, audience, expiration, not-before, and EdDSA signature before forwarding a request.

## Per-account AI quotas

The AI function reserves quota in PostgreSQL after authentication and request validation, before calling Gemini. Default limits are 5 requests per account per UTC minute and 50 requests per account per UTC day, shared by chat and timetable parsing. Reservation uses one database transaction and atomic `INSERT ... ON CONFLICT ... WHERE request_count < limit` updates; if either window is exhausted, the transaction rolls back and the provider is not called. The API returns HTTP 429 with `Retry-After`. If the quota database is unavailable, the API fails closed with HTTP 503. Only account ID, window kind, window start, and request count are stored; prompts, responses, academic context, IP addresses, and device identifiers are not stored.

Schema: `migrations/0003_ai_usage_windows.sql`. Apply it only after reviewing and testing the migration on a Neon child branch.

## Limits and error handling

- User message: 12,000 characters maximum.
- Optional academic context: 20,000 characters maximum.
- Request body: 40,000 bytes maximum.
- Provider output: 2,048 tokens maximum.
- Provider timeout: 35 seconds.
- Provider response bodies and internal diagnostics are never returned to clients.

## Remaining release gates

The Flutter client is wired to this endpoint and retains the local assistant for guest/local sessions.
Before production-wide activation, verify the durable per-account quota migration and configure Google AI usage limits,
set the production Flutter Web origin if web is shipped, and run end-to-end tests with a real Neon Auth session
and a privately configured Gemini API key. Do not treat a successful health check as proof that Gemini generation works.

## Set the Gemini secret and activate generation

The secret is deliberately not stored in this repository or in Flutter.
On the developer machine, from the repository root:

1. Install the CLI once with `npm install -g neon@latest`. Run `neon link` from the repository root if this checkout is not already linked, then select project `edunivora` (`morning-lab-61449214`) and branch `br-late-bread-bajll3is`.
2. On Windows PowerShell, run `./scripts/deploy-ai-secret.ps1`. It prompts for the key with hidden input, writes it temporarily to the ignored `.env.local`, and runs `npm run neon:deploy -- --env .env.local`.
3. The `ai` function declares the key as required, so deployment fails rather than silently publishing an unusable Gemini integration if the key is absent.
4. The script removes `.env.local` in its `finally` block. Neon retains the deployed function environment value; never commit or upload the local file.

This command applies the repository's Neon configuration and redeploys the functions declared in `neon.ts`; variables not declared there, such as the existing `APP_ORIGINS` on `notices`, are left unchanged by Neon.
