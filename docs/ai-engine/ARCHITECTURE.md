# EduNivora AI Engine — Architecture

## Current repository findings
- Flutter app with a lightweight Clean Architecture structure: core, domain, data, presentation, and Riverpod providers.
- Existing academic assistant screen: `lib/presentation/ai_assistant/academic_ai_screen.dart`.
- Existing `AcademicAssistantService` and `AcademicIntentEngine` produce deterministic local responses; they are not an external LLM integration.
- Existing authentication supports local credentials and Google Sign-In. Local credentials are stored and verified on-device; they cannot authenticate a backend securely.
- SQLite is local app storage. No existing server API or server-side identity/session service was found in the inspected project structure.
- No provider API key or production backend credentials were present in the repository.

## Target architecture added on this branch

```text
Flutter Presentation
  AcademicAiScreen (existing screen)
       |
       v
Domain: AIChatRepository + AIChatEvent
       |
       v
Data: AIGatewayDataSource + GoogleIdTokenProvider
       |  HTTPS + Google ID token
       v
backend/ai (Fastify)
  Authentication (Google token verification)
  Per-user rate limiting
  Conversation ownership checks
  Context window selection
  Prompt loading from editable Markdown
  AIProvider abstraction
       |
       v
OpenAI provider (server-only API key)
       |
       v
PostgreSQL (conversation/message persistence)
```

## Security decisions
- The provider key exists only in backend environment variables.
- Backend derives user identity from a verified Google ID token; it never trusts a user ID from request JSON.
- All conversation reads/writes include the verified user ID.
- Local-only username/password accounts are not accepted by the AI gateway until a server-verifiable identity provider is implemented.
- Rate limits are keyed by verified user ID after authentication.
- Request authorization headers are redacted from application logs.
- Academic records are not exposed to the model through arbitrary client-provided tool calls. No RAG or privileged academic tools are implemented.

## Extension points
- Implement another provider by satisfying `AIProvider` in `backend/ai/src/provider.ts`.
- Change model via `OPENAI_MODEL`.
- Edit `backend/ai/prompts/academic-system.md` without changing Dart/TypeScript code.
- Add authorized server-side tools behind the verified user context.
- Add conversation summarization/RAG as separate services; current context handling bounds the most recent turns only.

## Current limitations
- This branch does not deploy the backend or provision PostgreSQL, OAuth credentials, or the OpenAI secret.
- Flutter chat streaming is wired to the gateway, but persistent conversation-list restoration UI is not yet implemented.
- Server-side conversation persistence and per-user isolation are implemented in code but require a live PostgreSQL instance and integration tests.
- Context truncation is implemented; automatic semantic summarization is not yet implemented.
- Streaming token usage is not yet persisted; non-streaming endpoint records provider usage.
- No CI run or Flutter/Node test run has been performed from this GitHub editing session. The workflow added here will run when GitHub Actions is enabled for the branch.
