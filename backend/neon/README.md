# EduNivora backend — Release 1

This backend supports only optional account identity, public notices, registered delivery/read acknowledgements, anonymous aggregate guest metrics, and minimal notice-operator audit records. It MUST NOT persist courses, terms, schedules, tasks, exams, grades, notes, study plans, academic reports, course materials, or attachment bytes. Academic records remain on the Android device; no academic cloud synchronization exists.

## Components

- Neon Managed Auth owns password verification, OTP/email verification, OAuth identities, and sessions in the managed `neon_auth` schema.
- `public.app_users` is a minimal profile/role projection linked to the managed auth user UUID. It contains no passwords or session tokens.
- PostgreSQL stores published/draft notices, registered receipts, aggregate guest daily counters, and a narrow audit trail.
- The Hono/Node.js 24 Neon Function validates JWT signatures against the configured JWKS and validates issuer and audience. Privileged operations read the server-owned `app_users.role`; client role fields are ignored.
- The Cloudflare Worker accepts only the two guest-metric POST routes. One SQLite-backed Durable Object enforces per-notice/per-UTC-day view and delivery ceilings atomically. Durable state contains only metric-kind counters.

## Migrations

Apply `migrations/0001_initial.sql` and then `migrations/0002_neon_auth_and_delivery.sql` only after Neon Managed Auth has provisioned `neon_auth`. Validate on a disposable Neon child branch before applying to any database containing real records. The migration set contains no academic-data tables.

## API contract

See [Release 1 backend API contract](../../docs/BACKEND_API_CONTRACT.md). Public feed/detail reads do not require authentication. Registered receipts require a valid Neon Auth Bearer JWT. Every `/v1/admin/*` operation requires a verified server-side admin role. Guest metric writes must pass through the Worker; direct Neon writes require the server-to-server `X-EduNivora-Worker-Secret` assertion and fail closed if it is absent or invalid.

## Guest metrics privacy and limits

Guest events are aggregate event counts, not unique visitors. No guest ID, IP address, cookie, user-agent, device fingerprint, request ID, or stable cross-session identity is stored or forwarded. The Worker confirms a notice is published before allocating quota, uses a UTC date in its Durable Object name, and never refunds an ambiguous upstream reservation. Public notice reads remain available when metrics are unavailable. Worker quotas are configurable through `GUEST_METRIC_VIEWS_PER_ANNOUNCEMENT_UTC_DAY` and `GUEST_METRIC_DELIVERIES_PER_ANNOUNCEMENT_UTC_DAY` (defaults: 5,000 each).

## Authentication and external configuration

Email/password and OTP are implemented against Neon Managed Auth, but production email verification is blocked until the owner supplies and verifies project-owned SMTP configuration. Production Google OAuth is blocked until the owner supplies the project-owned Google OAuth client ID/secret and approves exact redirect/trusted-origin configuration. Do not use shared development OAuth/SMTP credentials as production configuration. No credentials belong in source, Flutter assets, logs, or chat.

The Android client does not require browser CORS origins. Keep `APP_ORIGINS` and `EDUNIVORA_APP_ORIGINS` unset/empty unless a separately approved origin is required. Do not configure Pages or Web origins for Release 1.

## Worker secret provisioning and deployment order

Production deployment is intentionally not performed by CI and requires explicit owner approval.

1. Review the Worker code, Durable Object SQLite migration, quotas, tests, and rollback plan.
2. Generate one random secret of at least 32 bytes in an approved secret manager. Do not paste it into chat, source, GitHub variables, or logs.
3. Provision that exact secret as Cloudflare Worker secret `NEON_GUEST_METRICS_SECRET` and Neon Function secret `GUEST_METRICS_PROXY_SECRET`. Never expose either value.
4. Set Worker variable `NEON_NOTICES_BASE_URL` to the verified Neon Function URL and quota variables to approved limits. No Pages origin is required for the Android client.
5. Deploy the Worker first, then deploy the reviewed Neon Function source with the matching secret. Do not deploy either without explicit production approval.
6. Smoke-test an unpublished/unknown notice (404), a valid published notice below quota (204), above-quota (429), missing/invalid upstream secret (503/403 at Neon), upstream failure (502), and public feed (200). Confirm direct guest POSTs to Neon are rejected and registered receipts/admin routes still enforce JWT roles.
7. Only after both services pass live checks may the Android app be built with `--dart-define=EDUNIVORA_GUEST_METRICS_PROXY_URL=<verified-worker-url>`. Without this value, guest metrics are disabled; public notices remain available.

### Rollback

Do not roll back to a Neon Function version that accepts direct unauthenticated guest writes. If the Worker is unhealthy, remove the guest metrics proxy URL from the Android build or roll back to another reviewed Worker build that preserves Durable Object quotas and server-secret verification. Guest counters may stop; public notices and local academic features must remain usable. Roll back Worker and Neon changes in a coordinated manner, preserving the fail-closed secret check.

## Release boundary

Release 1 has no Web application, Web admin, browser persistence, Cloudflare Pages deployment, academic cloud sync, Google Drive backup, backup encryption, or production SQLite encryption. Google Drive backup/restore and local database encryption are Release 2 work. Never claim production deployment or production readiness from source or CI alone.
