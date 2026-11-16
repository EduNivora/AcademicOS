// Aggregate quota state only: no request, device, IP, or guest identifiers.
export const METRIC_KINDS = Object.freeze(["view", "delivered"]);

export function ensureQuotaSchema(sql) {
  sql.exec(`
    CREATE TABLE IF NOT EXISTS guest_metric_quotas (
      metric_kind TEXT PRIMARY KEY CHECK (metric_kind IN ('view', 'delivered')),
      used_count INTEGER NOT NULL CHECK (used_count >= 0)
    )
  `);
}

export function reserveDailyQuota(sql, metricKind, limit) {
  if (!METRIC_KINDS.includes(metricKind)) {
    throw new TypeError("Unsupported guest metric kind.");
  }
  if (!Number.isSafeInteger(limit) || limit < 1) {
    throw new RangeError("The daily metric quota must be a positive safe integer.");
  }

  // Durable Object SQLite executes this statement atomically. Concurrent callers
  // cannot pass the ceiling between a read and a separate write.
  const row = sql.exec(
    `INSERT INTO guest_metric_quotas (metric_kind, used_count)
     VALUES (?, 1)
     ON CONFLICT (metric_kind) DO UPDATE
       SET used_count = guest_metric_quotas.used_count + 1
       WHERE guest_metric_quotas.used_count < ?
     RETURNING used_count`,
    metricKind,
    limit,
  ).one();

  return row
    ? { allowed: true, used: Number(row.used_count) }
    : { allowed: false, used: limit };
}

export function utcMetricDate(now = new Date()) {
  const date = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(date.getTime())) {
    throw new TypeError("A valid date is required for UTC metric quotas.");
  }
  return date.toISOString().slice(0, 10);
}

export function nextUtcMidnight(now = new Date()) {
  const date = now instanceof Date ? new Date(now) : new Date(now);
  if (Number.isNaN(date.getTime())) {
    throw new TypeError("A valid date is required for UTC metric quotas.");
  }
  return Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate() + 1,
  );
}

export function quotaObjectName(announcementId, metricDate) {
  return `${announcementId.toLowerCase()}:${metricDate}`;
}
