import test from "node:test";
import assert from "node:assert/strict";
import { createAiHandler } from "./app.mjs";
const token = "valid";
const identity = { sub: "00000000-0000-4000-8000-000000000123" };
const createPool = ({ minuteExceeded = false, dayExceeded = false, unavailable = false } = {}) => {
  const calls = [];
  const pool = {
    calls,
    async query(sql) {
      if (unavailable) throw new Error("database unavailable");
      if (sql === "SELECT 1") return { rows: [{ "?column?": 1 }] };
      throw new Error("unexpected pool query");
    },
    async connect() {
      if (unavailable) throw new Error("database unavailable");
      return {
        async query(sql) {
          calls.push(sql);
          if (sql === "BEGIN" || sql === "COMMIT" || sql === "ROLLBACK") return { rows: [] };
          if (sql.includes("'minute'")) return { rows: minuteExceeded ? [] : [{ request_count: 1 }] };
          if (sql.includes("'day'")) return { rows: dayExceeded ? [] : [{ request_count: 1 }] };
          throw new Error("unexpected quota SQL");
        },
        release() {},
      };
    },
  };
  return pool;
};
const make = ({ apiKey = "test-api-key-not-real", fetchImpl, verifyIdentity, pool } = {}) =>
  createAiHandler({
    verifyIdentity: verifyIdentity ?? (async (value) => value === token ? identity : null),
    apiKey,
    pool: pool ?? createPool(),
    allowedOrigins: ["https://app.example.test"],
    fetchImpl: fetchImpl ?? (async () => Response.json({
      steps: [{ type: "model_output", content: [{ type: "text", text: "جواب اختباري" }] }],
      usage: { total_tokens: 10 },
    })),
  });
const request = (message, { bearer = token, context, origin } = {}) =>
  new Request("https://unit.test/v1/chat", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(bearer ? { Authorization: "Bearer " + bearer } : {}),
      ...(origin ? { Origin: origin } : {}),
    },
    body: JSON.stringify({ message, ...(context === undefined ? {} : { context }) }),
  });

test("health route", async () => {
  const response = await make()(new Request("https://unit.test/health"));
  assert.equal(response.status, 200);
  const health = await response.json();
  assert.equal(health.service, "edunivora-ai");
  assert.equal(health.configured, true);
  assert.equal(health.quotaStore, "ready");
});
test("authentication is required", async () => {
  assert.equal((await make()(request("سؤال", { bearer: null }))).status, 401);
});
test("invalid bearer token is rejected", async () => {
  assert.equal((await make()(request("سؤال", { bearer: "bad" }))).status, 401);
});
test("valid request calls Gemini Interactions API", async () => {
  let sent;
  const response = await make({ fetchImpl: async (url, options) => {
    sent = { url, options };
    return Response.json({ steps: [{ type: "model_output", content: [{ type: "text", text: "شرح." }] }] });
  }})(request("اشرح"));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).answer, "شرح.");
  assert.equal(sent.url, "https://generativelanguage.googleapis.com/v1beta/interactions");
  assert.equal(JSON.parse(sent.options.body).model, "gemini-3.8-flash");
  assert.equal(JSON.parse(sent.options.body).store, false);
});
test("academic context is bounded and forwarded separately", async () => {
  let payload;
  const response = await make({ fetchImpl: async (_url, options) => {
    payload = JSON.parse(options.body);
    return Response.json({ steps: [{ type: "model_output", content: [{ type: "text", text: "تمام" }] }] });
  }})(request("ما أولويتي؟", { context: "لدي اختبار غدًا" }));
  assert.equal(response.status, 200);
  assert.match(payload.input[0].content, /بيانات أكاديمية/);
  assert.equal(payload.input[1].content, "ما أولويتي؟");
});
test("message size is validated before provider call", async () => {
  let called = false;
  const response = await make({ fetchImpl: async () => { called = true; return Response.json({}); } })(request("x".repeat(12001)));
  assert.equal(response.status, 400);
  assert.equal(called, false);
});
test("provider diagnostics are not exposed", async () => {
  const response = await make({ fetchImpl: async () => new Response("secret detail", { status: 403 }) })(request("سؤال"));
  assert.equal(response.status, 503);
  assert.doesNotMatch(await response.text(), /secret detail/);
});
test("missing Gemini key fails closed", async () => {
  const response = await make({ apiKey: "" })(request("سؤال"));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "ai_not_configured");
});
test("CORS only allows configured origins", async () => {
  const handler = make();
  const allowed = await handler(new Request("https://unit.test/health", { headers: { Origin: "https://app.example.test" } }));
  const denied = await handler(new Request("https://unit.test/health", { headers: { Origin: "https://evil.test" } }));
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "https://app.example.test");
  assert.equal(denied.headers.get("Access-Control-Allow-Origin"), null);
});

