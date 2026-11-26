# EduNivora Neon backend

This folder contains the Release 1 cloud boundary for accounts and public notices.
It must never be used to store courses, terms, schedules, tasks, exams, grades,
notes, academic materials, attachment bytes, or academic reports.

## Services

- Neon Managed Auth (Better Auth) owns sign-up, sign-in, password verification,
  email verification, OAuth identities, and sessions in the managed `neon_auth`
  schema.
- The app-owned `public.app_users` table is a minimal profile/role projection
  linked to `neon_auth."user"(id)`; it is not a second password store.
- PostgreSQL stores announcements, registered delivery/read receipts, anonymous
  daily guest counters, a narrow admin audit trail, and AI quota counters only.
- A Neon Function exposes the HTTP API next to the database. The function reads
  `DATABASE_URL`, `NEON_AUTH_BASE_URL`, and `NEON_AUTH_JWKS_URL` injected by
  Neon. Set `APP_ORIGINS` only after the actual Web app origin is known.

## Database migrations

Apply in numeric order after provisioning Neon Auth:

1. `migrations/0001_initial.sql`
2. `migrations/0002_neon_auth_and_delivery.sql`
3. `migrations/0003_ai_usage_windows.sql` — AI per-account minute/day quota counters.

The migrations are idempotent for their intended schema changes. They must be
tested on a Neon child branch before being applied to any database that contains
real users or notices.

The current Neon project has had all three schema steps applied and verified.
Migration 0003 was tested on a child branch and applied to production main on
2026-11-27. Its `public.ai_usage_windows` table and three indexes were verified;
the table had zero rows at verification time. This is only the database
prerequisite: the AI Function still requires its quota-aware bundle deployment.

No application user records or announcements existed when the Auth foreign key
was introduced.

## API

- `GET /health`
- `GET /v1/me` — authenticated app profile and server-owned role projection used to gate the admin console.
- `GET /v1/announcements?limit=20&before=<ISO timestamp>` — public, guest-safe feed.
- `POST /v1/announcements/:id/guest-view` — increments an aggregate daily view counter.
- `POST /v1/announcements/:id/guest-delivered` — increments an aggregate daily delivery counter.
- `POST /v1/announcements/:id/delivered` — authenticated registered delivery acknowledgement.
- `POST /v1/announcements/:id/read` — authenticated registered read receipt.
- `POST /v1/admin/announcements` — admin-only draft creation.
- `PATCH /v1/admin/announcements/:id` — admin-only draft editing.
- `POST /v1/admin/announcements/:id/publish` — admin-only publication.
- `POST /v1/admin/announcements/:id/archive` — admin-only archive.
- `GET /v1/admin/announcements?status=draft|published|archived` — admin-only notice list.
- `GET /v1/admin/announcements/:id/report` — admin-only report.

All registered-user endpoints require a Neon Auth JWT in the Authorization
Bearer header. The API verifies its EdDSA signature against the branch JWKS,
checks both issuer and audience against the origin of `NEON_AUTH_BASE_URL`
(the scheme and host only, not the `/edunivora/auth` path), and resolves the
subject against the managed Auth user table. A regression test locks this
Neon-specific JWT contract.
Admin authorization is enforced from `app_users.role` on every request; it is
never trusted from a client-supplied field. `GET /v1/me` exposes this role to the
client without granting any additional authority.

Guest metrics contain counters only. They do not store guest IDs, IP addresses,
device fingerprints, or stable guest identifiers. Guest counters are event
counts, not unique visitor counts, and must be interpreted accordingly.

Abuse protection for these unauthenticated counter endpoints is not yet
implemented. Treat guest aggregates as provisional, not authoritative analytics,
until the privacy-preserving controls tracked in GitHub issue #24 are completed
and tested. Public notice reading remains available independently of metrics.

## Authentication setup status

Neon Managed Auth is enabled for the EduNivora main branch. Email/password is
enabled with mandatory email verification by OTP.

