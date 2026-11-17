export class GuestMetrics {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/increment") {
      return new Response("Not Found", { status: 404 });
    }

    let input;
    try {
      input = await request.json();
    } catch {
      return Response.json({ error: "Invalid JSON" }, { status: 400 });
    }

    const allowed = new Set(["app_open", "session_start", "feature_used"]);
    if (!input || !allowed.has(input.event)) {
      return Response.json({ error: "Unsupported event" }, { status: 400 });
    }

    const day = new Date().toISOString().slice(0, 10);
    const key = `metric:${day}:${input.event}`;
    const count = (await this.ctx.storage.get(key)) || 0;
    await this.ctx.storage.put(key, count + 1);
    return Response.json({ accepted: true });
  }
}

const corsHeaders = (origin) => ({
  "Access-Control-Allow-Origin": origin || "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin"
});

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");
    const configured = (env.ALLOWED_ORIGINS || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean);

    if (origin && configured.length &&
        !configured.includes("*") && !configured.includes(origin)) {
      return Response.json({ error: "Origin not allowed" }, { status: 403 });
    }

    const allowedOrigin = origin &&
      (!configured.length || configured.includes("*") || configured.includes(origin))
      ? origin
      : null;
    const cors = corsHeaders(allowedOrigin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    if (url.pathname === "/health" && request.method === "GET") {
      return Response.json(
        { service: "edunivora-guest-metrics", status: "ok" },
        { headers: cors }
      );
    }

    if (url.pathname === "/api/guest-metrics" && request.method === "POST") {
      const body = await request.text();
      if (new TextEncoder().encode(body).byteLength > 2048) {
        return Response.json({ error: "Payload too large" }, {
          status: 413,
          headers: cors
        });
      }

      const id = env.GUEST_METRICS.idFromName("global");
      const stub = env.GUEST_METRICS.get(id);
      const response = await stub.fetch(
        "https://guest-metrics.internal/increment",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body
        }
      );

      return new Response(response.body, {
        status: response.status,
        headers: {
          ...Object.fromEntries(response.headers),
          ...cors,
          "Cache-Control": "no-store",
          "X-Content-Type-Options": "nosniff"
        }
      });
    }

    return Response.json({ error: "Not Found" }, {
      status: 404,
      headers: cors
    });
  }
};