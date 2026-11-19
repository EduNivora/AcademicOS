# AI Engine Delivery Status

Updated: 2026-11-19

## Implemented on this branch
- [x] Created isolated branch `feat/edunivora-ai-engine` from `main`.
- [x] Audited existing Flutter structure, AI screen/service, local authentication, database, dependencies, and architecture notes.
- [x] Added backend AI provider abstraction and an OpenAI adapter.
- [x] Added Fastify API with JSON and Server-Sent Events chat endpoints.
- [x] Added Google ID-token verification; backend identity comes from verified token subject.
- [x] Added per-user rate limiting after authentication.
- [x] Added PostgreSQL conversation/message schema and owner-scoped reads/writes.
- [x] Added bounded recent-turn context management.
- [x] Added editable Arabic/English academic system prompt.
- [x] Added provider request timeout/retry configuration and token usage persistence for JSON and streaming responses.
- [x] Added Flutter domain/data/provider wiring and connected the existing assistant screen to streaming API events.
- [x] Removed the previous fake "connected" status; the screen now indicates that requests are sent only when the student submits a message.
- [x] Added Markdown response rendering.
- [x] Added backend unit tests for context selection and a GitHub Actions validation workflow.
- [x] Added setup and architecture documentation.

## Not yet verified / blocked by environment credentials
- [ ] Install dependencies and run backend TypeScript typecheck/tests in a real Node 22 environment.
- [ ] Run `flutter pub get`, `flutter analyze`, and `flutter test` in a Flutter 3.32+ environment.
- [ ] Configure a live PostgreSQL database and apply the migration.
- [ ] Configure Google Web OAuth client ID and verify the Android/iOS ID-token flow.
- [ ] Supply `OPENAI_API_KEY` through backend secret storage and make a real provider request.
- [ ] Deploy the backend over HTTPS and configure Flutter `--dart-define` values.
- [ ] Complete integration tests for invalid/expired tokens, provider failures, timeout, large response, concurrent users, and cross-user conversation isolation.
- [ ] Add conversation history list/restore UI.
- [ ] Add automatic conversation summarization; current implementation bounds context to the latest configured messages.
- [ ] Add math-specific Markdown rendering if LaTeX output is a required part of the UX.

## Important
This is a real integration implementation, not a deployed service yet. Do not tell users that AI is live until the backend is deployed, secrets and OAuth are configured, database migration is applied, and an authenticated end-to-end request succeeds. No OpenAI secret has been added to this repository or to Flutter.
