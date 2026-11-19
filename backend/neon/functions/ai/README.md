# EduNivora AI Neon Function

Server-side Gemini boundary used by the Flutter academic assistant.

## Deployed endpoint

`https://br-late-bread-bajll3is-ai.compute.c-8.eu-central-1.aws.neon.tech`

- `GET /health` — deployment health; returns a non-secret `configured` boolean and was verified HTTP 200.
- `POST /v1/chat` — requires a valid Neon Auth JWT and a configured Gemini key.

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

## Runtime environment

- `NEON_AUTH_BASE_URL` — injected by Neon Auth.
- `NEON_AUTH_JWKS_URL` — injected by Neon Auth.
- `GEMINI_API_KEY` — **not configured yet**. Add it only as a server-side Neon Function environment variable.
- `APP_ORIGINS` — comma-separated exact origins required by Flutter Web. Native Android requests do not rely on browser CORS.

Never place `GEMINI_API_KEY` in Flutter, GitHub source, SQL, or client-side build arguments.
The key is sent to Google only in the `x-goog-api-key` request header from the server.
The function validates Neon Auth JWT issuer, audience, expiration, not-before, and EdDSA signature before forwarding a request.

## Limits and error handling

- User message: 12,000 characters maximum.
- Optional academic context: 20,000 characters maximum.
- Request body: 40,000 bytes maximum.
- Provider output: 2,048 tokens maximum.
- Provider timeout: 35 seconds.
- Provider response bodies and internal diagnostics are never returned to clients.

## Remaining release gates

The Flutter client is wired to this endpoint and retains the local assistant for guest/local sessions.
Before production-wide activation, add a durable per-account quota/rate limiter, configure Google AI usage limits,
set the production Flutter Web origin if web is shipped, and run end-to-end tests with a real Neon Auth session
and a privately configured Gemini API key. Do not treat a successful health check as proof that Gemini generation works.

## Set the Gemini secret and activate generation

The secret is deliberately not stored in this repository or in Flutter.
On the developer machine, from the repository root:

1. Link the local Neon CLI context to project `morning-lab-61449214` and branch `br-late-bread-bajll3is` using `neon link` if this checkout is not already linked.
2. Create a local `.env.local` containing exactly `GEMINI_API_KEY=your-key`. The repository ignores `.env.local` and all `.env.*` files.
3. Run `npm run neon:deploy -- --env .env.local`. The `ai` function declares this value as required, so deployment fails rather than silently publishing an unusable Gemini integration if the key is absent.
4. Delete `.env.local` after deployment. Neon retains the deployed function environment value; the local copy is no longer needed.

This command applies the repository's Neon configuration and redeploys the functions declared in `neon.ts`; variables not declared there, such as the existing `APP_ORIGINS` on `notices`, are left unchanged by Neon.
