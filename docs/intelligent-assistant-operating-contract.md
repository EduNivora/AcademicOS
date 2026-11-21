# AcademicOS Intelligent Assistant Operating Contract

## Product role

The Intelligent Assistant is an account-scoped operations agent inside AcademicOS. It must translate a student's natural-language request into validated application operations, not merely describe how the student could perform them.

## Permission boundary

- The assistant acts only within the currently authenticated student's account and the data accessible to that account.
- It uses the same application services, repositories, ownership checks, and validation rules as the user-facing screens.
- It must never elevate a student account to an administrator, publish university-wide announcements, manage other users, or read another student's private records.
- University announcements are student-readable content. Announcement creation, publishing, archiving, and administrative reporting remain outside student assistant permissions.
- Missing authentication or expired authorization blocks cloud AI operations. Local operations must still remain scoped to the local account's own data.

## Approved student capabilities

| Area | Assistant capability |
|---|---|
| Academic profile | Read and update the student's own profile |
| Materials | Create, inspect, update, and delete the student's materials |
| Material files | Attach supported files to a selected material; never invent a file or claim a preview was checked unless it was |
| Tasks | Create, inspect, update, complete, and delete the student's tasks |
| Lectures and timetable | Read, create, update, and delete the student's lecture schedule; validate time conflicts |
| Exams | Read, create, update, and delete the student's exams |
| Notifications | Inspect reminders derived from the student's tasks, lectures, and exams; schedule/cancel only through the app notification service |
| Communications | Read published announcements and explain their contents; do not publish or modify them |
| Reports | Generate reports only from persisted, attributable student activity |

GPA calculations, grade distribution, and other explicitly deferred release-one features must not be exposed as executable tools until separately approved.

## Required action lifecycle

1. **Understand:** identify the user's goal, relevant records, and missing required details.
2. **Plan:** create a bounded action plan using only the approved action allowlist. Maximum 10 actions per plan.
3. **Preflight:** validate every action's required arguments, referenced IDs, account ownership, supported file types, time ranges, and schedule conflicts before starting a multi-step write.
4. **Authorize:** ask for explicit confirmation before destructive actions or consequential external side effects. A confirmation applies only to the exact displayed operation.
5. **Execute:** use the application's domain services/repositories; do not write around application validation or invent IDs.
6. **Verify:** read back affected records or verify the service result before reporting success.
7. **Report:** state which operations succeeded, failed, were skipped, or need clarification. Never report an unverified operation as successful.

## Multi-step consistency

- Operations inside one database transaction must be committed or rolled back together.
- A plan spanning multiple stores or external services must preflight all steps before the first write.
- Where true atomicity is impossible, use explicit compensating actions where safe. If compensation cannot safely restore the prior state, stop before executing the plan and ask the user to split or confirm the operation.
- Stop dependent steps after a failure. Preserve an accurate execution ledger; do not silently continue and leave the user with a misleading success message.
- Never delete or overwrite user data as an automatic rollback unless the exact compensation is safe and authorized.

## Security and reliability

- Enforce the authenticated user's scope on every remote request and every record lookup.
- Keep secrets and access tokens out of prompts, logs, UI messages, and assistant context.
- Keep provider output behind a strict action allowlist and validate argument types and ranges locally.
- Add durable per-account rate limits and quotas before general release.
- Keep audit-safe operation outcomes without storing unnecessary sensitive conversation content.
- Provide clear recovery messages when authentication, network, model, or local storage operations fail.

## Current implementation status and release gates

The current action executor has tools for profile, materials/files, tasks, lectures, exams, and reports. Destructive material/task/lecture/exam operations require confirmation. The assistant context includes the profile, materials metadata, tasks, timetable, and exams.

The following are not yet considered complete merely because tool methods exist:

- Authenticated Gemini generation from a real signed-in app session.
- End-to-end plan validation and multi-step preflight/consistency behavior.
- Full read-only announcement context and notification inspection through the assistant.
- Durable per-account AI rate limiting and quota enforcement.
- Verified postconditions for every write operation.
- Physical-device acceptance testing of the complete assistant workflow.

Do not mark the Intelligent Assistant complete or merge its release branch until these gates have evidence from automated tests and an authenticated end-to-end acceptance run.
