-- ====================================================================
-- INRIDE USER ACTIVITY, PRESENCE & USAGE METRICS SCHEMA MIGRATION
-- Adds fields & helper RPCs to track:
-- 1. Real-time active presence (is_app_open, last_seen_at)
-- 2. Session open count (app_open_count)
-- 3. Total time spent in app (total_app_time_seconds)
-- 4. Last opened timestamp (last_opened_at)
-- ====================================================================

-- 1. Extend public.users table with presence & usage tracking columns
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_app_open BOOLEAN DEFAULT FALSE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS last_opened_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS app_open_count INT DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS total_app_time_seconds BIGINT DEFAULT 0;

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_users_is_app_open ON public.users(is_app_open);
CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON public.users(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at DESC);

-- 2. RPC: Record User App Open
CREATE OR REPLACE FUNCTION public.record_user_app_open(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET 
    is_app_open = TRUE,
    last_opened_at = NOW(),
    last_seen_at = NOW(),
    app_open_count = COALESCE(app_open_count, 0) + 1,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- If user is a driver, ensure drivers table is also synchronized
  UPDATE public.drivers
  SET is_online = TRUE
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RPC: Record User Heartbeat (every ~40 seconds while in foreground)
CREATE OR REPLACE FUNCTION public.record_user_app_heartbeat(p_user_id UUID, p_elapsed_seconds INT DEFAULT 40)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET 
    is_app_open = TRUE,
    last_seen_at = NOW(),
    total_app_time_seconds = COALESCE(total_app_time_seconds, 0) + GREATEST(0, p_elapsed_seconds),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: Record User App Close / Background
CREATE OR REPLACE FUNCTION public.record_user_app_close(p_user_id UUID, p_elapsed_seconds INT DEFAULT 0)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET 
    is_app_open = FALSE,
    last_seen_at = NOW(),
    total_app_time_seconds = COALESCE(total_app_time_seconds, 0) + GREATEST(0, p_elapsed_seconds),
    updated_at = NOW()
  WHERE id = p_user_id;

  -- If user is a driver, set drivers.is_online to false on app close
  UPDATE public.drivers
  SET is_online = FALSE
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
