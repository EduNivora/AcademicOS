import test from "node:test";
import assert from "node:assert/strict";
import gateway, { GuestMetrics } from "./index.js";

function createStorage() {
  const values = new Map();
  let alarm = null;
  return {
    async get(key) { return values.get(key); },
    async put(key, value) { values.set(key, structuredClone(value)); },
    async delete(key) { return values.delete(key); },
    async setAlarm(value) { alarm = value; },
    get alarm() { return alarm; },
  };
}

function createGatewayEnv({ allowed = true, status = 204 } = {}) {
  const calls = { limiter: [], upstream: [] };
  const storage = createStorage();
  const env = {
    NEON_NOTICES_API_ORIGIN: "https://notices.example.test/",
    NEON_WORKER_SHARED_SECRET: "unit-test-secret",
    ALLOWED_ORIGINS: "",
    GUEST_METRICS: {
      idFromName(name) { assert.equal(name, "global"); return name; },
      get() {
        return {
          async fetch(request) {
            const body = await request.json();
            calls.limiter.push(body);
            return Response.json({ allowed }, { status: allowed ? 200 : 429 });
          },
        };
      },
    },
  };
  return { env, calls, storage, upstreamStatus: status };
}

test("Durable Object rejects malformed rate-limit payloads", async () => {
  const metrics = new GuestMetrics({ storage: createStorage() });
  const response = await metrics.fetch(new Request("https://do.test/rate-limit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ minute: "now", fingerprint: "invalid" }),
  }));
  assert.equal(response.status, 400);
});

test("Durable Object enforces per-fingerprint minute limit and schedules cleanup", async () => {
  const storage = createStorage();
  const metrics = new GuestMetrics({ storage });
  const minute = 30_000;
  const request = () => new Request("https://do.test/rate-limit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ minute, fingerprint: "a".repeat(64) }),
  });
  for (let index = 0; index < 60; index += 1) {
    assert.equal((await metrics.fetch(request())).status, 200);
  }
  assert.equal((await metrics.fetch(request())).status, 429);
  assert.equal(storage.alarm, (minute + 1) * 60_000 + 1_000);
  await metrics.alarm();
  assert.equal(await storage.get("rate_window"), undefined);
});

test("gateway fails closed when required configuration is missing", async () => {
  const response = await gateway.fetch(
    new Request("https://gateway.test/health"),
    {},
  );
  assert.equal(response.status, 503);
});

test("gateway rejects browser origins not explicitly allowlisted", async () => {
  const { env } = createGatewayEnv();
  const response = await gateway.fetch(new Request("https://gateway.test/health", {
    headers: { Origin: "https://untrusted.example.test" },
  }), env);
  assert.equal(response.status, 403);
});

test("gateway rate-limits guest metrics before proxying", async () => {
  const { env, calls } = createGatewayEnv({ allowed: false });
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    calls.upstream.push(true);
    return new Response(null, { status: 204 });
  };
  try {
    const response = await gateway.fetch(new Request(
      "https://gateway.test/v1/announcements/f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1/guest-view",
      { method: "POST", headers: { "CF-Connecting-IP": "203.0.113.10" } },
    ), env);
    assert.equal(response.status, 429);
    assert.equal(calls.upstream.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("gateway injects its secret and strips client-supplied trust and IP headers", async () => {
  const { env, calls } = createGatewayEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.upstream.push({ url: String(url), headers: new Headers(init.headers) });
    return new Response(null, { status: 204 });
  };
  try {
    const response = await gateway.fetch(new Request(
      "https://gateway.test/v1/announcements/f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1/guest-view",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "CF-Connecting-IP": "203.0.113.10",
          "X-Forwarded-For": "203.0.113.10",
          "X-EduNivora-Worker-Secret": "attacker-controlled",
        },
        body: "{}",
      },
    ), env);
    assert.equal(response.status, 204);
    assert.equal(calls.limiter.length, 1);
    assert.equal(calls.upstream.length, 1);
    const headers = calls.upstream[0].headers;
    assert.equal(headers.get("X-EduNivora-Worker-Secret"), "unit-test-secret");
    assert.equal(headers.has("CF-Connecting-IP"), false);
    assert.equal(headers.has("X-Forwarded-For"), false);
    assert.equal(headers.has("Origin"), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("gateway forwards registered bearer credentials without adding the guest secret", async () => {
  const { env, calls } = createGatewayEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.upstream.push({ url: String(url), headers: new Headers(init.headers) });
    return Response.json({ user: { role: "student" } }, { status: 200 });
  };
  try {
    const response = await gateway.fetch(new Request("https://gateway.test/v1/me", {
      headers: { Authorization: "Bearer signed-user-token" },
    }), env);
    assert.equal(response.status, 200);
    assert.equal(calls.upstream[0].headers.get("Authorization"), "Bearer signed-user-token");
    assert.equal(calls.upstream[0].headers.has("X-EduNivora-Worker-Secret"), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
