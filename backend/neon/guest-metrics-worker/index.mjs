import { DurableObject } from "cloudflare:workers";
import { ensureQuotaSchema, reserveDailyQuota } from "./quota.mjs";
import { handleGuestMetricsRequest } from "./worker.mjs";

export class AnnouncementMetricQuota extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    // Ensure the SQLite schema exists before this object handles requests.
    this.ctx.blockConcurrencyWhile(async () => {
      ensureQuotaSchema(this.ctx.storage.sql);
    });
  }

  async reserve(metricKind, limit, expiresAt) {
    const reservation = reserveDailyQuota(
      this.ctx.storage.sql,
      metricKind,
      limit,
    );
    if (reservation.allowed && (await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(expiresAt);
    }
    return reservation;
  }

  async alarm() {
    // The object name includes the UTC date, so after midnight it is never
    // selected again. Delete the aggregate budget state after its day expires.
    await this.ctx.storage.deleteAll();
  }
}

export default {
  fetch(request, env) {
    return handleGuestMetricsRequest(request, env);
  },
};
