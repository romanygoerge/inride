-- ====================================================================
-- INRIDE SUPABASE PRODUCTION SECURITY AUDIT & HARDENING FIXES (ALL-IN-ONE)
-- ====================================================================
-- Self-contained script: Automatically creates helper functions, ensures 
-- tables & indexes exist, tightens RLS, and eliminates all permission errors.
-- ====================================================================

-- --------------------------------------------------------------------
-- 0. Ensure Admins Table Exists
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin')) DEFAULT 'admin',
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 1. Helper Security Definer Functions (is_admin & is_active_admin)
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    EXISTS (
      SELECT 1 
      FROM public.users 
      WHERE id = auth.uid() 
        AND (role = 'admin' OR role = 'super_admin')
    ) OR EXISTS (
      SELECT 1 
      FROM public.admins 
      WHERE (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'))
        AND is_active = true
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_active_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    EXISTS (
      SELECT 1 
      FROM public.admins 
      WHERE (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'))
        AND is_active = true
    ) OR EXISTS (
      SELECT 1 
      FROM public.users 
      WHERE id = auth.uid() 
        AND (role = 'admin' OR role = 'super_admin')
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.admins 
    WHERE (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'))
      AND role = 'super_admin'
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- --------------------------------------------------------------------
-- 2. Tighten `admins` Table Read Policy (Prevent Admin Enumeration)
-- --------------------------------------------------------------------
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read admins" ON public.admins;
DROP POLICY IF EXISTS "Admins can read own profile or active admin" ON public.admins;

CREATE POLICY "Admins can read own profile or active admin"
ON public.admins FOR SELECT TO authenticated
USING (
    auth_user_id = auth.uid() 
    OR LOWER(email) = LOWER(auth.jwt() ->> 'email') 
    OR public.is_active_admin()
);

-- --------------------------------------------------------------------
-- 3. Prevent Privilege Escalation on `public.users` Table
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_user_privilege_escalation()
RETURNS TRIGGER AS $$
BEGIN
    -- If user is NOT an active admin, lock down system-critical fields
    IF NOT (public.is_admin() OR public.is_active_admin()) THEN
        -- Prevent role elevation
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            NEW.role := OLD.role;
        END IF;
        
        -- Prevent created_at modification
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            NEW.created_at := OLD.created_at;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_user_privilege_escalation ON public.users;
CREATE TRIGGER trg_prevent_user_privilege_escalation
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_user_privilege_escalation();

-- --------------------------------------------------------------------
-- 4. Clean Legacy Anonymous (anon) Policies Across All Core Tables
-- --------------------------------------------------------------------

-- Users Table
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record" ON public.users;
DROP POLICY IF EXISTS "Users read own profile or admin" ON public.users;
DROP POLICY IF EXISTS "Users insert own profile or admin" ON public.users;
DROP POLICY IF EXISTS "Users update own profile or admin" ON public.users;

CREATE POLICY "Users read own profile or admin" ON public.users
FOR SELECT USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

CREATE POLICY "Users insert own profile or admin" ON public.users
FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

CREATE POLICY "Users update own profile or admin" ON public.users
FOR UPDATE USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

-- Passengers Table
ALTER TABLE IF EXISTS public.passengers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Passengers write own" ON public.passengers;
DROP POLICY IF EXISTS "Passengers read own or admin" ON public.passengers;
DROP POLICY IF EXISTS "Passengers write own profile or admin" ON public.passengers;

CREATE POLICY "Passengers read own or admin" ON public.passengers
FOR SELECT USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

CREATE POLICY "Passengers write own profile or admin" ON public.passengers
FOR ALL USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

-- Drivers Table
ALTER TABLE IF EXISTS public.drivers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Drivers write own" ON public.drivers;
DROP POLICY IF EXISTS "Drivers read own or admin" ON public.drivers;
DROP POLICY IF EXISTS "Drivers write own profile or admin" ON public.drivers;

CREATE POLICY "Drivers read own or admin" ON public.drivers
FOR SELECT USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

CREATE POLICY "Drivers write own profile or admin" ON public.drivers
FOR ALL USING (auth.uid() = id OR public.is_admin() OR public.is_active_admin());

-- Vehicles Table
ALTER TABLE IF EXISTS public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Drivers write own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Vehicles access policy" ON public.vehicles;

CREATE POLICY "Vehicles access policy" ON public.vehicles
FOR ALL USING (auth.uid() = driver_id OR public.is_admin() OR public.is_active_admin());

-- --------------------------------------------------------------------
-- 5. Secure Storage Policies (driver-documents, profile-images, vehicle-images)
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated Insert Storage" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Update Storage" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Delete Storage" ON storage.objects;
DROP POLICY IF EXISTS "Strict Authenticated Storage Insert" ON storage.objects;
DROP POLICY IF EXISTS "Strict Authenticated Storage Update" ON storage.objects;
DROP POLICY IF EXISTS "Strict Authenticated Storage Delete" ON storage.objects;
DROP POLICY IF EXISTS "Public Read Profile & Vehicle Images" ON storage.objects;

-- Strict folder upload/update/delete based on auth.uid() folder prefix
CREATE POLICY "Strict Authenticated Storage Insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin() OR public.is_active_admin())
);

CREATE POLICY "Strict Authenticated Storage Update" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin() OR public.is_active_admin())
);

CREATE POLICY "Strict Authenticated Storage Delete" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin() OR public.is_active_admin())
);

CREATE POLICY "Public Read Profile & Vehicle Images" ON storage.objects
FOR SELECT USING (
    bucket_id IN ('profile-images', 'vehicle-images') OR
    (bucket_id = 'driver-documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin() OR public.is_active_admin()))
);
