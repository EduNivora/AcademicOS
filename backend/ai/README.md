# EduNivora AI Gateway

A standalone Node.js 22+ backend for real model requests. Flutter never receives the provider API key.

## Security model
- Every request requires a Google ID token in `Authorization: Bearer <id-token>`.
- The server verifies token signature, expiry, issuer, email verification, and the configured OAuth audience with Google's verification library.
- User identity comes only from the verified token's `sub`; client-supplied user IDs are ignored.
- Conversations and messages are scoped by verified user ID in every SQL query.
- PostgreSQL is required for durable conversation history. Apply `migrations/001_ai_chat.sql`.
- Rate limiting is applied by authenticated user ID; secrets and authorization headers are redacted from logs.
- The current local username/password auth in the Flutter app is not a server-verifiable identity. It is deliberately not accepted by this gateway. Add a real server-side identity provider before enabling AI for local-only accounts.

## Setup
1. Install Node.js 22+ and PostgreSQL.
2. Copy `.env.example` to `.env`; set `DATABASE_URL`, `GOOGLE_OAUTH_CLIENT_ID`, and `OPENAI_API_KEY`.
3. Ensure the Flutter Google Sign-In flow requests an ID token for the same Web OAuth client ID.
4. Apply the migration: `psql "$DATABASE_URL" -f migrations/001_ai_chat.sql`.
5. Run `npm install`, `npm run typecheck`, then `npm run dev`.

## Endpoints
- `GET /health`: liveness only (no provider secret or database details).
- `POST /v1/chat`: authenticated JSON request, body `{ "message": "...", "conversationId": "optional UUID" }`.
- `POST /v1/chat/stream`: same request, Server-Sent Events with `delta`, `done`, or `error` events.
- `GET /v1/conversations`: authenticated user's conversation list.
- `GET /v1/conversations/:id/messages`: messages for a conversation owned by the authenticated user.

## Configuration
See `.env.example`. The system prompt is editable at `prompts/academic-system.md` or via `SYSTEM_PROMPT_FILE`. Select the model with `OPENAI_MODEL`.

## Important current boundary
The Flutter screen has not yet been switched to this gateway. The backend scaffold is not a claim of a working deployed AI service. It becomes operational only after secrets, PostgreSQL, Google OAuth audience configuration, and deployment are supplied and verified. The UI must not display a connected status until a real health/authenticated request succeeds.