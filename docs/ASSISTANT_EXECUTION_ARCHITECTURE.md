# AcademicOS — Assistant Execution Architecture

## Purpose and boundary

The academic assistant is a planner and a constrained client-side executor. Gemini may propose an action plan, but it never receives database credentials, SQL access, or a direct database connection. Academic records remain in the application's local SQLite database and are mutated only through existing repositories/use cases and DatabaseHelper.

This is intentionally a local-first architecture. The current product does not store academic courses, tasks, schedules, exams, or attachments in Neon. Neon is used by the AI endpoint for authenticated request handling and quota counters only.

## Request and execution path

1. The student enters a prompt in AcademicAiScreen.
2. For a signed-in cloud session, the client sends the prompt and a bounded academic context to the authenticated Neon AI function. The context contains profile fields, course/task/schedule/exam data and attachment metadata; it does not contain attachment BLOB bytes or document text.
3. Gemini returns a proposed action plan as untrusted JSON. `AcademicAssistantActionPlanParser` rejects malformed JSON, malformed entries, unknown action names, and plans above ten actions as a whole. It is a plan, not an instruction with execution authority.
4. AcademicAssistantActionExecutor.execute checks the action name against the fixed action switch and checks every argument against the per-action field allowlist. Unknown fields—including user_id, userId, owner_id, SQL fragments, and arbitrary nested values—are rejected.
5. The executor resolves records against the local repositories. Ambiguous or missing records return a clarification/error result instead of selecting a random record.
6. Destructive operations and all record-update operations return a confirmation request. The UI requires explicit student confirmation before the second execution attempt.
7. The executor writes through existing use cases/database methods. The model never chooses a table, SQL statement, file path, database connection, or account identity.
8. For every mutation result, verifyPostcondition reads the affected record again from the authoritative local repository/database and compares the requested values, relationships, or attachment bytes.
9. The UI reports success only when the action result is successful and the postcondition passes. If verification fails, the UI reports that the result could not be confirmed, refreshes visible data, and stops the remaining steps in that plan.
10. The UI keeps the current conversation in memory for the active screen session. Durable conversation history and a durable multi-step execution ledger are not implemented in this branch.

## Supported action allowlist

The current executor supports only its explicit switch cases:

- Course/material metadata: create, update, and confirmed cascade delete.
- Course attachment: add a bounded local file BLOB to a resolved course.
- Student profile: update after confirmation.
- Tasks: create, complete, update after confirmation, and delete after confirmation.
- Weekly lectures: add, update after confirmation, and delete after confirmation.
- Exams: create, update after confirmation, and delete after confirmation.
- Academic reports: generate a local report from persisted records.

Any other action name is rejected. A malformed plan is rejected without a free-form model fallback for the same action request. A model response cannot add a new capability by naming a tool.

## Postcondition verification

AcademicAssistantToolResult carries succeeded, changedData, and affectedRecordId. verifyPostcondition performs a read-after-write check for every supported mutation class:

- Course create/update: re-read the course and compare requested fields.
- Course delete: confirm the course and dependent task/schedule/exam/attachment rows are absent.
- Attachment add: re-read the row and compare course ownership, filename, and exact BLOB bytes.
- Task create/complete/update/delete: re-read task state and verify title, relationships, completion, due date, and reminder fields as applicable.
- Lecture add/update/delete: re-read the schedule row and verify course link, day/time/location, reminder fields, or deletion.
- Exam create/update/delete: re-read the exam row and verify title/date/location/notes/course link or deletion.
- Profile update: reload the local profile and compare requested fields.

A successful database method call by itself is not proof of success.

## Retry and duplicate protection

The executor checks for equivalent existing data before creating a course, task, attachment, lecture, or exam. Attachment duplicate detection compares exact stored bytes for a matching course/name/type. This is a data-level duplicate guard, not a replacement for a durable execution ledger. A durable action receipt/ledger that survives process death and recovers interrupted multi-step plans remains a separate follow-up.

## Document interaction

The assistant does not receive attachment bytes or extracted document text. PDF summarization uses the separate local document pipeline (DocumentSummaryService and PdfTextExtractionService) and never routes document content to Gemini. The AI context includes only attachment metadata such as title and file type.

## Server responsibilities

The Neon AI function:
- validates the Neon Auth JWT signature, issuer, audience, expiry, and UUID subject;
- keeps the Gemini key on the server;
- applies database-backed per-account minute/day quotas before provider calls;
- does not execute academic mutations and does not store prompts, answers, academic context, IP addresses, or device identifiers in the quota table.

The current quota migration is included as source only. It has not been applied to production and the function has not been deployed from this branch.

## Known architectural boundary

Because academic data is local-first, there is no server-side academic row owner ID to check today. The server verifies the account making an AI request, but the local SQLite mutation path is not a cloud multi-tenant API. This branch must not be described as providing cross-device academic sync or server-enforced per-row tenant isolation. If cloud academic storage is introduced, all mutations must move behind authenticated server endpoints with row-level ownership checks before that feature is enabled.