test("health reports an unset Gemini key without exposing the key", async () => {
  const response = await make({ apiKey: "" })(new Request("https://unit.test/health"));
  const health = await response.json();
  assert.equal(response.status, 200);
  assert.equal(health.configured, false);
  assert.equal(JSON.stringify(health).includes("test-api-key"), false);
});

const scheduleRequest = ({ image = "dGVzdA==", mimeType = "image/png", bearer = token } = {}) =>
  new Request("https://unit.test/v1/schedule/parse", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(bearer ? { Authorization: "Bearer " + bearer } : {}),
    },
    body: JSON.stringify({ image, mimeType }),
  });

test("schedule image parsing forwards a multimodal image and validates extracted rows", async () => {
  let payload;
  const handler = make({ fetchImpl: async (_url, options) => {
    payload = JSON.parse(options.body);
    return Response.json({
      steps: [{ type: "model_output", content: [{
        type: "text",
        text: JSON.stringify({ entries: [{
          day: "الأحد", course_name: "أمن الشبكات", start_time: "08:00", end_time: "09:30", location: "قاعة 2",
        }] }),
      }] }],
    });
  }});
  const response = await handler(scheduleRequest());
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).entries, [{
    day: "الأحد", course_name: "أمن الشبكات", start_time: "08:00", end_time: "09:30", location: "قاعة 2",
  }]);
  assert.equal(payload.input[1].type, "image");
  assert.equal(payload.input[1].mime_type, "image/png");
  assert.equal(payload.input[1].data, "dGVzdA==");
  assert.equal(payload.store, false);
});

test("schedule image parsing rejects unsupported image types before Gemini", async () => {
  let called = false;
  const handler = make({ fetchImpl: async () => { called = true; return Response.json({}); } });
  const response = await handler(scheduleRequest({ mimeType: "application/pdf" }));
  assert.equal(response.status, 400);
  assert.equal(called, false);
});

test("schedule image parsing requires authentication", async () => {
  const response = await make()(scheduleRequest({ bearer: null }));
  assert.equal(response.status, 401);
});


test("AI quota reserves minute and daily counters atomically before provider calls", async () => {
  const pool = createPool();
  let providerCalled = false;
  const response = await make({
    pool,
    fetchImpl: async () => {
      providerCalled = true;
      return Response.json({ steps: [{ type: "model_output", content: [{ type: "text", text: "تمام" }] }] });
    },
  })(request("اشرح"));
  assert.equal(response.status, 200);
  assert.equal(providerCalled, true);
  assert.equal(pool.calls[0], "BEGIN");
  assert.ok(pool.calls.some((sql) => sql.includes("'minute'")));
  assert.ok(pool.calls.some((sql) => sql.includes("'day'")));
  assert.equal(pool.calls.at(-1), "COMMIT");
});

test("minute quota returns 429 and does not call Gemini", async () => {
  const pool = createPool({ minuteExceeded: true });
  let providerCalled = false;
  const response = await make({
    pool,
    fetchImpl: async () => { providerCalled = true; return Response.json({}); },
  })(request("اشرح"));
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error.code, "ai_quota_exceeded");
  assert.equal(response.headers.get("Retry-After"), "60");
  assert.equal(providerCalled, false);
  assert.equal(pool.calls.at(-1), "ROLLBACK");
});

test("daily quota rolls back minute reservation and does not call Gemini", async () => {
  const pool = createPool({ dayExceeded: true });
  let providerCalled = false;
  const response = await make({
    pool,
    fetchImpl: async () => { providerCalled = true; return Response.json({}); },
  })(request("اشرح"));
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error.code, "ai_quota_exceeded");
  assert.ok(Number(response.headers.get("Retry-After")) > 0);
  assert.equal(providerCalled, false);
  assert.equal(pool.calls.at(-1), "ROLLBACK");
});

test("quota store failure fails closed without calling Gemini", async () => {
  let providerCalled = false;
  const response = await make({
    pool: createPool({ unavailable: true }),
    fetchImpl: async () => { providerCalled = true; return Response.json({}); },
  })(request("اشرح"));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "ai_quota_unavailable");
  assert.equal(providerCalled, false);
});


test("health fails when the quota database is unavailable", async () => {
  const response = await make({ pool: createPool({ unavailable: true }) })(
    new Request("https://unit.test/health"),
  );
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "ai_quota_store_unavailable");
});
