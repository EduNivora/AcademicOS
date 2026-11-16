import { env } from "cloudflare:workers";
import { runInDurableObject } from "cloudflare:test";
import { describe, expect, it } from "vitest";

const announcementId = "f7d0b52a-4a36-4fd9-9ad5-8cbbece8f3d1";
const nextUtcMidnight = Date.parse("2026-11-17T00:00:00.000Z");

function quotaFor(name) {
  const id = env.ANNOUNCEMENT_METRIC_QUOTAS.idFromName(name);
  return env.ANNOUNCEMENT_METRIC_QUOTAS.get(id);
}

describe("AnnouncementMetricQuota SQLite Durable Object", () => {
  it("accepts events below the exact limit and rejects above it", async () => {
    const quota = quotaFor(`${announcementId}:2026-11-16:exact-limit`);
    const results = await Promise.all([
      quota.reserve("view", 3, nextUtcMidnight),
      quota.reserve("view", 3, nextUtcMidnight),
      quota.reserve("view", 3, nextUtcMidnight),
      quota.reserve("view", 3, nextUtcMidnight),
    ]);

    expect(results.filter((result) => result.allowed)).toHaveLength(3);
    expect(results.filter((result) => !result.allowed)).toHaveLength(1);
    expect(results.map((result) => result.used).sort((a, b) => a - b)).toEqual([
      1, 2, 3, 3,
    ]);
  });

  it("enforces a global cap across concurrent requests and Worker stubs", async () => {
    const name = `${announcementId}:2026-11-16:global-burst`;
    const firstWorkerStub = quotaFor(name);
    const secondWorkerStub = quotaFor(name);

    const results = await Promise.all(
      Array.from({ length: 100 }, (_, index) =>
        (index % 2 === 0 ? firstWorkerStub : secondWorkerStub).reserve(
          "delivered",
          11,
          nextUtcMidnight,
        ),
      ),
    );

    expect(results.filter((result) => result.allowed)).toHaveLength(11);
    expect(results.filter((result) => !result.allowed)).toHaveLength(89);
    expect(Math.max(...results.map((result) => result.used))).toBe(11);
  });

  it("keeps views and delivery quotas independent within one announcement-day object", async () => {
    const quota = quotaFor(`${announcementId}:2026-11-16:separate-kinds`);

    const view = await quota.reserve("view", 1, nextUtcMidnight);
    const delivered = await quota.reserve("delivered", 1, nextUtcMidnight);
    const viewAgain = await quota.reserve("view", 1, nextUtcMidnight);
    const deliveredAgain = await quota.reserve("delivered", 1, nextUtcMidnight);

    expect(view.allowed).toBe(true);
    expect(delivered.allowed).toBe(true);
    expect(viewAgain.allowed).toBe(false);
    expect(deliveredAgain.allowed).toBe(false);
  });

  it("isolates budgets by announcement and UTC date", async () => {
    const secondAnnouncement = "11111111-1111-4111-8111-111111111111";
    const dayOne = quotaFor(`${announcementId}:2026-11-16`);
    const dayTwo = quotaFor(`${announcementId}:2026-11-17`);
    const otherAnnouncement = quotaFor(`${secondAnnouncement}:2026-11-16`);

    expect((await dayOne.reserve("view", 1, nextUtcMidnight)).allowed).toBe(true);
    expect((await dayOne.reserve("view", 1, nextUtcMidnight)).allowed).toBe(false);
    expect((await dayTwo.reserve("view", 1, nextUtcMidnight + 86400000)).allowed).toBe(true);
    expect((await otherAnnouncement.reserve("view", 1, nextUtcMidnight)).allowed).toBe(true);
  });

  it("persists only aggregate metric kinds and counts", async () => {
    const name = `${announcementId}:2026-11-16:privacy-schema`;
    const quota = quotaFor(name);
    await quota.reserve("view", 2, nextUtcMidnight);
    await quota.reserve("delivered", 2, nextUtcMidnight);

    await runInDurableObject(quota, async (_instance, state) => {
      const columns = state.storage.sql
        .exec("PRAGMA table_info(guest_metric_quotas)")
        .toArray()
        .map((column) => column.name);
      const rows = state.storage.sql
        .exec("SELECT metric_kind, used_count FROM guest_metric_quotas ORDER BY metric_kind")
        .toArray();

      expect(columns).toEqual(["metric_kind", "used_count"]);
      expect(rows).toEqual([
        { metric_kind: "delivered", used_count: 1 },
        { metric_kind: "view", used_count: 1 },
      ]);
    });
  });
});