**Production authentication is not ready.** The verified Neon Auth configuration
on 2026-11-27 reports only `http://localhost:43821` in trusted origins and
`allow_localhost=false`; no production Web origin is registered. The email
provider is still Neon's shared development sender (`auth@mail.myneon.app`),
and Google OAuth uses a shared development provider/client rather than a
verified project-owned production OAuth configuration. Do not expose public
Web sign-up or claim production Google/email authentication until the exact
production origin, project-owned OAuth credentials, production SMTP sender,
redirect URIs, and real-account end-to-end flows are configured and verified.

The Flutter client contains a Neon Managed Auth REST adapter for email
sign-up/sign-in, email-verification OTP, session restoration, sign-out, and JWT
retrieval. Native session cookies are persisted through Flutter Secure Storage;
Web requests use browser-managed credential cookies. The login and registration
screens use email/password and OTP verification, while guest access remains
available without a network connection. This implementation has unit coverage,
but real-account end-to-end flows on Android and Web are not yet accepted.
Production Web authentication remains blocked until the actual deployed origin
is added to Neon trusted origins and credentialed CORS is verified.

## First administrator bootstrap

Do not expose an admin-registration button or accept a role from the client.
Create the first account through the normal Flutter email/OTP flow, verify its
email, then run `operations/bootstrap_first_admin.sql` once in the Neon SQL
Editor after replacing its email placeholder with that verified address. The
script refuses to run if an administrator already exists or if the verified
account cannot be found. Keep this operation restricted to the project owner.

## Deployment

The Notices API is deployed to the Neon project's default branch.

- Function slug: `notices`
- Runtime: Node.js 24
- Active deployment reported by Neon on 2026-11-27: deployment ID 8, created 2026-11-20.
- Invocation URL: `https://br-late-bread-bajll3is-notices.compute.c-8.eu-central-1.aws.neon.tech`
- The active deployment metadata does not identify the source commit or prove that the latest source is deployed.
- A prior smoke check against deployment 7 returned 404 for `GET /v1/me`, while `/health` and the public feed returned 200 and the unauthenticated admin route returned 401. No fresh `/v1/me` smoke test against deployment 8 has been recorded here. Do not consider the admin console operational until the active bundle is matched to an accepted source SHA and verified with a real Neon JWT.

The Notices bundle workflow builds the Node.js 24 entrypoint, packages its runtime
dependencies, and uploads the ZIP plus bundled entrypoint as a GitHub Actions
artifact for 14 days. It does not commit generated files or push bot commits to
the source branch. The `neon.ts` config points to the maintained source entry
file and declares `pg` and `@neon/functions` as runtime external packages.

The smoke tests do not prove JWT acceptance, registered receipts, admin
publishing, Flutter integration, CORS for the final Web origin, or production
readiness. Those remain explicit acceptance gates.

Never commit `.env`, `.env.local`, `DATABASE_URL`, OAuth secrets, or Auth
tokens. Never place database credentials in the Flutter client.

## Flutter announcements and receipts

The Flutter client loads the public feed from `GET /v1/announcements` and
caches it locally for offline reading. Registered users obtain a short-lived
Neon Auth JWT from the Neon `get-session` response (the session token field or
the `set-auth-jwt` response header); the client sends it as a Bearer token to the
registered delivery and read-receipt endpoints. Guest installations use only
anonymous aggregate delivery/view counters. If token retrieval fails, the
client skips metrics rather than misclassifying a signed-in account as a guest.

Guest delivery acknowledgement is deduplicated across app restarts using a
bounded local list of up to 500 notice IDs. That list is never uploaded and
contains no guest identity. Clearing app/browser storage can cause a later
acknowledgement to be counted again. Flutter unit tests cover the transport and
routing decisions; exact-head Flutter CI and live JWT-backed database receipts
remain acceptance gates.
