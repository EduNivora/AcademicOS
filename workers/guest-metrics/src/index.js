export class GuestMetrics {
  constructor(ctx, env = {}) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/consume") {
      return new Response("Not Found", { status: 404 });
    }

    let input;
    try {
      input = await request.json();
    } catch {
      return Response.json({ error: "Invalid quota payload" }, { status: 400 });
    }

    const validDate = typeof input?.date === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(input.date) &&
      !Number.isNaN(Date.parse(input.date)) &&
      new Date(input.date).toISOString().slice(0, 10) === input.date;
    const validAnnouncement = typeof input?.announcementId === "string" &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.announcementId);
    const validEvent = input?.event === "views" || input?.event === "delivered";

    if (!validDate || !validAnnouncement || !validEvent) {
      return Response.json({ error: "Invalid quota payload" }, { status: 400 });
    }

    const perAnnouncementLimit = Math.max(
      1,
      Number.parseInt(this.env.MAX_ANNOUNCEMENT_METRICS_PER_DAY ?? "5000", 10) || 5000,
    );
    const globalLimit = Math.max(
      1,
      Number.parseInt(this.env.MAX_GUEST_METRICS_PER_DAY ?? "50000", 10) || 50000,
    );

    let allowed = false;
    let scheduleCleanup = false;

    await this.ctx.storage.transaction(async (txn) => {
      const stored = await txn.get("daily_metrics");
      const state = stored?.date === input.date
        ? stored
        : { date: input.date, total: 0, announcements: {} };

      const current = state.announcements[input.announcementId] ?? {
        total: 0,
        views: 0,
        delivered: 0,
      };

      if (state.total >= globalLimit || current.total >= perAnnouncementLimit) {
        allowed = false;
        return;
      }

      state.total += 1;
      current.total += 1;
      current[input.event] += 1;
      state.announcements[input.announcementId] = current;
      await txn.put("daily_metrics", state);
      allowed = true;
      scheduleCleanup = stored?.date !== input.date;
    });

    if (scheduleCleanup) {
      const nextUtcDay = Date.parse(input.date + "T00:00:00.000Z") + 86_400_000;
      await this.ctx.storage.setAlarm(nextUtcDay + 1_000);
    }

    return allowed
      ? Response.json({ allowed: true })
      : Response.json({ error: { code: "daily_limit_reached", message: "Guest metrics daily limit reached." } }, { status: 429 });
  }

  async alarm() {
    const today = new Date().toISOString().slice(0, 10);
    await this.ctx.storage.transaction(async (txn) => {
      const stored = await txn.get("daily_metrics");
      if (stored && stored.date < today) {
        await txn.delete("daily_metrics");
      }
    });
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

export default {
  async fetch(request, env) {
    if (!env.NEON_NOTICES_API_ORIGIN ||
        !env.NEON_WORKER_SHARED_SECRET ||
        !env.GUEST_METRICS) {
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

    const metricMatch = request.method === "POST"
      ? incomingUrl.pathname.match(/^\/v1\/announcements\/([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\/guest-(view|delivered)$/i)
      : null;

    if (metricMatch) {
      const announcementId = metricMatch[1];
      const event = metricMatch[2].toLowerCase() === "view" ? "views" : "delivered";
      const date = new Date().toISOString().slice(0, 10);
      const id = env.GUEST_METRICS.idFromName("global");
      const limiter = env.GUEST_METRICS.get(id);

      let limitResponse;
      try {
        limitResponse = await limiter.fetch(new Request(
          "https://guest-metrics.internal/consume",
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ announcementId, date, event })
          }
        ));
      } catch {
        return Response.json({ error: "Rate limiter unavailable" }, {
          status: 503,
          headers: { ...cors, "Cache-Control": "no-store" }
        });
      }

      if (limitResponse.status === 429) {
        return Response.json({ error: { code: "rate_limited", message: "Daily guest metrics limit reached." } }, {
          status: 429,
          headers: { ...cors, "Retry-After": "86400", "Cache-Control": "no-store" }
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

    const isGuestMetric = Boolean(metricMatch);
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
