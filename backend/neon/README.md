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
  daily guest counters, and a narrow admin audit trail.
- A Neon Function exposes the HTTP API next to the database. The function reads
  `DATABASE_URL`, `NEON_AUTH_BASE_URL`, and `NEON_AUTH_JWKS_URL` injected by
  Neon. Set `APP_ORIGINS` only after the actual Web app origin is known.

## Database migrations

Apply in numeric order after provisioning Neon Auth:

1. `migrations/0001_initial.sql`
2. `migrations/0002_neon_auth_and_delivery.sql`

The migrations are idempotent for the existing empty EduNivora project. They
must be tested on a Neon child branch before being applied to any database that
contains real users or notices.

The current Neon project has already had both schema steps applied and verified.
No application user records or announcements existed when the Auth foreign key
was introduced.

## API

- `GET /health`
- `GET /v1/me` — authenticated app profile and server-owned role projection used to gate the admin console.
- `GET /v1/announcements?limit=20&before=<ISO timestamp>` — public, guest-safe feed.
- `GET /v1/announcements/:id` — public details for one published announcement.
- `POST /v1/announcements/:id/guest-view` — Worker-authorized aggregate daily view counter.
- `POST /v1/announcements/:id/guest-delivered` — Worker-authorized aggregate daily delivery counter.
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

Guest metric writes are accepted by the source API only with the server-to-server
`X-EduNivora-Worker-Secret` assertion. The planned Cloudflare Worker uses one
SQLite-backed Durable Object per announcement and UTC day, enforcing separate
global budgets for views and delivery acknowledgements (5,000 each by default).
It stores only aggregate budget counters. The Worker forwards only the metric
route and server-side assertion; it does not forward cookies, IP metadata,
user-agent, device identifiers, or request bodies. A failed upstream request
does not refund reserved quota, because Neon may have committed before a network
failure was observed.

The Worker implementation and Node tests are in
`guest-metrics-worker/` and
`functions/notices/guest_metrics_worker.test.mjs`. These tests exercise the
quota algorithm and mocked Worker routing; they are not a substitute for a
Cloudflare runtime deployment/concurrency test. Guest metrics are best-effort.
Public notice reads remain independent and must continue if the proxy is down.
Guest metrics are disabled in the Flutter client unless
`EDUNIVORA_GUEST_METRICS_PROXY_URL` is supplied at build time.

## Authentication setup status

Neon Managed Auth is enabled for the EduNivora branch. Email/password is enabled
with mandatory email verification by OTP. The initial shared Neon SMTP sender
is suitable for development only; configure a production SMTP sender before
public release. Neon currently reports a shared Google OAuth provider for
development. Production Google sign-in requires the project's own Google OAuth
client ID and secret, plus verified redirect/trusted-origin configuration.

The Flutter client now contains a Neon Managed Auth REST adapter for email
sign-up/sign-in, email-verification OTP, session restoration, sign-out, and JWT
retrieval. Native session cookies are persisted through Flutter Secure Storage;
Web requests use browser-managed credential cookies. The login and registration
screens use email/password and OTP verification, while guest access remains
available without a network connection. This implementation has unit coverage,
but real-account end-to-end flows on Android and Web are not yet accepted.
Production Web authentication is blocked until the actual deployed origin is
added to Neon trusted origins and credentialed CORS is verified.

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
- Last confirmed live deployment: deployment ID 7 (Node.js 24)
- Invocation URL: `https://br-late-bread-bajll3is-notices.compute.c-8.eu-central-1.aws.neon.tech`
- Health check: `GET /health` returned HTTP 200 and confirmed a database query.
- Public feed: `GET /v1/announcements` returned HTTP 200 with an empty feed.
- Admin guard: unauthenticated `GET /v1/admin/announcements` returned HTTP 401.
- The current source branch adds authenticated `GET /v1/me`, receipt/profile improvements, and the corrected JWT issuer/audience validation. The latest source bundle is built and stored as a GitHub Actions artifact, but these newer source changes have **not yet been deployed** to the live Function. The active deployment remains version 7; the recorded smoke check returned 404 for `GET /v1/me`, while `/health` and the public feed returned 200 and the unauthenticated admin route returned 401. Do not consider the admin console operational until a verified deployment exposes `/v1/me` and accepts a real Neon JWT.

The bundle workflow builds the Node.js 24 entrypoint, packages its runtime
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


## Guest metrics Worker deployment — operator action required

The guest-metrics Worker is intentionally not deployed by this source change.
Before deployment:

1. Review `guest-metrics-worker/wrangler.jsonc`, the Durable Object class
   migration, quotas, source code, tests, and rollback instructions.
2. Generate one random secret of at least 32 bytes in an approved password
   manager/secret manager. Do not paste it into GitHub, chat, source files,
   logs, or commits.
3. Install that same secret as the Worker secret
   `NEON_GUEST_METRICS_SECRET` and as the Neon Function environment variable
   `GUEST_METRICS_PROXY_SECRET`. Do not set either production value until
   the Worker deployment, quota tests, and rollback path are approved.
4. Configure the actual Pages origin `https://edunivora.pages.dev` in
   `EDUNIVORA_APP_ORIGINS`; verify the account's Workers subdomain or choose
   an approved custom hostname.
5. Deploy and smoke-test the Worker first. Then deploy the Neon Function with
   the matching secret. Direct public guest-metric POSTs must return 403;
   when the Neon secret is absent, the endpoint returns 503. Public GET feed
   must remain 200 in either case.
6. Build Flutter with
   `--dart-define=EDUNIVORA_GUEST_METRICS_PROXY_URL=<verified-worker-url>`
   only after the Worker and Neon Function have both passed live tests.

Rollback must never restore unauthenticated direct writes. On a proxy incident,
omit the Flutter proxy URL (guest metrics stop while public feed and local
academic features remain available), or roll back to another reviewed Worker
build that preserves the quota and server-secret checks. Do not redeploy the
pre-fix Neon Function version 7 as a rollback target.
