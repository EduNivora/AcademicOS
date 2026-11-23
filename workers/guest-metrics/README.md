# EduNivora Cloudflare edge gateway

The Worker is the public edge entrypoint for the Neon Notices API.

## Deployment

```bash
npx wrangler deploy --config workers/guest-metrics/wrangler.toml
```

## Bindings and secrets

- `GUEST_METRICS`: SQLite-backed Durable Object used for atomic daily aggregate quotas.
- `NEON_NOTICES_API_ORIGIN`: HTTPS origin of the Neon `notices` Function.
- `NEON_WORKER_SHARED_SECRET`: secret shared with the Neon Function. Never commit it or expose it to Flutter.
- `ALLOWED_ORIGINS`: optional exact comma-separated browser origins. Configure the actual production Web origin before enabling Web access.

Set the secret in both Cloudflare Worker secrets and the Neon Function deployment
environment under the same value.

## Rate control and privacy

Guest metrics use a single Durable Object transaction to enforce both:
- a default maximum of 5,000 accepted metric events per announcement per UTC day;
- a default maximum of 50,000 accepted metric events across all announcements per UTC day.

Both limits can be overridden using `MAX_ANNOUNCEMENT_METRICS_PER_DAY` and
`MAX_GUEST_METRICS_PER_DAY`. The Durable Object stores only the UTC date and
aggregate counts by announcement/event type. It does not store raw IPs, HMAC
fingerprints, guest IDs, device IDs, cookies, or per-request identity.

The global transaction is intentionally serialized to make the daily ceilings
strict across Cloudflare locations. This is a deliberate throughput trade-off:
guest analytics are best-effort and should never block public announcement
reading. An attacker can exhaust an announcement's daily quota and suppress
later aggregate counts for that announcement; this is accepted rather than
allowing unbounded counter inflation or database writes. If the upstream Neon
service fails after quota reservation, the event is not refunded or retried
automatically, preventing blind duplicate writes. When the quota or limiter is
unavailable, the Worker rejects only the metric write; the public feed remains
readable.

The Neon Function remains the source of truth for daily aggregate counters.
The shared secret blocks direct calls to the Neon guest metric routes.

## Endpoints

The Worker proxies `GET /health`, `GET /v1/announcements`, authenticated
account endpoints, and the two guest metric POST endpoints. It strips
client-supplied gateway-secret and forwarding/IP headers before constructing
trusted upstream requests.
