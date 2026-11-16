import {
  nextUtcMidnight,
  quotaObjectName,
  utcMetricDate,
} from "./quota.mjs";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DEFAULT_DAILY_VIEWS = 5000;
const DEFAULT_DAILY_DELIVERIES = 5000;

function jsonResponse(status, code, message, origin, allowedOrigins) {
  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  });
  if (origin && allowedOrigins.includes(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
  }
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers,
  });
}

function response(status, origin, allowedOrigins) {
  const headers = new Headers({
    "Cache-Control": "no-store",
    "Vary": "Origin",
  });
  if (origin && allowedOrigins.includes(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
  }
  return new Response(null, { status, headers });
}

function positiveLimit(value, fallback) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function configuredOrigins(env) {
  return (env.EDUNIVORA_APP_ORIGINS ?? "https://edunivora.pages.dev")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

/**
 * Guest metrics-only ingress.
 *
 * The Worker never reads or forwards source IP, cookies, user-agent, request
 * identifiers, or any stable guest identity. Only the announcement UUID and
 * metric kind select an aggregate daily quota.
 */
export async function handleGuestMetricsRequest(
  request,
  env,
  {
    fetchImpl = fetch,
    now = new Date(),
  } = {},
) {
  const url = new URL(request.url);
  const origin = request.headers.get("Origin");
  const allowedOrigins = configuredOrigins(env);

  if (origin && !allowedOrigins.includes(origin)) {
    return jsonResponse(403, "origin_not_allowed", "Origin is not allowed.", null, []);
  }

  if (request.method === "OPTIONS") {
    if (!origin) return response(204, null, []);
    const preflight = response(204, origin, allowedOrigins);
    preflight.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    preflight.headers.set("Access-Control-Allow-Headers", "Content-Type");
    preflight.headers.set("Access-Control-Max-Age", "600");
    return preflight;
  }

  if (request.method !== "POST") {
    return jsonResponse(405, "method_not_allowed", "Only POST is supported.", origin, allowedOrigins);
  }

  const match = url.pathname.match(
    /^\/v1\/announcements\/([0-9a-f-]{36})\/guest-(view|delivered)$/,
  );
  if (!match || !UUID_PATTERN.test(match[1])) {
    return jsonResponse(404, "not_found", "Guest metrics route not found.", origin, allowedOrigins);
  }

  // This endpoint has no request payload. Refuse extra input instead of
  // accidentally forwarding client-controlled headers or content.
  const contentLength = Number(request.headers.get("Content-Length") ?? "0");
  if (!Number.isFinite(contentLength) || contentLength > 0 || request.body !== null) {
    return jsonResponse(400, "unexpected_body", "A request body is not accepted.", origin, allowedOrigins);
  }

  const upstreamBase = env.NEON_NOTICES_BASE_URL;
  const upstreamSecret = env.NEON_GUEST_METRICS_SECRET;
  const namespace = env.ANNOUNCEMENT_METRIC_QUOTAS;
  if (
    typeof upstreamBase !== "string" ||
    typeof upstreamSecret !== "string" ||
    upstreamSecret.length < 32 ||
    !namespace ||
    typeof namespace.idFromName !== "function" ||
    typeof namespace.get !== "function"
  ) {
    return jsonResponse(503, "metrics_unavailable", "Guest metrics are temporarily unavailable.", origin, allowedOrigins);
  }

  const announcementId = match[1].toLowerCase();
  const kind = match[2] === "view" ? "view" : "delivered";
  let metricDate;
  let expiresAt;
  try {
    metricDate = utcMetricDate(now);
    expiresAt = nextUtcMidnight(now);
  } catch {
    return jsonResponse(500, "quota_clock_error", "Guest metrics are temporarily unavailable.", origin, allowedOrigins);
  }

  const limit = kind === "view"
    ? positiveLimit(env.GUEST_METRIC_VIEWS_PER_ANNOUNCEMENT_UTC_DAY, DEFAULT_DAILY_VIEWS)
    : positiveLimit(env.GUEST_METRIC_DELIVERIES_PER_ANNOUNCEMENT_UTC_DAY, DEFAULT_DAILY_DELIVERIES);

  // Confirm the announcement is currently public before allocating a
  // Durable Object. Arbitrary UUIDs must not create unbounded quota objects.
  const upstreamBaseUrl = upstreamBase;
  try {
    const announcementUrl = new URL(
      `/v1/announcements/${announcementId}`,
      upstreamBaseUrl,
    );
    const announcementResponse = await fetchImpl(announcementUrl, {
      method: "GET",
      headers: { "Accept": "application/json" },
      redirect: "manual",
    });
    if (announcementResponse.status === 404) {
      return jsonResponse(404, "announcement_not_found", "Announcement not found.", origin, allowedOrigins);
    }
    if (announcementResponse.status !== 200) {
      return jsonResponse(502, "metrics_upstream_failed", "Guest metrics could not be recorded.", origin, allowedOrigins);
    }
  } catch {
    return jsonResponse(502, "metrics_upstream_failed", "Guest metrics could not be recorded.", origin, allowedOrigins);
  }

  try {
    // One globally-coordinated Durable Object per announcement and UTC day.
    const quotaName = quotaObjectName(announcementId, metricDate);
    const quotaId = namespace.idFromName(quotaName);
    const quota = namespace.get(quotaId);
    const reservation = await quota.reserve(kind, limit, expiresAt);
    if (!reservation?.allowed) {
      return jsonResponse(429, "daily_quota_exceeded", "The daily guest metric limit has been reached.", origin, allowedOrigins);
    }
  } catch {
    return jsonResponse(503, "quota_unavailable", "Guest metrics are temporarily unavailable.", origin, allowedOrigins);
  }

  // Only a minimal server-to-server assertion is sent to Neon. Incoming
  // headers, cookies, IP metadata, and body are intentionally not forwarded.
  const upstreamUrl = new URL(url.pathname, `${upstreamBase.replace(/\/+$/, "")}/`);
  try {
    const upstream = await fetchImpl(upstreamUrl, {
      method: "POST",
      headers: {
        "X-EduNivora-Worker-Secret": upstreamSecret,
        "Accept": "application/json",
      },
      body: null,
      signal: AbortSignal.timeout(8000),
      redirect: "manual",
    });

    if (upstream.status === 204 || upstream.ok) {
      return response(204, origin, allowedOrigins);
    }
    if (upstream.status === 404) {
      return jsonResponse(404, "announcement_not_found", "Announcement not found.", origin, allowedOrigins);
    }

    // Quota reservations are not refunded for ambiguous upstream failures.
    // This is intentionally fail-closed: an upstream timeout cannot be used to
    // recycle quota after Neon may already have committed the aggregate write.
    return jsonResponse(502, "metrics_upstream_failed", "Guest metrics could not be recorded.", origin, allowedOrigins);
  } catch {
    return jsonResponse(502, "metrics_upstream_failed", "Guest metrics could not be recorded.", origin, allowedOrigins);
  }
}
