# AcademicOS — Assistant Security Model

## Trust boundaries

| Component | Trust level | Permitted responsibility |
|---|---|---|
| Student prompt and attached file metadata | Untrusted input | Request intent and data only |
| Gemini response/action plan | Untrusted model output | Propose an allowlisted action and bounded arguments |
| AcademicAssistantActionExecutor | Trusted application code | Validate, confirm, execute local use cases, and verify persisted state |
| SQLite repositories / DatabaseHelper | Local source of truth | Persist the current installation's academic records |
| Neon AI function | Trusted server boundary | Verify Neon Auth JWT, reserve quotas, call Gemini using a server-side secret |
| Gemini provider | External processor | Return a response/plan; never access local SQLite |

## Identity and ownership

- Cloud AI requests require a valid Neon Auth JWT. The server verifies signature, issuer, audience, expiration, not-before, and a UUID account subject.
- The server-side quota row is keyed by the verified JWT subject. The client cannot choose the quota account ID.
- Academic records are stored locally, not in a Neon academic database. No academic write is executed on the server. Consequently, there is no server-side user_id column or RLS policy for academic rows in this release.
- The local executor never accepts identity/owner fields from model arguments. They are rejected by the strict per-action argument allowlist.
- This is not multi-user-per-device isolation or cross-device synchronization. Those capabilities require a separate authenticated local-profile/data-partition design or server-side tenant model before being claimed.
- The assistant has no administrator action set and cannot create university-wide records or change system roles.

## Model and prompt-injection controls

- Model output is parsed as untrusted JSON.
- Action names are fixed in the executor switch and the dedicated `AcademicAssistantActionPlanParser`; malformed JSON, malformed action entries, unknown names, and plans above ten actions are rejected as a whole before execution.
- Each action has an explicit allowed argument-key set. Unexpected keys, identity fields, arbitrary maps, SQL text, and unsupported values are rejected.
- Numeric, boolean, date, string-length, and attachment-size inputs are validated before execution.
- A malformed or unrecognized model plan does not fall back to a free-form Gemini answer for an action request, preventing a model-only success claim when no tool ran.
- No model-controlled SQL, filesystem path, URL, database table, or service endpoint is executed.
- Attachment contents and extracted PDF text are not sent to Gemini. Only bounded academic metadata is included in the AI context. The system instruction also frames context as data, not authority.
- Even if a malicious filename or model output contains instructions, it cannot expand the action allowlist or bypass postcondition checks.

## Confirmation and mutation safety

- Course cascade deletion, task deletion, lecture deletion, and exam deletion require explicit confirmation.
- Updates to the academic profile, course records, tasks, lectures, and exams also require explicit confirmation.
- The UI does not report a successful mutation until the executor returns a successful result and the persisted postcondition passes.
- If postcondition verification fails, the remaining steps in a multi-action plan are stopped and the UI explicitly says the write could not be confirmed.
- Duplicate checks prevent repeat creation of equivalent courses, tasks, attachments, lectures, and exams. A local SQLite execution ledger persists run/step history across restarts, but it does not automatically resume interrupted plans; crash-safe recovery remains a follow-up.

## Data handling and logging

- The AI context may contain profile fields and academic records (course/task/schedule/exam data and attachment metadata). The UI discloses that the academic summary is sent to Gemini when cloud AI is used.
- Attachment BLOB bytes and PDF extracted text remain local and are not sent to the AI provider by the document-summary feature.
- The provider request uses store=false.
- The quota table stores only account UUID, window kind, window start, and request count.
- The server logs provider status and error names only; it does not log prompts, responses, academic context, IP addresses, device identifiers, or API key values.
- GEMINI_API_KEY is read only from Neon Function runtime configuration and is not added to Flutter, source code, or build arguments.

## Rate limiting

The AI function reserves quota atomically in PostgreSQL after authentication and request validation, before calling Gemini:
- 5 requests per account per UTC minute by default.
- 50 requests per account per UTC day by default.
- Both chat and timetable parsing consume the same per-account quota.
- Quota exhaustion returns HTTP 429 with Retry-After.
- Quota database failure returns HTTP 503 (fail closed).

Migration 0003_ai_usage_windows.sql is included in this PR but has not been applied to production. Deployment requires owner approval, migration review, and authenticated acceptance.

## Explicit limitations

- No server-side academic mutation API exists because academic records are local SQLite data.
- No durable assistant conversation history is included. The local SQLite action ledger persists run/step history, but automatic crash recovery/resumption and exactly-once execution are not implemented.
- Real-account Gemini acceptance, production quota migration, and production function deployment are not performed by this PR.
