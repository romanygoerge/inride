-- ====================================================================
-- INRIDE CAPTAIN PRESENCE, STATUS & HEARTBEAT SYSTEM FIX (2026)
-- 1. Extend drivers table with presence tracking columns (non-destructive)
-- 2. Extend app_settings with configurable timeout
-- 3. Add public.users to supabase_realtime publication
-- 4. Rewrite RPCs to use server timestamp NOW() and separate concerns:
--    - App Opened != Online (heartbeat alive) != Available for Trips
-- 5. Tighten RLS on drivers to prevent tampering across accounts
-- 6. Update cleanup_stale_drivers for reliable automatic offline transition
-- ====================================================================

-- 1. Extend public.drivers
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS last_app_open TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS is_app_open BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_drivers_last_seen_at ON public.drivers(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_drivers_is_online ON public.drivers(is_online);
CREATE INDEX IF NOT EXISTS idx_drivers_is_available ON public.drivers(is_available);

-- 2. Extend public.app_settings
ALTER TABLE public.app_settings
ADD COLUMN IF NOT EXISTS driver_offline_timeout_seconds INT DEFAULT 180;

UPDATE public.app_settings
SET driver_offline_timeout_seconds = 180
WHERE id = 'default' AND (driver_offline_timeout_seconds IS NULL OR driver_offline_timeout_seconds <= 0);

-- 3. Add public.users to Realtime publication if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END $$;

-- Ensure replica identity is FULL for both tables to transmit all columns
ALTER TABLE public.users REPLICA IDENTITY FULL;
ALTER TABLE public.drivers REPLICA IDENTITY FULL;

-- 4. RPC: Record User App Open
-- Triggered whenever the user/driver opens the app or returns from background.
-- Sets last_app_open = NOW() on both users and drivers tables.
-- NOTE: DOES NOT alter is_available (opening app does NOT mean available for trips).
CREATE OR REPLACE FUNCTION public.record_user_app_open(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Security check: user can only record for themselves unless admin
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id AND NOT (SELECT COALESCE(is_active_admin(), false)) THEN
    RAISE EXCEPTION 'Unauthorized: cannot record app open for another user';
  END IF;

  UPDATE public.users
  SET 
    is_app_open = TRUE,
    last_opened_at = NOW(),
    last_seen_at = NOW(),
    app_open_count = COALESCE(app_open_count, 0) + 1,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- If user is a driver, record app open and online presence on drivers table
  -- We preserve is_available so driver is not forced into available trips state
  UPDATE public.drivers
  SET 
    is_app_open = TRUE,
    last_app_open = NOW(),
    last_seen_at = NOW(),
    is_online = TRUE,
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: Record User Heartbeat
CREATE OR REPLACE FUNCTION public.record_user_app_heartbeat(p_user_id UUID, p_elapsed_seconds INT DEFAULT 30)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id AND NOT (SELECT COALESCE(is_active_admin(), false)) THEN
    RAISE EXCEPTION 'Unauthorized: cannot record heartbeat for another user';
  END IF;

  UPDATE public.users
  SET 
    is_app_open = TRUE,
    last_seen_at = NOW(),
    total_app_time_seconds = COALESCE(total_app_time_seconds, 0) + GREATEST(0, p_elapsed_seconds),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Record Driver Heartbeat (dedicated for captains while in driver mode)
CREATE OR REPLACE FUNCTION public.record_driver_heartbeat(
  p_driver_id UUID,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL,
  p_elapsed_seconds INT DEFAULT 30
)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() != p_driver_id AND NOT (SELECT COALESCE(is_active_admin(), false)) THEN
    RAISE EXCEPTION 'Unauthorized: cannot record driver heartbeat for another captain';
  END IF;

  -- Update users presence
  UPDATE public.users
  SET 
    is_app_open = TRUE,
    last_seen_at = NOW(),
    total_app_time_seconds = COALESCE(total_app_time_seconds, 0) + GREATEST(0, p_elapsed_seconds),
    updated_at = NOW()
  WHERE id = p_driver_id;

  -- Update drivers presence & location
  UPDATE public.drivers
  SET 
    is_online = TRUE,
    is_app_open = TRUE,
    last_seen_at = NOW(),
    updated_at = NOW(),
    current_latitude = COALESCE(p_lat, current_latitude),
    current_longitude = COALESCE(p_lng, current_longitude)
  WHERE id = p_driver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Record App Close / Background
CREATE OR REPLACE FUNCTION public.record_user_app_close(p_user_id UUID, p_elapsed_seconds INT DEFAULT 0)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id AND NOT (SELECT COALESCE(is_active_admin(), false)) THEN
    RAISE EXCEPTION 'Unauthorized: cannot record app close for another user';
  END IF;

  UPDATE public.users
  SET 
    is_app_open = FALSE,
    last_seen_at = NOW(),
    total_app_time_seconds = COALESCE(total_app_time_seconds, 0) + GREATEST(0, p_elapsed_seconds),
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Update drivers table app open status.
  -- We do NOT immediately set is_online = FALSE if driver briefly minimized app,
  -- but we update last_seen_at and is_app_open = FALSE.
  -- If heartbeat does not resume before timeout, cleanup_stale_drivers sets is_online = FALSE.
  UPDATE public.drivers
  SET 
    is_app_open = FALSE,
    last_seen_at = NOW(),
    updated_at = NOW()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: Set Driver Trip Availability (explicit toggle from captain switch)
CREATE OR REPLACE FUNCTION public.set_driver_trip_availability(p_driver_id UUID, p_is_available BOOLEAN)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() != p_driver_id AND NOT (SELECT COALESCE(is_active_admin(), false)) THEN
    RAISE EXCEPTION 'Unauthorized: cannot change trip availability for another captain';
  END IF;

  UPDATE public.drivers
  SET 
    is_available = p_is_available,
    is_online = CASE WHEN p_is_available THEN TRUE ELSE is_online END,
    last_seen_at = NOW(),
    updated_at = NOW()
  WHERE id = p_driver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Function & Cron: Cleanup Stale Drivers (Timeout handling)
CREATE OR REPLACE FUNCTION public.cleanup_stale_drivers()
RETURNS integer AS $$
DECLARE
  affected_count integer;
  v_timeout_seconds integer;
BEGIN
  -- Read configurable timeout from app_settings, fallback to 180s (3 minutes)
  SELECT COALESCE(driver_offline_timeout_seconds, 180)
  INTO v_timeout_seconds
  FROM public.app_settings
  WHERE id = 'default';
  
  IF v_timeout_seconds IS NULL OR v_timeout_seconds < 30 THEN
    v_timeout_seconds := 180;
  END IF;

  UPDATE public.drivers
  SET is_online = FALSE,
      is_available = FALSE,
      is_app_open = FALSE,
      updated_at = NOW()
  WHERE is_online = TRUE
    AND (
      last_seen_at IS NULL 
      OR last_seen_at < (NOW() - (v_timeout_seconds || ' seconds')::INTERVAL)
    );

  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Security & RLS Tightening on drivers table
-- Drop open policy that allowed any user to modify any driver
DROP POLICY IF EXISTS "Allow open drivers access" ON public.drivers;

-- Ensure drivers update policy only permits self-updates or admins
DROP POLICY IF EXISTS "Drivers write own profile or admin" ON public.drivers;
CREATE POLICY "Drivers write own profile or admin"
ON public.drivers
FOR UPDATE
TO public
USING (
  (auth.uid() = id) 
  OR (SELECT COALESCE(is_admin(), false)) 
  OR (SELECT COALESCE(is_active_admin(), false))
)
WITH CHECK (
  (auth.uid() = id) 
  OR (SELECT COALESCE(is_admin(), false)) 
  OR (SELECT COALESCE(is_active_admin(), false))
);

-- Ensure drivers insert policy
DROP POLICY IF EXISTS "Drivers insert own profile or admin" ON public.drivers;
CREATE POLICY "Drivers insert own profile or admin"
ON public.drivers
FOR INSERT
TO public
WITH CHECK (
  (auth.uid() = id) 
  OR (SELECT COALESCE(is_admin(), false)) 
  OR (SELECT COALESCE(is_active_admin(), false))
);
