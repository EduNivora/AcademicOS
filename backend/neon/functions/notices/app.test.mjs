import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "./app.mjs";

const announcementId = "f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1";
const userId = "9c6d51f0-78b9-4b3e-8a3b-5cb08d0a29a0";

function createPool({ role = "user" } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, params = []) {
      calls.push({ sql, params });
      if (sql.includes('FROM neon_auth."user"')) {
        return { rowCount: 1, rows: [{ id: userId, name: "Test User", email: "test@example.com" }] };
      }
      if (sql.includes("INSERT INTO public.app_users")) {
        return { rowCount: 1, rows: [{ id: userId, display_name: "Test User", email: "test@example.com", role }] };
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
    { method: "POST" },
  );
  assert.equal(response.status, 204);
  const metricCall = pool.calls.find((call) =>
    call.sql.includes("announcement_guest_daily_metrics"),
  );
  assert.ok(metricCall);
  assert.equal(metricCall.params.length, 1);
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
