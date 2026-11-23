import test from "node:test";
import assert from "node:assert/strict";
import gateway, { GuestMetrics } from "./index.js";

function createStorage() {
  const values = new Map();
  let alarm = null;
  let maxDeleteBatch = 0;
  let tail = Promise.resolve();
  return {
    async get(key) { return values.get(key); },
    async put(key, value) { values.set(key, structuredClone(value)); },
    async delete(keys) {
      const list = Array.isArray(keys) ? keys : [keys];
      maxDeleteBatch = Math.max(maxDeleteBatch, list.length);
      if (list.length > 128) throw new RangeError("delete accepts at most 128 keys");
      let deleted = false;
      for (const key of list) deleted = values.delete(key) || deleted;
      return deleted;
    },
    async list({ prefix = "", limit = 128, startAfter } = {}) {
      const entries = [...values.entries()]
        .filter(([key]) => key.startsWith(prefix) && (!startAfter || key > startAfter))
        .sort(([left], [right]) => left.localeCompare(right))
        .slice(0, limit);
      return new Map(entries);
    },
    async setAlarm(value) { alarm = value; },
    get alarm() { return alarm; },
    get maxDeleteBatch() { return maxDeleteBatch; },
    async transaction(callback) {
      const operation = tail.then(async () => callback());
      tail = operation.catch(() => {});
      return operation;
    },
  };
}

const announcementId = "f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1";
const otherAnnouncementId = "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0";

function quotaRequest({ id = announcementId, date = "2026-11-23", event = "views" } = {}) {
  return new Request("https://do.test/consume", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ announcementId: id, date, event }),
  });
}

function createGatewayEnv({ perAnnouncement = "5000", global = "50000" } = {}) {
  const calls = { limiter: [], upstream: [] };
  const storage = createStorage();
  const metrics = new GuestMetrics({ storage }, {
    MAX_ANNOUNCEMENT_METRICS_PER_DAY: perAnnouncement,
    MAX_GUEST_METRICS_PER_DAY: global,
  });
  const env = {
    NEON_NOTICES_API_ORIGIN: "https://notices.example.test/",
    NEON_WORKER_SHARED_SECRET: "unit-test-secret",
    ALLOWED_ORIGINS: "",
    GUEST_METRICS: {
      idFromName(name) { assert.equal(name, "global"); return name; },
      get() {
        return {
          async fetch(request) {
            const response = await metrics.fetch(request);
            calls.limiter.push(response.status);
            return response;
          },
        };
      },
    },
  };
  return { env, calls, storage };
}

test("Durable Object rejects malformed quota payloads", async () => {
  const metrics = new GuestMetrics({ storage: createStorage() });
  const response = await metrics.fetch(new Request("https://do.test/consume", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ date: "bad", announcementId: "not-a-uuid", event: "view" }),
  }));
  assert.equal(response.status, 400);
});

test("Durable Object enforces per-announcement daily limit atomically under concurrency", async () => {
  const storage = createStorage();
  const metrics = new GuestMetrics({ storage }, {
    MAX_ANNOUNCEMENT_METRICS_PER_DAY: "5",
    MAX_GUEST_METRICS_PER_DAY: "50",
  });
  const results = await Promise.all(
    Array.from({ length: 20 }, () => metrics.fetch(quotaRequest())),
  );
  assert.equal(results.filter((response) => response.status === 200).length, 5);
  assert.equal(results.filter((response) => response.status === 429).length, 15);
  assert.equal(await storage.get("global:2026-11-23"), 5);
  const state = await storage.get(`announcement:2026-11-23:${announcementId}`);
  assert.equal(state.total, 5);
  assert.equal(state.views, 5);
  assert.equal(storage.alarm, Date.parse("2026-11-24T00:00:00.000Z") + 1_000);
  const storedValues = JSON.stringify([...await storage.list({ prefix: "" })]);
  assert.equal(storedValues.includes("203.0.113"), false);
});

test("Durable Object enforces a global daily ceiling across announcements", async () => {
  const metrics = new GuestMetrics({ storage: createStorage() }, {
    MAX_ANNOUNCEMENT_METRICS_PER_DAY: "5",
    MAX_GUEST_METRICS_PER_DAY: "3",
  });
  const results = await Promise.all([
    metrics.fetch(quotaRequest({ id: announcementId })),
    metrics.fetch(quotaRequest({ id: otherAnnouncementId })),
    metrics.fetch(quotaRequest({ id: announcementId, event: "delivered" })),
    metrics.fetch(quotaRequest({ id: otherAnnouncementId, event: "delivered" })),
  ]);
  assert.equal(results.filter((response) => response.status === 200).length, 3);
  assert.equal(results.filter((response) => response.status === 429).length, 1);
  assert.equal(await metrics.ctx.storage.get("global:2026-11-23"), 3);
});

