import { timingSafeEqual } from "node:crypto";
import { Hono } from "hono";
import { cors } from "hono/cors";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonError(c, status, code, message) {
  return c.json({ error: { code, message } }, status);
}

function isUuid(value) {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

// Keep each admin state change and its audit record in one atomic transaction.
async function runAdminTransaction(pool, operation) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await operation(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (rollbackError) {
      console.error("EduNivora admin transaction rollback failed", rollbackError?.name ?? "UnknownError");
    }
    throw error;
  } finally {
    client.release();
  }
}

async function ensureProfile(pool, subject) {
  if (!isUuid(subject)) return null;

  const identity = await pool.query(
    `SELECT id, name, email
       FROM neon_auth."user"
      WHERE id = $1::uuid
        AND banned IS NOT TRUE`,
    [subject],
  );

  const authUser = identity.rows[0];
  if (!authUser) return null;

  const displayName =
    typeof authUser.name === "string" && authUser.name.trim()
      ? authUser.name.trim().slice(0, 120)
      : (authUser.email ?? "EduNivora user").slice(0, 120);

  const profile = await pool.query(
    `INSERT INTO public.app_users (auth_subject, display_name, email)
     VALUES ($1::uuid, $2, $3)
     ON CONFLICT (auth_subject) DO UPDATE
       SET display_name = EXCLUDED.display_name,
           email = EXCLUDED.email,
           updated_at = NOW()
     RETURNING id, display_name, email, role`,
    [subject, displayName, authUser.email],
  );

  return profile.rows[0] ?? null;
}

