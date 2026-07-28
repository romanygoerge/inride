-- ====================================================================
-- INRIDE ADMIN DASHBOARD AUTHENTICATION & ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================
-- Run this entire script in the Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Run
-- ====================================================================

-- 1. Ensure `role` column constraint in `public.users` permits 'admin'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'users' 
          AND column_name = 'role'
    ) THEN
        ALTER TABLE public.users ADD COLUMN role TEXT DEFAULT 'rider';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- 2. Helper function to check if current authenticated user is an Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.users 
    WHERE id = auth.uid() 
      AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ====================================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ====================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notification_receipts ENABLE ROW LEVEL SECURITY;

-- Create missing administrative tables if not existing
CREATE TABLE IF NOT EXISTS public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_type TEXT DEFAULT 'all',
    type TEXT DEFAULT 'admin_notifications',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_notification_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES public.admin_notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    admin_id TEXT
);

ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notification_receipts ENABLE ROW LEVEL SECURITY;

-- ====================================================================
-- 4. RLS POLICIES FOR USERS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins have full access to users" ON public.users;
CREATE POLICY "Admins have full access to users"
ON public.users
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- ====================================================================
-- 5. RLS POLICIES FOR DRIVERS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins have full access to drivers" ON public.drivers;
CREATE POLICY "Admins have full access to drivers"
ON public.drivers
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================================================================
-- 6. RLS POLICIES FOR PASSENGERS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins have full access to passengers" ON public.passengers;
CREATE POLICY "Admins have full access to passengers"
ON public.passengers
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================================================================
-- 7. RLS POLICIES FOR VEHICLES TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins have full access to vehicles" ON public.vehicles;
CREATE POLICY "Admins have full access to vehicles"
ON public.vehicles
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================================================================
-- 8. RLS POLICIES FOR TRIPS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins have full access to trips" ON public.trips;
CREATE POLICY "Admins have full access to trips"
ON public.trips
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================================================================
-- 9. RLS POLICIES FOR ADMIN NOTIFICATIONS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins full access to admin_notifications" ON public.admin_notifications;
CREATE POLICY "Admins full access to admin_notifications"
ON public.admin_notifications
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can view admin notifications" ON public.admin_notifications;
CREATE POLICY "Users can view admin notifications"
ON public.admin_notifications
FOR SELECT
TO authenticated
USING (true);

-- ====================================================================
-- 10. RLS POLICIES FOR ADMIN NOTIFICATION RECEIPTS TABLE
-- ====================================================================
DROP POLICY IF EXISTS "Admins full access to receipts" ON public.admin_notification_receipts;
CREATE POLICY "Admins full access to receipts"
ON public.admin_notification_receipts
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can insert own receipt" ON public.admin_notification_receipts;
CREATE POLICY "Users can insert own receipt"
ON public.admin_notification_receipts
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ====================================================================
-- 11. ASSIGN ADMINISTRATOR ROLE TO USER UID: d8daab61-f140-4c1d-a90e-2657499c94ad
-- ====================================================================
INSERT INTO public.users (id, name, email, role, created_at, updated_at)
VALUES (
    'd8daab61-f140-4c1d-a90e-2657499c94ad',
    'مدير النظام',
    'admin@inride.com',
    'admin',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    role = 'admin',
    updated_at = NOW();

