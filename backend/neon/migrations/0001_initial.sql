-- 0001: Minimal EduNivora cloud identity and public-notice schema.
-- Run only after Neon Auth has provisioned the neon_auth schema.
-- Academic records and files are intentionally excluded.

CREATE TABLE IF NOT EXISTS public.app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_subject TEXT NOT NULL UNIQUE,
  display_name VARCHAR(120) NOT NULL,
  email VARCHAR(254),
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS app_users_email_lower_unique
  ON public.app_users (LOWER(email))
  WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(180) NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  published_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (length(trim(title)) > 0),
  CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS announcements_published_idx
  ON public.announcements (published_at DESC)
  WHERE status = 'published';

CREATE TABLE IF NOT EXISTS public.announcement_reads (
  announcement_id UUID NOT NULL
    REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL
    REFERENCES public.app_users(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (announcement_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.announcement_guest_daily_metrics (
  announcement_id UUID NOT NULL
    REFERENCES public.announcements(id) ON DELETE CASCADE,
  metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
  views_count BIGINT NOT NULL DEFAULT 0 CHECK (views_count >= 0),
  PRIMARY KEY (announcement_id, metric_date)
);
