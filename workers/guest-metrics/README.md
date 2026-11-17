# EduNivora Cloudflare edge gateway

The Worker is the public edge entrypoint for the Neon Notices API.

## Deployment

```bash
npx wrangler deploy --config workers/guest-metrics/wrangler.toml
```

## Bindings and secrets

- `GUEST_METRICS`: SQLite-backed Durable Object used only for short-lived rate-limit windows.
- `NEON_NOTICES_API_ORIGIN`: HTTPS origin of the Neon `notices` Function.
- `NEON_WORKER_SHARED_SECRET`: secret shared with the Neon Function. Never commit it or expose it to Flutter.
- `ALLOWED_ORIGINS`: optional exact comma-separated browser origins. Release 1 is Android-only.

Set the secret in both Cloudflare Worker secrets and the Neon Function deployment
environment under the same name.

## Rate control and privacy

Only the two guest counter routes are rate-limited: `guest-view` and
`guest-delivered`. The Worker derives an HMAC-SHA256 fingerprint from the
Cloudflare client IP and current UTC minute. The raw IP is never persisted or
forwarded to Neon. The Durable Object retains only per-minute HMAC counters,
resets its state at the next minute, and allows at most 60 guest metric requests
per minute per network address, with a 5,000-request global per-minute ceiling.

The Neon Function remains the source of truth for daily aggregate counters.
The shared secret blocks direct calls to the Neon guest metric routes.
Public announcement reads and authenticated registered-user endpoints are
proxied unchanged.

## Endpoints

The Worker proxies the Neon API, including `GET /health`, `GET
/v1/announcements`, authenticated account endpoints, and the two guest metric
POST endpoints.
