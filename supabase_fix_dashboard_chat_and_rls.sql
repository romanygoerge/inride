-- ====================================================================
-- INRIDE FULL ADMIN DASHBOARD & SUPPORT CHAT RLS FIX SCRIPT
-- Resolves: 
-- 1. Support Chat messages delivery (Admin <-> Passengers / Drivers)
-- 2. "فشل الإجراء" (Operation failed) errors on Admin Dashboard buttons
-- ====================================================================

-- 0. Ensure Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Ensure All Tables Exist
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    phone_number TEXT DEFAULT '',
    email TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'rider',
    rating DOUBLE PRECISION DEFAULT 5.0,
    wallet_balance NUMERIC(10,2) DEFAULT 250.00,
    avatar_url TEXT DEFAULT '',
    fcm_token TEXT DEFAULT '',
    banned_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.passengers (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT DEFAULT '',
    email TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    gender TEXT DEFAULT '',
    address TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    fcm_token TEXT DEFAULT '',
    total_trips INT DEFAULT 0,
    rating DOUBLE PRECISION DEFAULT 5.0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    model TEXT DEFAULT '',
    number_plate TEXT DEFAULT '',
    color TEXT DEFAULT '',
    type TEXT DEFAULT 'car',
    year INT DEFAULT 2020,
    status TEXT DEFAULT 'active',
    license_url TEXT DEFAULT '',
    insurance_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    is_online BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    verification_status TEXT DEFAULT 'unregistered',
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    national_id_url TEXT DEFAULT '',
    license_url TEXT DEFAULT '',
    vehicle_front_url TEXT DEFAULT '',
    vehicle_back_url TEXT DEFAULT '',
    vehicle_license_url TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    fcm_token TEXT DEFAULT '',
    rating DOUBLE PRECISION DEFAULT 5.0,
    total_earnings NUMERIC(10,2) DEFAULT 0.00,
    total_trips INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ride_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passenger_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    pickup_latitude DOUBLE PRECISION NOT NULL,
    pickup_longitude DOUBLE PRECISION NOT NULL,
    pickup_address TEXT DEFAULT '',
    destination_latitude DOUBLE PRECISION NOT NULL,
    destination_longitude DOUBLE PRECISION NOT NULL,
    destination_address TEXT DEFAULT '',
    vehicle_type TEXT NOT NULL DEFAULT 'car',
    offered_fare NUMERIC(10,2) NOT NULL,
    distance DOUBLE PRECISION NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    passenger_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    fare NUMERIC(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    balance NUMERIC(10,2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    type TEXT DEFAULT 'charge',
    balance_after NUMERIC(10,2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_name TEXT DEFAULT '',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'admin_notifications',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.support_chats (
    id UUID PRIMARY KEY,
    user_id UUID,
    user_type TEXT DEFAULT 'rider',
    user_name TEXT DEFAULT '',
    status TEXT DEFAULT 'open',
    last_message TEXT DEFAULT '',
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    unread_admin_count INT DEFAULT 0,
    unread_user_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID,
    user_id UUID,
    sender_id UUID,
    receiver_id UUID,
    sender_type TEXT DEFAULT 'rider',
    message TEXT DEFAULT '',
    text TEXT DEFAULT '',
    status TEXT DEFAULT 'sent',
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- 2. Ensure Admin User Records exist in `public.users` table
INSERT INTO public.users (id, name, email, role, created_at, updated_at)
VALUES 
    (
        'fbf9e43e-3ca0-4950-ab0e-11367a24c162',
        'روماني جورج',
        'romanygoerge48@gmail.com',
        'admin',
        NOW(),
        NOW()
    ),
    (
        'd8daab61-f140-4c1d-a90e-2657499c94ad',
        'مدير النظام',
        'admin@inride.com',
        'admin',
        NOW(),
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    role = 'admin',
    email = EXCLUDED.email,
    updated_at = NOW();

-- 3. Fix Row Level Security (RLS) policies for Open Access Admin Dashboard
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow open support_chats" ON public.support_chats;
CREATE POLICY "Allow open support_chats" ON public.support_chats FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open support_messages" ON public.support_messages;
CREATE POLICY "Allow open support_messages" ON public.support_messages FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open users access" ON public.users;
CREATE POLICY "Allow open users access" ON public.users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open drivers access" ON public.drivers;
CREATE POLICY "Allow open drivers access" ON public.drivers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open passengers access" ON public.passengers;
CREATE POLICY "Allow open passengers access" ON public.passengers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open vehicles access" ON public.vehicles;
CREATE POLICY "Allow open vehicles access" ON public.vehicles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open trips access" ON public.trips;
CREATE POLICY "Allow open trips access" ON public.trips FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open ride_requests access" ON public.ride_requests;
CREATE POLICY "Allow open ride_requests access" ON public.ride_requests FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open wallets access" ON public.wallets;
CREATE POLICY "Allow open wallets access" ON public.wallets FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open transactions access" ON public.transactions;
CREATE POLICY "Allow open transactions access" ON public.transactions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow open admin_notifications access" ON public.admin_notifications;
CREATE POLICY "Allow open admin_notifications access" ON public.admin_notifications FOR ALL USING (true) WITH CHECK (true);

-- 4. Trigger for automatic support conversation updates
CREATE OR REPLACE FUNCTION public.handle_support_message_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.message IS NULL OR NEW.message = '' THEN
    NEW.message := COALESCE(NEW.text, '');
  END IF;
  IF NEW.text IS NULL OR NEW.text = '' THEN
    NEW.text := COALESCE(NEW.message, '');
  END IF;

  IF NEW.conversation_id IS NULL THEN
    NEW.conversation_id := NEW.user_id;
  END IF;
  IF NEW.user_id IS NULL THEN
    NEW.user_id := NEW.conversation_id;
  END IF;

  IF NEW.sender_type = 'admin' THEN
    NEW.is_admin := TRUE;
  END IF;

  INSERT INTO public.support_chats (
    id,
    user_id,
    user_type,
    user_name,
    status,
    last_message,
    last_message_at,
    unread_admin_count,
    unread_user_count,
    created_at,
    updated_at
  )
  VALUES (
    NEW.conversation_id,
    NEW.user_id,
    COALESCE(NEW.sender_type, 'rider'),
    '',
    'open',
    NEW.message,
    COALESCE(NEW.created_at, NOW()),
    CASE WHEN NEW.sender_type IN ('rider', 'driver') THEN 1 ELSE 0 END,
    CASE WHEN NEW.sender_type = 'admin' THEN 1 ELSE 0 END,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    last_message = EXCLUDED.last_message,
    last_message_at = EXCLUDED.last_message_at,
    status = 'open',
    unread_admin_count = CASE 
      WHEN EXCLUDED.user_type IN ('rider', 'driver') THEN public.support_chats.unread_admin_count + 1 
      ELSE public.support_chats.unread_admin_count 
    END,
    unread_user_count = CASE 
      WHEN EXCLUDED.user_type = 'admin' THEN public.support_chats.unread_user_count + 1 
      ELSE public.support_chats.unread_user_count 
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_handle_support_message_insert ON public.support_messages;
CREATE TRIGGER trg_handle_support_message_insert
BEFORE INSERT ON public.support_messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_support_message_insert();

-- 5. Enable Realtime on support tables
ALTER TABLE public.support_chats REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_chats'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chats;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
  END IF;
END $$;
