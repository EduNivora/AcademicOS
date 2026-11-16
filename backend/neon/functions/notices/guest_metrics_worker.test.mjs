import test from "node:test";
import assert from "node:assert/strict";
import {
  ensureQuotaSchema,
  nextUtcMidnight,
  quotaObjectName,
  reserveDailyQuota,
  utcMetricDate,
} from "../../guest-metrics-worker/quota.mjs";
import { handleGuestMetricsRequest } from "../../guest-metrics-worker/worker.mjs";

const announcementId = "f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1";
const secret = "worker-to-neon-secret-".padEnd(48, "x");

class MemorySql {
  constructor() {
    this.rows = new Map();
  }

  exec(statement, ...params) {
    if (statement.includes("CREATE TABLE")) {
      return { toArray: () => [] };
    }
    if (statement.includes("INSERT INTO guest_metric_quotas")) {
      const [kind, limit] = params;
      const used = this.rows.get(kind) ?? 0;
      if (used >= limit) return { toArray: () => [] };
      const next = used + 1;
      this.rows.set(kind, next);
      return { toArray: () => [{ used_count: next }] };
    }
    if (statement.includes("DELETE FROM guest_metric_quotas")) {
      this.rows.clear();
      return { one: () => null };
    }
    throw new Error("Unexpected SQL in quota test double.");
  }
}

function createNamespace() {
  const objects = new Map();
  return {
    objects,
    idFromName(name) {
      return name;
    },
    get(id) {
      if (!objects.has(id)) {
        const sql = new MemorySql();
        ensureQuotaSchema(sql);
        objects.set(id, {
          reserve: async (kind, limit) => reserveDailyQuota(sql, kind, limit),
          sql,
        });
      }
      return objects.get(id);
    },
  };
}

function makeEnv({ limit = 2, namespace = createNamespace(), ...overrides } = {}) {
  return {
    NEON_NOTICES_BASE_URL: "https://notices.example.test",
    NEON_GUEST_METRICS_SECRET: secret,
    EDUNIVORA_APP_ORIGINS: "https://edunivora.pages.dev",
    GUEST_METRIC_VIEWS_PER_ANNOUNCEMENT_UTC_DAY: String(limit),
    GUEST_METRIC_DELIVERIES_PER_ANNOUNCEMENT_UTC_DAY: String(limit),
    ANNOUNCEMENT_METRIC_QUOTAS: namespace,
    ...overrides,
  };
}

function metricRequest(kind = "view", origin = "https://edunivora.pages.dev") {
  return new Request(
    `https://metrics.example.test/v1/announcements/${announcementId}/guest-${kind}`,
    { method: "POST", headers: origin ? { Origin: origin } : {} },
  );
}

test("quota accepts events below the limit", () => {
  const sql = new MemorySql();
  ensureQuotaSchema(sql);
  assert.deepEqual(reserveDailyQuota(sql, "view", 3), { allowed: true, used: 1 });
  assert.deepEqual(reserveDailyQuota(sql, "view", 3), { allowed: true, used: 2 });
});

test("quota accepts the exact limit and rejects the next event", () => {
  const sql = new MemorySql();
  ensureQuotaSchema(sql);
  assert.equal(reserveDailyQuota(sql, "delivered", 2).allowed, true);
  assert.equal(reserveDailyQuota(sql, "delivered", 2).allowed, true);
  assert.deepEqual(reserveDailyQuota(sql, "delivered", 2), { allowed: false, used: 2 });
});

test("concurrent bursts cannot exceed the atomic global quota", async () => {
  const namespace = createNamespace();
  const env = makeEnv({ limit: 7, namespace });
  let upstreamWrites = 0;
  const fetchImpl = async (_url, options) => {
    if (options.method === "GET") {
      return new Response(JSON.stringify({ item: { id: announcementId } }), { status: 200 });
    }
    upstreamWrites += 1;
    return new Response(null, { status: 204 });
  };

  const responses = await Promise.all(
    Array.from({ length: 80 }, () =>
      handleGuestMetricsRequest(metricRequest(), env, {
        fetchImpl,
        now: new Date("2026-11-16T12:00:00.000Z"),
      }),
    ),
  );

  assert.equal(responses.filter((item) => item.status === 204).length, 7);
  assert.equal(responses.filter((item) => item.status === 429).length, 73);
  assert.equal(upstreamWrites, 7);
  const quota = namespace.getByName(quotaObjectName(announcementId, "2026-11-16"));
  assert.equal(quota.sql.rows.get("view"), 7);
});

test("separate Worker instances share the same announcement-day Durable Object", async () => {
  const namespace = createNamespace();
  const envA = makeEnv({ limit: 1, namespace });
  const envB = makeEnv({ limit: 1, namespace });
  let upstreamWrites = 0;
  const fetchImpl = async (_url, options) => {
    if (options.method === "GET") {
      return new Response(JSON.stringify({ item: { id: announcementId } }), { status: 200 });
    }
    upstreamWrites += 1;
    return new Response(null, { status: 204 });
  };
  const now = new Date("2026-11-16T12:00:00.000Z");

  const [first, second] = await Promise.all([
    handleGuestMetricsRequest(metricRequest(), envA, { fetchImpl, now }),
    handleGuestMetricsRequest(metricRequest(), envB, { fetchImpl, now }),
  ]);

  assert.deepEqual([first.status, second.status].sort(), [204, 429]);
  assert.equal(upstreamWrites, 1);
  assert.equal(namespace.objects.size, 1);
});

