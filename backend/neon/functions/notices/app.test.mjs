import test from "node:test";
import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { createApp } from "./app.mjs";

const announcementId = "f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1";
const userId = "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0";

function createPool({ role = "user", failAudit = false } = {}) {
  const calls = [];
  const query = async (sql, params = []) => {
    calls.push({ sql, params });
    if (failAudit && sql.includes("INSERT INTO public.announcement_admin_audit")) {
      throw new Error("simulated audit insert failure");
    }
    if (sql === "BEGIN" || sql === "COMMIT" || sql === "ROLLBACK") {
      return { rowCount: null, rows: [] };
    }
    if (sql.includes('FROM neon_auth."user"')) {
      return { rowCount: 1, rows: [{ id: userId, name: "Test User", email: "test@example.com" }] };
    }
    if (sql.includes("INSERT INTO public.app_users")) {
      return { rowCount: 1, rows: [{ id: userId, display_name: "Test User", email: "test@example.com", role }] };
    }
    if (sql.includes("INSERT INTO public.announcement_deliveries")) {
      return { rowCount: 1, rows: [{ announcement_id: announcementId }] };
    }
    if (sql.includes("INSERT INTO public.announcement_reads")) {
      return { rowCount: 1, rows: [{ announcement_id: announcementId }] };
    }
    if (sql.includes("SELECT 1 FROM public.announcements")) {
      return { rowCount: 1, rows: [{ "?column?": 1 }] };
    }
    if (sql.includes("INSERT INTO public.announcement_guest_daily_metrics")) {
      return { rowCount: 1, rows: [{ views_count: "1", delivered_count: "1" }] };
    }
    if (sql.includes("INSERT INTO public.announcements")) {
      return { rowCount: 1, rows: [{ id: announcementId, title: "Notice", body: "Text", status: "draft" }] };
    }
    if (sql.includes("INSERT INTO public.announcement_admin_audit")) {
      return { rowCount: 1, rows: [] };
    }
    if (sql.includes("SELECT id, title, body, published_at")) {
      return { rowCount: 0, rows: [] };
    }
    if (sql.includes("SELECT 1")) return { rowCount: 1, rows: [{ "?column?": 1 }] };
    return { rowCount: 0, rows: [] };
  };
  return {
    calls,
    query,
    async connect() {
      return { query, release() {} };
    },
  };
}

function makeApp(options = {}) {
  return createApp({
    pool: options.pool ?? createPool(),
    verifyIdentity: options.verifyIdentity ?? (async (token) => token === "valid"
      ? { sub: userId, iss: "https://auth.example.test" }
      : null),
    allowedOrigins: ["https://app.example.test"],
    guestMetricsSecret: options.guestMetricsSecret ?? "test-worker-secret",
  });
}

test("health endpoint checks database and returns service status", async () => {
  const app = makeApp();
  const response = await app.request("/health");
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, service: "edunivora-notices-api" });
});

test("public announcement feed is available without authentication", async () => {
  const response = await makeApp().request("/v1/announcements");
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { items: [] });
});

test("public feed rejects malformed pagination cursor", async () => {
  const response = await makeApp().request("/v1/announcements?before=not-a-date");
  assert.equal(response.status, 400);
});

test("guest view stores aggregate metric without identity", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/guest-view`,
    { method: "POST", headers: { "X-EduNivora-Worker-Secret": "test-worker-secret" } },
  );
  assert.equal(response.status, 204);
  const metricCall = pool.calls.find((call) =>
    call.sql.includes("announcement_guest_daily_metrics"),
  );
  assert.ok(metricCall);
  assert.equal(metricCall.params.length, 1);
});

test("guest metrics reject direct calls without the Cloudflare gateway secret", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/guest-view`,
    { method: "POST" },
  );
  assert.equal(response.status, 403);
  assert.equal(pool.calls.length, 0);
});

test("registered delivery endpoint rejects requests without bearer token", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/delivered`,
    { method: "POST" },
  );
  assert.equal(response.status, 401);
  assert.equal(pool.calls.length, 0);
});


test("registered delivery receipt is linked to the authenticated account", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/delivered`,
    {
      method: "POST",
      headers: { Authorization: "Bearer valid" },
    },
  );
  assert.equal(response.status, 204);
  assert.ok(pool.calls.some((call) =>
    call.sql.includes("INSERT INTO public.announcement_deliveries"),
  ));
  assert.ok(pool.calls.some((call) =>
    call.sql.includes('FROM neon_auth."user"'),
  ));
});

