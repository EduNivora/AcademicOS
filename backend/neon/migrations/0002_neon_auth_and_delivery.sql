-- 0002: Link profiles to Neon Managed Auth and record delivery.
-- Neon Auth owns the neon_auth schema and its user/session lifecycle.
-- This app-owned table stores only a small profile/role projection.

ALTER TABLE public.app_users
  ALTER COLUMN auth_subject TYPE UUID USING auth_subject::uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_users_auth_subject_fk'
      AND conrelid = 'public.app_users'::regclass
  ) THEN
    ALTER TABLE public.app_users
      ADD CONSTRAINT app_users_auth_subject_fk
      FOREIGN KEY (auth_subject)
      REFERENCES neon_auth."user"(id)
      ON DELETE CASCADE;
  END IF;
END
$$;

ALTER TABLE public.announcement_guest_daily_metrics
  ADD COLUMN IF NOT EXISTS delivered_count BIGINT NOT NULL DEFAULT 0
  CHECK (delivered_count >= 0);

CREATE TABLE IF NOT EXISTS public.announcement_deliveries (
  announcement_id UUID NOT NULL
    REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL
    REFERENCES public.app_users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (announcement_id, user_id)
);

CREATE INDEX IF NOT EXISTS announcement_deliveries_user_idx
  ON public.announcement_deliveries (user_id, delivered_at DESC);

CREATE TABLE IF NOT EXISTS public.announcement_admin_audit (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id UUID
    REFERENCES public.app_users(id) ON DELETE SET NULL,
  announcement_id UUID
    REFERENCES public.announcements(id) ON DELETE SET NULL,
  action TEXT NOT NULL
    CHECK (action IN ('create', 'update', 'publish', 'archive', 'view_report')),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Preserve audit events if an account is deleted, while anonymizing the actor.
ALTER TABLE public.announcement_admin_audit
  ALTER COLUMN actor_user_id DROP NOT NULL;

ALTER TABLE public.announcement_admin_audit
  DROP CONSTRAINT IF EXISTS announcement_admin_audit_actor_user_id_fkey;

ALTER TABLE public.announcement_admin_audit
  ADD CONSTRAINT announcement_admin_audit_actor_user_id_fkey
  FOREIGN KEY (actor_user_id)
  REFERENCES public.app_users(id)
  ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS announcement_admin_audit_time_idx
  ON public.announcement_admin_audit (occurred_at DESC);
