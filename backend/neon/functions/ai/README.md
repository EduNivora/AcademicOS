# EduNivora AI Neon Function

This function is the server-side Gemini boundary for the Flutter academic assistant.

## Endpoint

- `GET /health` — deployment health only; does not call Gemini.
- `POST /v1/chat` — authenticated Gemini Interactions API generation.

Request JSON:

```json
{
  "message": "اشرح لي مفهوم قواعد البيانات العلائقية",
  "context": "بيانات أكاديمية اختيارية من التطبيق"
}
```

The request must include `Authorization: Bearer <Neon Auth JWT>`.
The request uses `store: false` so provider-side interaction history is not persisted. The response contains `answer`, `model`, and provider usage metadata when available.

## Required runtime environment

- `NEON_AUTH_BASE_URL` — injected by Neon Auth for this branch.
- `NEON_AUTH_JWKS_URL` — injected by Neon Auth for this branch.
- `GEMINI_API_KEY` — add as a server-side Neon Function environment variable.
- `APP_ORIGINS` — comma-separated, exact application origins.

Never place `GEMINI_API_KEY` in Flutter, GitHub source, SQL, or client-side build arguments.
The API key is sent to Google only in the `x-goog-api-key` request header from the server.
The function validates Neon Auth JWT issuer, audience, and EdDSA signature before forwarding a request.

## Limits and error handling

- User message: 12,000 characters maximum.
- Optional academic context: 20,000 characters maximum.
- Provider output: 2,048 tokens maximum.
- Provider timeout: 35 seconds.
- Provider response bodies and internal diagnostics are never returned to clients.

This is the first AI integration slice. Flutter client wiring, per-account quotas,
abuse controls, conversation persistence, and end-to-end acceptance tests are separate
release gates and must not be assumed complete from this function alone.
