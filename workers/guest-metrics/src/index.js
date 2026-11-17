export class GuestMetrics {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/rate-limit") {
      return new Response("Not Found", { status: 404 });
    }

    let input;
    try {
      input = await request.json();
    } catch {
      return Response.json({ error: "Invalid rate-limit payload" }, { status: 400 });
    }

    if (!Number.isInteger(input?.minute) ||
        typeof input?.fingerprint !== "string" ||
        !/^[a-f0-9]{64}$/.test(input.fingerprint)) {
      return Response.json({ error: "Invalid rate-limit payload" }, { status: 400 });
    }

    const stored = await this.ctx.storage.get("rate_window");
    const windowState = stored?.minute === input.minute
      ? stored
      : { minute: input.minute, total: 0, counts: {} };

    const current = windowState.counts[input.fingerprint] || 0;
    if (current >= 60 || windowState.total >= 5000) {
      return Response.json({ allowed: false }, { status: 429 });
    }

    windowState.counts[input.fingerprint] = current + 1;
    windowState.total += 1;
    await this.ctx.storage.put("rate_window", windowState);
    if (stored?.minute !== input.minute) {
      await this.ctx.storage.setAlarm((input.minute + 1) * 60000 + 1000);
    }
    return Response.json({ allowed: true });
  }

  async alarm() {
    await this.ctx.storage.delete("rate_window");
  }
}

const HOP_BY_HOP_HEADERS = [
  "connection", "content-length", "keep-alive", "proxy-authenticate",
  "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade", "host"
];

function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin"
  };
}

async function fingerprintForMinute(ip, minute, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${minute}:${ip}`)
  );
  return Array.from(new Uint8Array(signature))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

export default {
  async fetch(request, env) {
    if (!env.NEON_NOTICES_API_ORIGIN || !env.NEON_WORKER_SHARED_SECRET) {
      return Response.json({ error: "Gateway is not configured" }, {
        status: 503,
        headers: { "Cache-Control": "no-store" }
      });
    }

    const incomingUrl = new URL(request.url);
    const origin = request.headers.get("Origin");
    const allowedOrigins = (env.ALLOWED_ORIGINS || "")
      .split(",").map((value) => value.trim()).filter(Boolean);

    if (origin && !allowedOrigins.includes(origin)) {
      return Response.json({ error: "Origin not allowed" }, { status: 403 });
    }

    const cors = origin ? corsHeaders(origin) : {};
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const isGuestMetric = request.method === "POST" &&
      /^\/v1\/announcements\/[0-9a-f-]+\/guest-(view|delivered)$/i.test(incomingUrl.pathname);

    if (isGuestMetric) {
      const ip = request.headers.get("CF-Connecting-IP") || "unknown";
      const minute = Math.floor(Date.now() / 60000);
      const fingerprint = await fingerprintForMinute(
        ip,
        minute,
        env.NEON_WORKER_SHARED_SECRET
      );
      const id = env.GUEST_METRICS.idFromName("global");
      const limiter = env.GUEST_METRICS.get(id);
      const limitResponse = await limiter.fetch(
        "https://guest-metrics.internal/rate-limit",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ minute, fingerprint })
        }
      );
      if (limitResponse.status === 429) {
        return Response.json({ error: { code: "rate_limited", message: "Please retry later." } }, {
          status: 429,
          headers: { ...cors, "Retry-After": "60", "Cache-Control": "no-store" }
        });
      }
      if (!limitResponse.ok) {
        return Response.json({ error: "Rate limiter unavailable" }, {
          status: 503,
          headers: { ...cors, "Cache-Control": "no-store" }
        });
      }
    }

    let upstreamOrigin;
    try {
      upstreamOrigin = new URL(env.NEON_NOTICES_API_ORIGIN);
      if (upstreamOrigin.protocol !== "https:" ||
          upstreamOrigin.pathname !== "/" ||
          upstreamOrigin.search || upstreamOrigin.hash ||
          upstreamOrigin.username || upstreamOrigin.password) {
        throw new Error("Invalid origin");
      }
    } catch {
      return Response.json({ error: "Invalid Neon API origin" }, {
        status: 503,
        headers: { ...cors, "Cache-Control": "no-store" }
      });
    }

    const target = new URL(incomingUrl.pathname + incomingUrl.search, upstreamOrigin);
    const headers = new Headers(request.headers);
    for (const name of HOP_BY_HOP_HEADERS) headers.delete(name);
    headers.delete("Origin");
    headers.delete("CF-Connecting-IP");
    headers.delete("X-Forwarded-For");
    headers.delete("X-Real-IP");
    headers.delete("Cookie");
    headers.delete("X-EduNivora-Worker-Secret");

    if (isGuestMetric) {
      headers.set("X-EduNivora-Worker-Secret", env.NEON_WORKER_SHARED_SECRET);
    }

    const init = { method: request.method, headers, redirect: "manual" };
    if (!["GET", "HEAD"].includes(request.method)) init.body = await request.arrayBuffer();

    try {
      const upstream = await fetch(target, init);
      const responseHeaders = new Headers(upstream.headers);
      for (const name of HOP_BY_HOP_HEADERS) responseHeaders.delete(name);
      responseHeaders.set("Cache-Control", "no-store");
      responseHeaders.set("X-Content-Type-Options", "nosniff");
      for (const [name, value] of Object.entries(cors)) responseHeaders.set(name, value);
      return new Response(upstream.body, {
        status: upstream.status,
        statusText: upstream.statusText,
        headers: responseHeaders
      });
    } catch {
      return Response.json({ error: { code: "upstream_unavailable", message: "EduNivora API is temporarily unavailable." } }, {
        status: 502,
        headers: { ...cors, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" }
      });
    }
  }
};