test("registered read receipt is linked to the authenticated account", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/read`,
    {
      method: "POST",
      headers: { Authorization: "Bearer valid" },
    },
  );
  assert.equal(response.status, 204);
  assert.ok(pool.calls.some((call) =>
    call.sql.includes("INSERT INTO public.announcement_reads"),
  ));
});

test("non-admin accounts cannot create announcements", async () => {
  const pool = createPool({ role: "user" });
  const response = await makeApp({ pool }).request("/v1/admin/announcements", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Notice", body: "Message" }),
  });
  assert.equal(response.status, 403);
  assert.equal(pool.calls.some((call) => call.sql.includes("INSERT INTO public.announcements")), false);
});

test("administrator can create a draft announcement", async () => {
  const pool = createPool({ role: "admin" });
  const response = await makeApp({ pool }).request("/v1/admin/announcements", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Notice", body: "Plain text" }),
  });
  assert.equal(response.status, 201);
  assert.equal((await response.json()).item.status, "draft");
  assert.ok(pool.calls.some((call) => call.sql === "BEGIN"));
  assert.ok(pool.calls.some((call) => call.sql === "COMMIT"));
});

test("admin mutation rolls back when its audit insert fails", async () => {
  const pool = createPool({ role: "admin", failAudit: true });
  const response = await makeApp({ pool }).request("/v1/admin/announcements", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Notice", body: "Plain text" }),
  });
  assert.equal(response.status, 500);
  assert.ok(pool.calls.some((call) => call.sql === "BEGIN"));
  assert.ok(pool.calls.some((call) => call.sql.includes("INSERT INTO public.announcements")));
  assert.ok(pool.calls.some((call) => call.sql.includes("INSERT INTO public.announcement_admin_audit")));
  assert.ok(pool.calls.some((call) => call.sql === "ROLLBACK"));
  assert.equal(pool.calls.some((call) => call.sql === "COMMIT"), false);
});

test("announcement input is bounded and validated", async () => {
  const pool = createPool({ role: "admin" });
  const response = await makeApp({ pool }).request("/v1/admin/announcements", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify({ title: "   ", body: "message" }),
  });
  assert.equal(response.status, 400);
});


test("authenticated profile endpoint returns the server-owned role", async () => {
  const pool = createPool({ role: "admin" });
  const response = await makeApp({ pool }).request("/v1/me", {
    headers: { Authorization: "Bearer valid" },
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.user.role, "admin");
  assert.equal(body.user.email, "test@example.com");
});

test("profile endpoint rejects missing bearer credentials", async () => {
  const response = await makeApp({ pool: createPool() }).request("/v1/me");
  assert.equal(response.status, 401);
});

test("guest delivery is recorded as an aggregate event without identity", async () => {
  const pool = createPool();
  const response = await makeApp({ pool }).request(
    `/v1/announcements/${announcementId}/guest-delivered`,
    { method: "POST", headers: { "X-EduNivora-Worker-Secret": "test-worker-secret" } },
  );
  assert.equal(response.status, 204);
  const metricCall = pool.calls.find((call) =>
    call.sql.includes("announcement_guest_daily_metrics"),
  );
  assert.ok(metricCall);
  assert.equal(metricCall.params.length, 1);
});

test("administrator can list drafts and filter by status", async () => {
  const pool = createPool({ role: "admin" });
  const app = createApp({
    pool,
    verifyIdentity: async () => ({ sub: userId }),
  });
  const response = await app.request("/v1/admin/announcements?status=draft", {
    headers: { Authorization: "Bearer valid" },
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { items: [] });
});

test("CORS allows only an explicitly configured application origin", async () => {
  const app = makeApp();
  const allowed = await app.request("/v1/announcements", {
    headers: { Origin: "https://app.example.test" },
  });
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "https://app.example.test");

  const denied = await app.request("/v1/announcements", {
    headers: { Origin: "https://untrusted.example.test" },
  });
  assert.equal(denied.headers.get("Access-Control-Allow-Origin"), null);
});

test("wildcard CORS configuration does not authorize arbitrary origins", async () => {
  const app = createApp({
    pool: createPool(),
    verifyIdentity: async () => null,
    allowedOrigins: ["*"],
  });
  const response = await app.request("/v1/announcements", {
    headers: { Origin: "https://student.example.test" },
  });
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
});

test("protected endpoints return 401 when token verification infrastructure fails", async () => {
  const app = createApp({
    pool: createPool(),
    verifyIdentity: async () => { throw new Error("JWKS temporarily unavailable"); },
    allowedOrigins: ["https://app.example.test"],
  });
  const headers = { Authorization: "Bearer syntactically-present-token" };

  const receipt = await app.request(
    `/v1/announcements/${announcementId}/delivered`,
    { method: "POST", headers },
  );
  assert.equal(receipt.status, 401);

  const admin = await app.request("/v1/admin/announcements", { headers });
  assert.equal(admin.status, 401);
});


test("first-admin bootstrap SQL is guarded and uses a matching dollar-quote delimiter", async () => {
  const sql = await readFile(
    new URL("../../operations/bootstrap_first_admin.sql", import.meta.url),
    "utf8",
  );

  assert.ok(sql.includes("LOCK TABLE public.app_users IN EXCLUSIVE MODE;"));
  assert.ok(sql.includes("DO $bootstrap$"));
  assert.ok(sql.includes("END\n$bootstrap$;"));
  assert.ok(sql.includes("position('replace_with_' in target_email) > 0"));
  assert.ok(sql.includes('"emailVerified" IS TRUE'));
  assert.ok(sql.includes("banned IS NOT TRUE"));
  assert.ok(sql.includes("WHERE role = 'admin'"));
});
