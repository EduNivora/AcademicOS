# EduNivora Release 1 — Backend API Contract

**Scope:** Android client, optional account identity, public notices, registered receipts, and anonymous aggregate guest metrics only. Academic records and attachment bytes are never sent to or stored by this backend.

## Base URL and response conventions

The Notices API base URL is the Neon Function URL supplied by the project owner. All JSON errors use:

```json
{ "error": { "code": "stable_error_code", "message": "Safe user-facing message" } }
```

Do not expose SQL errors, stack traces, tokens, secret values, or provider internals. Public read endpoints are cacheable only according to the API response headers; authenticated/admin/report responses must not be cached by shared clients.

## Identity and authorization

- Public endpoints: no Authorization header required.
- Registered receipt and `GET /v1/me`: `Authorization: Bearer <Neon Managed Auth access JWT>`.
- Operator endpoints: same Bearer JWT plus a server-side `app_users.role = 'admin'` projection. Never accept a role or `isAdmin` value from the request body.
- Guest metric writes: Android clients call the configured Cloudflare Worker URL, not the Neon Function. The Worker calls the Neon Function with `X-EduNivora-Worker-Secret`; direct guest metric writes are rejected. If the Worker URL is not configured, guest metrics are disabled and public notice reading continues.

## Endpoints

| Method and path | Auth | Purpose |
|---|---|---|
| `GET /health` | Public | Operational health and database connectivity check |
| `GET /v1/me` | Bearer JWT | Return the authenticated profile and server-owned role |
| `GET /v1/announcements?limit=20&before=<ISO timestamp>` | Public | Return published notices, newest first; limit is clamped to 1–50 |
| `GET /v1/announcements/:id` | Public | Return one published notice; drafts/archived notices are not exposed |
| `POST /v1/announcements/:id/delivered` | Bearer JWT | Idempotently acknowledge device delivery for a registered account |
| `POST /v1/announcements/:id/read` | Bearer JWT | Idempotently record that a registered user opened/read a notice |
| `POST /v1/announcements/:id/guest-delivered` | Worker secret only | Increment anonymous aggregate daily delivery count |
| `POST /v1/announcements/:id/guest-view` | Worker secret only | Increment anonymous aggregate daily view count |
| `POST /v1/admin/announcements` | Admin JWT | Create a draft notice |
| `PATCH /v1/admin/announcements/:id` | Admin JWT | Edit a draft notice |
| `POST /v1/admin/announcements/:id/publish` | Admin JWT | Publish a draft notice |
| `POST /v1/admin/announcements/:id/archive` | Admin JWT | Retire/archive a notice |
| `GET /v1/admin/announcements?status=draft\|published\|archived` | Admin JWT | List operator notices by state |
| `GET /v1/admin/announcements/:id/report` | Admin JWT | Read notice report and registered/aggregate receipt counts |

### Request bodies

Create:

```json
{ "title": "Notice title", "body": "Plain-text notice body" }
```

Edit:

```json
{ "title": "Updated title", "body": "Updated plain-text body" }
```

Title and body are required non-empty strings and are length-limited by the database/API validation. No academic records, files, HTML, or arbitrary metadata are accepted as notice payloads. Publish/archive/receipt/guest metric requests have no client-controlled body.

### Response shapes

- Feed: `{ "items": [{ "id", "title", "body", "published_at" }] }`
- Detail: `{ "item": { "id", "title", "body", "published_at" } }`
- Current user: `{ "user": { "id", "displayName", "email", "role" } }`
- Create/update/publish/archive and receipt operations return the created/updated resource or an empty success response according to the route handler; clients must rely on HTTP status and the JSON error envelope rather than assuming every successful operation returns a body.

## Receipt and publication semantics

These are three different facts and must never be conflated:

1. **Server acceptance/publication:** the operator's notice mutation is committed by the API. A notice is publicly retrievable only when its status is `published` and `published_at` is set.
2. **Device delivery acknowledgement:** the installation reports that it received/processed the notice. Offline devices cannot acknowledge delivery in real time.
3. **User opening/viewing:** the user opens the notice and the client records a read/view event.

Registered delivery/read receipts are account-linked and unique per notice/account. Guest metrics are anonymous daily aggregate event counters, not unique visitors and not named guest histories. A delivery receipt is not proof of a read.

## Guest metrics Worker behavior

The Worker accepts only POSTs to the two guest metric routes. It validates the notice is currently published before allocating a quota object, reserves quota atomically per notice and UTC day, and rejects over-quota requests with HTTP 429. Unknown/unpublished notices return 404. Missing Worker configuration fails closed with 503. Upstream failures return a generic 502 without leaking upstream response bodies. The Worker forwards only the notice route, a server-to-server secret, and an Accept header; it does not forward cookies, IP metadata, user-agent, request IDs, bodies, or stable guest identifiers.

Default quotas are 5,000 views and 5,000 delivery acknowledgements per notice per UTC day. Quotas are operational abuse ceilings, not unique-user counts. If metrics are unavailable, the app must continue to show public notices and preserve local academic operation.

## HTTP status expectations

- `200`: successful read.
- `201`: resource created, where the handler returns a created resource.
- `204`: successful receipt/metric write with no response body.
- `400`: malformed input, UUID, cursor, or unexpected Worker body.
- `401`: missing/invalid/expired JWT or unavailable account identity.
- `403`: authenticated non-admin or missing/invalid Worker assertion.
- `404`: unknown notice or notice not publicly available.
- `429`: Worker quota exceeded.
- `500`: generic unexpected server failure.
- `502`: upstream metric failure.
- `503`: required metric proxy/secret configuration unavailable.

## Configuration boundary

Server-only values include Neon database connection configuration, Neon Auth base/JWKS URLs, `GUEST_METRICS_PROXY_SECRET`, and Cloudflare `NEON_GUEST_METRICS_SECRET`. The two guest-metric secrets must be the same randomly generated value of at least 32 bytes, provisioned independently into the two secret managers. Never put them in Flutter, source control, CI logs, or chat. Production SMTP and project-owned Google OAuth credentials are separate owner-provided requirements. No production secrets or deployments are changed by CI.
