import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const migration = async (name) => readFile(new URL(name, import.meta.url), "utf8");

test("Release 1 migrations are ordered and contain only the approved cloud data model", async () => {
  const initial = await migration("./0001_initial.sql");
  const auth = await migration("./0002_neon_auth_and_delivery.sql");
  assert.match(initial, /CREATE TABLE IF NOT EXISTS public\.app_users/i);
  assert.match(initial, /CREATE TABLE IF NOT EXISTS public\.announcements/i);
  assert.match(initial, /CREATE TABLE IF NOT EXISTS public\.announcement_reads/i);
  assert.match(initial, /CREATE TABLE IF NOT EXISTS public\.announcement_guest_daily_metrics/i);
  assert.match(auth, /REFERENCES neon_auth\.\"user\"\(id\)/i);
  assert.match(auth, /CREATE TABLE IF NOT EXISTS public\.announcement_deliveries/i);
  assert.match(auth, /CREATE TABLE IF NOT EXISTS public\.announcement_admin_audit/i);
  assert.match(auth, /ON DELETE SET NULL/i);
  const combined = initial + auth;
  for (const forbidden of [
    "courses", "academic_terms", "schedules", "tasks", "exams", "grades",
    "notes", "study_plans", "course_materials", "attachments",
  ]) {
    assert.doesNotMatch(combined, new RegExp(`CREATE\\s+TABLE[^;]*\\b${forbidden}\\b`, "i"));
  }
  assert.match(initial, /PRIMARY KEY \(announcement_id, metric_date\)/i);
  assert.match(auth, /PRIMARY KEY \(announcement_id, user_id\)/i);
  assert.match(auth, /PRIMARY KEY \(announcement_id, user_id\)/i);
});
