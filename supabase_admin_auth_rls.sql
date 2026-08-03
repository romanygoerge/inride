-- ====================================================================
-- SUPABASE SQL MIGRATION: ADMIN AUTHENTICATION & RLS SECURITY POLICIES
-- ====================================================================
-- Description: Creates clean `admins` table, enables RLS, allows authenticated
-- users to query `admins` by email or auth_user_id, and inserts Super Admin.
-- ====================================================================

-- 1. DROP EXISTING TABLE AND ALL LEGACY CONSTRAINTS
DROP TABLE IF EXISTS public.admins CASCADE;

-- 2. CREATE CLEAN ADMINS TABLE
CREATE TABLE public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin')) DEFAULT 'admin',
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. CREATE PERFORMANCE INDEXES
CREATE INDEX idx_admins_auth_user_id ON public.admins(auth_user_id);
CREATE INDEX idx_admins_email ON public.admins(email);
CREATE INDEX idx_admins_is_active ON public.admins(is_active);
CREATE INDEX idx_admins_role ON public.admins(role);

-- 4. HELPER SECURITY DEFINER FUNCTIONS (STABLE & SECURE)
CREATE OR REPLACE FUNCTION public.is_active_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.admins 
    WHERE (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'))
      AND is_active = true
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

-- 5. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- 6. CREATE SECURE RLS POLICIES FOR ADMINS TABLE

DROP POLICY IF EXISTS "Allow authenticated read admins" ON public.admins;
CREATE POLICY "Allow authenticated read admins"
ON public.admins FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "Admins can update their own profile" ON public.admins;
CREATE POLICY "Admins can update their own profile"
ON public.admins FOR UPDATE TO authenticated
USING (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'))
WITH CHECK (auth_user_id = auth.uid() OR LOWER(email) = LOWER(auth.jwt() ->> 'email'));

DROP POLICY IF EXISTS "Super Admins can insert new admins" ON public.admins;
CREATE POLICY "Super Admins can insert new admins"
ON public.admins FOR INSERT TO authenticated WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "Super Admins can delete admins" ON public.admins;
CREATE POLICY "Super Admins can delete admins"
ON public.admins FOR DELETE TO authenticated USING (public.is_super_admin());

-- 7. APPLY RLS TO OTHER DASHBOARD TABLES (IF THEY EXIST)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Active Admins full access to users" ON public.users;
        CREATE POLICY "Active Admins full access to users" ON public.users FOR ALL TO authenticated USING (public.is_active_admin());
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'drivers') THEN
        ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Active Admins full access to drivers" ON public.drivers;
        CREATE POLICY "Active Admins full access to drivers" ON public.drivers FOR ALL TO authenticated USING (public.is_active_admin());
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips') THEN
        ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Active Admins full access to trips" ON public.trips;
        CREATE POLICY "Active Admins full access to trips" ON public.trips FOR ALL TO authenticated USING (public.is_active_admin());
    END IF;
END $$;

-- 8. INSERT OR UPDATE SUPER ADMIN RECORD FOR romanygoerge48@gmail.com
INSERT INTO public.admins (auth_user_id, name, email, role, is_active, created_at)
VALUES (
    'fbf9e436-3ca0-4950-ab0e-11367a24c162',
    'Romany George',
    'romanygoerge48@gmail.com',
    'super_admin',
    true,
    NOW()
)
ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    role = 'super_admin',
    is_active = true,
    name = EXCLUDED.name;
