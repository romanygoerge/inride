-- ====================================================================
-- INRIDE SUPABASE SECURITY HARDENING & PRODUCTION RLS POLICIES
-- Removes anonymous write access, secures storage buckets, and enforces strict RLS
-- ====================================================================

-- 1. Helper Function to Check Admin Role
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

-- 2. Hardening Row Level Security (RLS) on Main Tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------
-- Users Table Security Policies
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record" ON public.users;
DROP POLICY IF EXISTS "Admins have full access to users" ON public.users;

CREATE POLICY "Users read own profile or admin" ON public.users
FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users insert own profile or admin" ON public.users
FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users update own profile or admin" ON public.users
FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- --------------------------------------------------------------------
-- Drivers Table Security Policies
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "Drivers write own" ON public.drivers;
DROP POLICY IF EXISTS "Admins have full access to drivers" ON public.drivers;

CREATE POLICY "Drivers read own or admin" ON public.drivers
FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Drivers write own profile or admin" ON public.drivers
FOR ALL USING (auth.uid() = id OR public.is_admin());

-- --------------------------------------------------------------------
-- Passengers Table Security Policies
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "Passengers write own" ON public.passengers;
DROP POLICY IF EXISTS "Admins have full access to passengers" ON public.passengers;

CREATE POLICY "Passengers read own or admin" ON public.passengers
FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Passengers write own profile or admin" ON public.passengers
FOR ALL USING (auth.uid() = id OR public.is_admin());

-- --------------------------------------------------------------------
-- Support Chats & Messages Security Policies
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "Support chats policy" ON public.support_chats;
DROP POLICY IF EXISTS "Support messages policy" ON public.support_messages;
DROP POLICY IF EXISTS "Support chats RLS policy" ON public.support_chats;
DROP POLICY IF EXISTS "Support messages RLS policy" ON public.support_messages;

CREATE POLICY "Support chats authenticated access" ON public.support_chats
FOR ALL USING (
    auth.uid() IS NOT NULL AND (id = auth.uid() OR user_id = auth.uid() OR public.is_admin())
);

CREATE POLICY "Support messages authenticated access" ON public.support_messages
FOR ALL USING (
    auth.uid() IS NOT NULL AND (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR 
        conversation_id = auth.uid() OR 
        user_id = auth.uid() OR
        public.is_admin()
    )
);

-- --------------------------------------------------------------------
-- Storage Buckets Security Policies
-- --------------------------------------------------------------------
-- Remove insecure anonymous write/update/delete policies on storage objects
DROP POLICY IF EXISTS "Authenticated Insert Storage" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Update Storage" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Delete Storage" ON storage.objects;

-- Secure Storage Upload Policy: Authenticated users can upload to their own folder
CREATE POLICY "Strict Authenticated Storage Insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
);

CREATE POLICY "Strict Authenticated Storage Update" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
);

CREATE POLICY "Strict Authenticated Storage Delete" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id IN ('profile-images', 'vehicle-images', 'driver-documents') AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
);

-- Public Bucket Read Access (Profile images & Vehicle public photos)
CREATE POLICY "Public Read Profile & Vehicle Images" ON storage.objects
FOR SELECT USING (
    bucket_id IN ('profile-images', 'vehicle-images') OR
    (bucket_id = 'driver-documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin()))
);