export function createApp({
  pool,
  verifyIdentity,
  allowedOrigins = [],
  guestMetricsProxySecret = null,
}) {
  if (!pool || typeof pool.query !== "function" || typeof pool.connect !== "function") {
    throw new TypeError("A PostgreSQL pool with query and connect methods is required");
  }
  if (typeof verifyIdentity !== "function") {
    throw new TypeError("A token verifier is required");
  }

  const requireGuestMetricsProxy = async (c, next) => {
    if (
      typeof guestMetricsProxySecret !== "string" ||
      Buffer.byteLength(guestMetricsProxySecret, "utf8") < 32
    ) {
      return jsonError(c, 503, "metrics_unavailable", "Guest metrics are temporarily unavailable.");
    }

    const supplied = c.req.header("X-EduNivora-Worker-Secret") ?? "";
    const expectedBytes = Buffer.from(guestMetricsProxySecret, "utf8");
    const suppliedBytes = Buffer.from(supplied, "utf8");
    const matches = suppliedBytes.length === expectedBytes.length &&
      timingSafeEqual(suppliedBytes, expectedBytes);
    if (!matches) {
      return jsonError(c, 403, "forbidden", "Worker authorization is required.");
    }
    await next();
  };

  const app = new Hono();

  app.use(
    "*",
    cors({
      origin: (origin) =>
        origin && allowedOrigins.includes(origin) ? origin : "",
      allowMethods: ["GET", "POST", "PATCH", "OPTIONS"],
      allowHeaders: ["Content-Type", "Authorization"],
      maxAge: 600,
    }),
  );

  app.onError((error, c) => {
    // Do not return SQL, tokens, or internal exception details to clients.
    console.error("EduNivora API request failed", error?.name ?? "UnknownError");
    return jsonError(c, 500, "internal_error", "An unexpected error occurred.");
  });

  app.get("/health", async (c) => {
    await pool.query("SELECT 1");
    return c.json({ ok: true, service: "edunivora-notices-api" });
  });

  app.get("/v1/announcements", async (c) => {
    const requestedLimit = Number.parseInt(c.req.query("limit") ?? "20", 10);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(requestedLimit, 1), 50)
      : 20;
    const before = c.req.query("before") ?? null;
    if (before !== null && Number.isNaN(Date.parse(before))) {
      return jsonError(c, 400, "invalid_cursor", "The before cursor is invalid.");
    }

    const result = await pool.query(
      `SELECT id, title, body, published_at
         FROM public.announcements
        WHERE status = 'published'
          AND published_at IS NOT NULL
          AND ($2::timestamptz IS NULL OR published_at < $2::timestamptz)
        ORDER BY published_at DESC, id DESC
        LIMIT $1`,
      [limit, before],
    );

    return c.json({ items: result.rows });
  });

  app.get("/v1/announcements/:id", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }

    const result = await pool.query(
      `SELECT id, title, body, published_at
         FROM public.announcements
        WHERE id = $1::uuid
          AND status = 'published'
          AND published_at IS NOT NULL
        LIMIT 1`,
      [announcementId],
    );
    if (result.rowCount === 0) {
      return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
    }
    return c.json({ item: result.rows[0] });
  });

  app.get("/v1/me", async (c) => {
    const authorization = c.req.header("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return jsonError(c, 401, "unauthorized", "Sign-in is required.");

    let identity;
    try {
      identity = await verifyIdentity(token);
    } catch {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    if (!identity?.sub || !isUuid(identity.sub)) {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }

    const profile = await ensureProfile(pool, identity.sub);
    if (!profile) {
      return jsonError(c, 401, "account_unavailable", "Account is unavailable.");
    }
    return c.json({
      user: {
        id: profile.id,
        displayName: profile.display_name,
        email: profile.email,
        role: profile.role,
      },
    });
  });

  // Guest analytics store aggregate counters only. No guest id, IP address,
  // device fingerprint, or cross-session identifier is persisted.
  app.post("/v1/announcements/:id/guest-view", requireGuestMetricsProxy, async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }

    const result = await pool.query(
      `INSERT INTO public.announcement_guest_daily_metrics
         (announcement_id, metric_date, views_count)
       SELECT id, (NOW() AT TIME ZONE 'UTC')::date, 1
         FROM public.announcements
        WHERE id = $1::uuid AND status = 'published'
       ON CONFLICT (announcement_id, metric_date)
       DO UPDATE SET views_count =
         public.announcement_guest_daily_metrics.views_count + 1
       RETURNING views_count`,
      [announcementId],
    );

    if (result.rowCount === 0) {
      return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
    }
    return c.body(null, 204);
  });

  app.post("/v1/announcements/:id/guest-delivered", requireGuestMetricsProxy, async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }

    const result = await pool.query(
      `INSERT INTO public.announcement_guest_daily_metrics
         (announcement_id, metric_date, delivered_count)
       SELECT id, (NOW() AT TIME ZONE 'UTC')::date, 1
         FROM public.announcements
        WHERE id = $1::uuid AND status = 'published'
       ON CONFLICT (announcement_id, metric_date)
       DO UPDATE SET delivered_count =
         public.announcement_guest_daily_metrics.delivered_count + 1
       RETURNING delivered_count`,
      [announcementId],
    );

    if (result.rowCount === 0) {
      return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
    }
    return c.body(null, 204);
  });

  app.use("/v1/announcements/:id/delivered", async (c, next) => {
    const authorization = c.req.header("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return jsonError(c, 401, "unauthorized", "Sign-in is required.");

    let identity;
    try {
      identity = await verifyIdentity(token);
    } catch {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    if (!identity?.sub || !isUuid(identity.sub)) {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    const profile = await ensureProfile(pool, identity.sub);
    if (!profile) return jsonError(c, 401, "account_unavailable", "Account is unavailable.");
    c.set("profile", profile);
    await next();
  });

  app.use("/v1/announcements/:id/read", async (c, next) => {
    const authorization = c.req.header("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return jsonError(c, 401, "unauthorized", "Sign-in is required.");

    let identity;
    try {
      identity = await verifyIdentity(token);
    } catch {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    if (!identity?.sub || !isUuid(identity.sub)) {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    const profile = await ensureProfile(pool, identity.sub);
    if (!profile) return jsonError(c, 401, "account_unavailable", "Account is unavailable.");
    c.set("profile", profile);
    await next();
  });

  app.post("/v1/announcements/:id/delivered", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const profile = c.get("profile");
    const result = await pool.query(
      `INSERT INTO public.announcement_deliveries (announcement_id, user_id)
       SELECT id, $2::uuid
         FROM public.announcements
        WHERE id = $1::uuid AND status = 'published'
       ON CONFLICT (announcement_id, user_id) DO NOTHING
       RETURNING announcement_id`,
      [announcementId, profile.id],
    );
    if (result.rowCount === 0) {
      const exists = await pool.query(
        "SELECT 1 FROM public.announcements WHERE id = $1::uuid AND status = 'published'",
        [announcementId],
      );
      if (exists.rowCount === 0) {
        return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
      }
    }
    return c.body(null, 204);
  });

  app.post("/v1/announcements/:id/read", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const profile = c.get("profile");
    const result = await pool.query(
      `INSERT INTO public.announcement_reads (announcement_id, user_id)
       SELECT id, $2::uuid
         FROM public.announcements
        WHERE id = $1::uuid AND status = 'published'
       ON CONFLICT (announcement_id, user_id) DO NOTHING
       RETURNING announcement_id`,
      [announcementId, profile.id],
    );
    if (result.rowCount === 0) {
      const exists = await pool.query(
        "SELECT 1 FROM public.announcements WHERE id = $1::uuid AND status = 'published'",
        [announcementId],
      );
      if (exists.rowCount === 0) {
        return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
      }
    }
    return c.body(null, 204);
  });

  const requireAdmin = async (c, next) => {
    const authorization = c.req.header("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return jsonError(c, 401, "unauthorized", "Sign-in is required.");

    let identity;
    try {
      identity = await verifyIdentity(token);
    } catch {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    if (!identity?.sub || !isUuid(identity.sub)) {
      return jsonError(c, 401, "invalid_token", "The session is invalid or expired.");
    }
    const profile = await ensureProfile(pool, identity.sub);
    if (!profile) return jsonError(c, 401, "account_unavailable", "Account is unavailable.");
    if (profile.role !== "admin") {
      return jsonError(c, 403, "forbidden", "Administrator access is required.");
    }
    c.set("profile", profile);
    await next();
  };

  app.use("/v1/admin/*", requireAdmin);

  // Admin list is filtered server-side; clients cannot supply authorization roles.
  app.get("/v1/admin/announcements", async (c) => {
    const requestedLimit = Number.parseInt(c.req.query("limit") ?? "50", 10);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(requestedLimit, 1), 100)
      : 50;
    const status = c.req.query("status") ?? null;
    if (status !== null && !["draft", "published", "archived"].includes(status)) {
      return jsonError(c, 400, "invalid_status", "Unsupported announcement status.");
    }

    const result = await pool.query(
      `SELECT id, title, body, status, published_at, created_at, updated_at
         FROM public.announcements
        WHERE ($2::text IS NULL OR status = $2)
        ORDER BY created_at DESC, id DESC
        LIMIT $1`,
      [limit, status],
    );
    return c.json({ items: result.rows });
  });

  app.post("/v1/admin/announcements", async (c) => {
    const input = await c.req.json().catch(() => null);
    const title = typeof input?.title === "string" ? input.title.trim() : "";
    const body = typeof input?.body === "string" ? input.body.trim() : "";
    if (!title || title.length > 180 || !body || body.length > 10000) {
      return jsonError(c, 400, "invalid_announcement", "Title and plain-text body are required.");
    }

    const profile = c.get("profile");
    const announcement = await runAdminTransaction(pool, async (client) => {
      const created = await client.query(
        `INSERT INTO public.announcements (title, body, created_by)
         VALUES ($1, $2, $3::uuid)
         RETURNING id, title, body, status, created_at`,
        [title, body, profile.id],
      );
      const item = created.rows[0];
      await client.query(
        `INSERT INTO public.announcement_admin_audit
           (actor_user_id, announcement_id, action)
         VALUES ($1::uuid, $2::uuid, 'create')`,
        [profile.id, item.id],
      );
      return item;
    });
    return c.json({ item: announcement }, 201);
  });

  app.patch("/v1/admin/announcements/:id", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const input = await c.req.json().catch(() => null);
    const title = typeof input?.title === "string" ? input.title.trim() : "";
    const body = typeof input?.body === "string" ? input.body.trim() : "";
    if (!title || title.length > 180 || !body || body.length > 10000) {
      return jsonError(c, 400, "invalid_announcement", "Title and plain-text body are required.");
    }
    const profile = c.get("profile");
    const item = await runAdminTransaction(pool, async (client) => {
      const updated = await client.query(
        `UPDATE public.announcements
            SET title = $2, body = $3, updated_at = NOW()
          WHERE id = $1::uuid AND status = 'draft'
          RETURNING id, title, body, status, updated_at`,
        [announcementId, title, body],
      );
      if (updated.rowCount === 0) return null;
      await client.query(
        `INSERT INTO public.announcement_admin_audit
           (actor_user_id, announcement_id, action)
         VALUES ($1::uuid, $2::uuid, 'update')`,
        [profile.id, announcementId],
      );
      return updated.rows[0];
    });
    if (!item) return jsonError(c, 404, "draft_not_found", "Editable draft not found.");
    return c.json({ item });
  });

  app.post("/v1/admin/announcements/:id/publish", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const profile = c.get("profile");
    const item = await runAdminTransaction(pool, async (client) => {
      const published = await client.query(
        `UPDATE public.announcements
            SET status = 'published',
                published_at = NOW(),
                updated_at = NOW()
          WHERE id = $1::uuid AND status = 'draft'
          RETURNING id, title, body, status, published_at`,
        [announcementId],
      );
      if (published.rowCount === 0) return null;
      await client.query(
        `INSERT INTO public.announcement_admin_audit
           (actor_user_id, announcement_id, action)
         VALUES ($1::uuid, $2::uuid, 'publish')`,
        [profile.id, announcementId],
      );
      return published.rows[0];
    });
    if (!item) return jsonError(c, 404, "draft_not_found", "Publishable draft not found.");
    return c.json({ item });
  });

  app.post("/v1/admin/announcements/:id/archive", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const profile = c.get("profile");
    const item = await runAdminTransaction(pool, async (client) => {
      const archived = await client.query(
        `UPDATE public.announcements
            SET status = 'archived', updated_at = NOW()
          WHERE id = $1::uuid AND status <> 'archived'
          RETURNING id, title, status, updated_at`,
        [announcementId],
      );
      if (archived.rowCount === 0) return null;
      await client.query(
        `INSERT INTO public.announcement_admin_audit
           (actor_user_id, announcement_id, action)
         VALUES ($1::uuid, $2::uuid, 'archive')`,
        [profile.id, announcementId],
      );
      return archived.rows[0];
    });
    if (!item) return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
    return c.json({ item });
  });

  app.get("/v1/admin/announcements/:id/report", async (c) => {
    const announcementId = c.req.param("id");
    if (!isUuid(announcementId)) {
      return jsonError(c, 400, "invalid_announcement_id", "Invalid announcement id.");
    }
    const profile = c.get("profile");
    const report = await pool.query(
      `SELECT a.id, a.title, a.status, a.published_at,
              (SELECT count(*)::bigint FROM public.announcement_deliveries d
                WHERE d.announcement_id = a.id) AS registered_deliveries,
              (SELECT count(*)::bigint FROM public.announcement_reads r
                WHERE r.announcement_id = a.id) AS registered_reads,
              COALESCE((SELECT sum(m.delivered_count)
                          FROM public.announcement_guest_daily_metrics m
                         WHERE m.announcement_id = a.id), 0)::bigint AS guest_deliveries,
              COALESCE((SELECT sum(m.views_count)
                          FROM public.announcement_guest_daily_metrics m
                         WHERE m.announcement_id = a.id), 0)::bigint AS guest_views
         FROM public.announcements a
        WHERE a.id = $1::uuid`,
      [announcementId],
    );
    if (report.rowCount === 0) {
      return jsonError(c, 404, "announcement_not_found", "Announcement not found.");
    }
    await pool.query(
      `INSERT INTO public.announcement_admin_audit
         (actor_user_id, announcement_id, action)
       VALUES ($1::uuid, $2::uuid, 'view_report')`,
      [profile.id, announcementId],
    );
    return c.json({ report: report.rows[0] });
  });

  return app;
}
