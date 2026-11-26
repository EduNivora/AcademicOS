-- 0003: Durable per-account AI request quotas.
-- Stores counters only and never store prompts, responses, academic context, or IP addresses.

CREATE TABLE IF NOT EXISTS public.ai_usage_windows (
  user_id UUID NOT NULL
    REFERENCES neon_auth."user"(id) ON DELETE CASCADE,
  window_kind TEXT NOT NULL
    CHECK (window_kind IN ('minute', 'day')),
  window_start TIMESTAMPTZ NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0
    CHECK (request_count >= 0),
  PRIMARY KEY (user_id, window_kind, window_start)
);

-- Supports pruning old windows for the account making a request.
CREATE INDEX IF NOT EXISTS ai_usage_windows_account_expiry_idx
  ON public.ai_usage_windows (user_id, window_start);

-- Also supports a future scheduled global cleanup for inactive accounts.
CREATE INDEX IF NOT EXISTS ai_usage_windows_expiry_idx
  ON public.ai_usage_windows (window_start);