test("UTC date boundary creates a fresh daily quota object", async () => {
  const namespace = createNamespace();
  const env = makeEnv({ limit: 1, namespace });
  const fetchImpl = async () => new Response(null, { status: 204 });

  const beforeMidnight = new Date("2026-11-16T23:59:59.999Z");
  const afterMidnight = new Date("2026-11-17T00:00:00.000Z");
  const first = await handleGuestMetricsRequest(metricRequest(), env, {
    fetchImpl,
    now: beforeMidnight,
  });
  const second = await handleGuestMetricsRequest(metricRequest(), env, {
    fetchImpl,
    now: afterMidnight,
  });

  assert.equal(first.status, 204);
  assert.equal(second.status, 204);
  assert.equal(namespace.objects.size, 2);
  assert.equal(utcMetricDate(beforeMidnight), "2026-11-16");
  assert.equal(utcMetricDate(afterMidnight), "2026-11-17");
  assert.equal(nextUtcMidnight(beforeMidnight), Date.parse("2026-11-17T00:00:00.000Z"));
});

test("upstream failure returns 502 and does not refund a possibly committed write", async () => {
  const env = makeEnv({ limit: 1 });
  let upstreamCalls = 0;
  const fetchImpl = async (_url, options) => {
    if (options.method === "GET") {
      return new Response(JSON.stringify({ item: { id: announcementId } }), { status: 200 });
    }
    upstreamCalls += 1;
    return new Response("internal detail must not be exposed", { status: 500 });
  };

  const first = await handleGuestMetricsRequest(metricRequest(), env, { fetchImpl });
  const second = await handleGuestMetricsRequest(metricRequest(), env, { fetchImpl });

  assert.equal(first.status, 502);
  assert.equal(second.status, 429);
  assert.equal(upstreamCalls, 1);
  assert.doesNotMatch(await first.text(), /internal detail/);
});

test("unknown announcement IDs do not allocate quota objects", async () => {
  const namespace = createNamespace();
  const env = makeEnv({ namespace });
  const invalidId = "11111111-1111-4111-8111-111111111111";
  let postWrites = 0;
  const response = await handleGuestMetricsRequest(
    new Request(`https://metrics.example.test/v1/announcements/${invalidId}/guest-view`, {
      method: "POST",
      headers: { Origin: "https://edunivora.pages.dev" },
    }),
    env,
    {
      fetchImpl: async (_url, options) => {
        if (options.method === "GET") return new Response(null, { status: 404 });
        postWrites += 1;
        return new Response(null, { status: 204 });
      },
    },
  );

  assert.equal(response.status, 404);
  assert.equal(namespace.objects.size, 0);
  assert.equal(postWrites, 0);
});

test("misconfigured proxy is unavailable before it can reserve quota", async () => {
  const namespace = createNamespace();
  const env = makeEnv({ namespace, NEON_GUEST_METRICS_SECRET: "" });
  let upstreamCalls = 0;
  const response = await handleGuestMetricsRequest(metricRequest(), env, {
    fetchImpl: async (_url, options) => {
      if (options.method === "GET") {
        return new Response(JSON.stringify({ item: { id: announcementId } }), { status: 200 });
      }
      upstreamCalls += 1;
      return new Response(null, { status: 204 });
    },
  });

  assert.equal(response.status, 503);
  assert.equal(upstreamCalls, 0);
  assert.equal(namespace.objects.size, 0);
});

test("Worker never forwards client tracking headers or a request body", async () => {
  const env = makeEnv();
  let captured;
  const request = new Request(
    `https://metrics.example.test/v1/announcements/${announcementId}/guest-view`,
    {
      method: "POST",
      headers: {
        Origin: "https://edunivora.pages.dev",
        Cookie: "must-not-forward=1",
        "User-Agent": "must-not-forward",
      },
    },
  );

  const response = await handleGuestMetricsRequest(request, env, {
    fetchImpl: async (url, options) => {
      if (options.method === "GET") {
        return new Response(JSON.stringify({ item: { id: announcementId } }), { status: 200 });
      }
      captured = { url: url.toString(), options };
      return new Response(null, { status: 204 });
    },
  });

  assert.equal(response.status, 204);
  assert.equal(captured.url, `https://notices.example.test/v1/announcements/${announcementId}/guest-view`);
  assert.deepEqual(Object.keys(captured.options.headers), ["X-EduNivora-Worker-Secret", "Accept"]);
  assert.equal(captured.options.headers["X-EduNivora-Worker-Secret"], secret);
  assert.equal(captured.options.body, null);
});

test("only the configured public application origin is allowed", async () => {
  const response = await handleGuestMetricsRequest(
    metricRequest("view", "https://attacker.example.test"),
    makeEnv(),
  );
  assert.equal(response.status, 403);
});
