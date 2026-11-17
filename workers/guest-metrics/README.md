# EduNivora Guest Metrics Worker

Production Worker for privacy-preserving anonymous usage counters.

## Deployment

```bash
npx wrangler deploy --config workers/guest-metrics/wrangler.toml
```

The Worker uses a SQLite-backed Durable Object named `GuestMetrics`. The
namespace is provisioned by the v1 migration and bound as `GUEST_METRICS`.

## Endpoints

- `GET /health` — liveness check.
- `POST /api/guest-metrics` — increments an anonymous counter.

Accepted request bodies:

```json
{"event":"app_open"}
{"event":"session_start"}
{"event":"feature_used"}
```

No account identifiers, device identifiers, IP addresses, or other personal
data are persisted. Counters are partitioned by UTC day and event type.

## Configuration

- `ALLOWED_ORIGINS` — optional comma-separated browser origins. Leave unset
  for native clients and unrestricted CORS; configure exact web origins before
  enabling browser-based production traffic.

No Neon database password is needed for anonymous counters: durable counters
are stored in the Durable Object. Neon Auth remains the identity provider for
account sign-in and is configured separately.