test("Durable Object resets counters when the UTC metric date changes", async () => {
  const storage = createStorage();
  const metrics = new GuestMetrics({ storage }, {
    MAX_ANNOUNCEMENT_METRICS_PER_DAY: "1",
    MAX_GUEST_METRICS_PER_DAY: "10",
  });
  assert.equal((await metrics.fetch(quotaRequest({ date: "2026-11-23" }))).status, 200);
  assert.equal((await metrics.fetch(quotaRequest({ date: "2026-11-23" }))).status, 429);
  assert.equal((await metrics.fetch(quotaRequest({ date: "2026-11-24" }))).status, 200);
  assert.equal(await storage.get("global:2026-11-24"), 1);
});

test("Durable Object alarm paginates expired keys and deletes in batches of 128", async () => {
  const storage = createStorage();
  const metrics = new GuestMetrics({ storage }, {
    MAX_ANNOUNCEMENT_METRICS_PER_DAY: "5",
    MAX_GUEST_METRICS_PER_DAY: "50",
    now: () => Date.parse("2026-11-24T00:00:05.000Z"),
  });
  for (let index = 0; index < 260; index += 1) {
    await storage.put(`announcement:2026-11-23:legacy-${String(index).padStart(3, "0")}`, {
      total: 1,
      views: 1,
      delivered: 0,
    });
  }
  await storage.put("global:2026-11-23", 260);
  await storage.put("announcement:2026-11-24:current", {
    total: 1,
    views: 1,
    delivered: 0,
  });
  await storage.put("global:2026-11-24", 1);

  await metrics.alarm();

  const expired = await storage.list({ prefix: "announcement:2026-11-23:" });
  assert.equal(expired.size, 0);
  assert.equal(await storage.get("global:2026-11-23"), undefined);
  assert.equal(await storage.get("global:2026-11-24"), 1);
  assert.equal(storage.maxDeleteBatch, 128);
});

test("gateway fails closed when required configuration is missing", async () => {
  const response = await gateway.fetch(new Request("https://gateway.test/health"), {});
  assert.equal(response.status, 503);
});

test("gateway rejects browser origins not explicitly allowlisted", async () => {
  const { env } = createGatewayEnv();
  const response = await gateway.fetch(new Request("https://gateway.test/health", {
    headers: { Origin: "https://untrusted.example.test" },
  }), env);
  assert.equal(response.status, 403);
});

test("gateway rejects oversized metric payloads before consuming quota", async () => {
  const { env, calls, storage } = createGatewayEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { calls.upstream.push(true); return new Response(null, { status: 204 }); };
  try {
    const today = new Date().toISOString().slice(0, 10);
    const response = await gateway.fetch(new Request(
      `https://gateway.test/v1/announcements/${announcementId}/guest-view`,
      { method: "POST", body: "x".repeat(65 * 1024) },
    ), env);
    assert.equal(response.status, 413);
    assert.equal(await storage.get(`global:${today}`), undefined);
    assert.equal(calls.upstream.length, 0);
    assert.equal(calls.limiter.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("gateway rate-limits guest metrics before proxying", async () => {
  const { env, calls } = createGatewayEnv({ perAnnouncement: "1", global: "10" });
  await env.GUEST_METRICS.get().fetch(quotaRequest());
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    calls.upstream.push(true);
    return new Response(null, { status: 204 });
  };
  try {
    const response = await gateway.fetch(new Request(
      `https://gateway.test/v1/announcements/${announcementId}/guest-view`,
      { method: "POST" },
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
      `https://gateway.test/v1/announcements/${announcementId}/guest-view`,
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

test("guest metric upstream failure does not retry or refund the reserved quota", async () => {
  const { env, calls, storage } = createGatewayEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { calls.upstream.push(true); throw new Error("private upstream details"); };
  try {
    const response = await gateway.fetch(new Request(
      `https://gateway.test/v1/announcements/${announcementId}/guest-view`,
      { method: "POST" },
    ), env);
    assert.equal(response.status, 502);
    assert.equal(calls.upstream.length, 1);
    assert.equal(calls.limiter.length, 1);
    const today = new Date().toISOString().slice(0, 10);
    assert.equal(await storage.get(`global:${today}`), 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("gateway returns 502 on upstream failure and does not leak internal details", async () => {
  const { env } = createGatewayEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error("private upstream details"); };
  try {
    const response = await gateway.fetch(new Request("https://gateway.test/health"), env);
    assert.equal(response.status, 502);
    assert.equal((await response.json()).error.code, "upstream_unavailable");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
