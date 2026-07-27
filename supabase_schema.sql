-- ==========================================
-- SUPABASE POSTGRESQL FULL DATABASE SCHEMA
-- Project: inRide App
-- ==========================================

-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==========================================
-- 1. USERS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY, -- Matches auth.users.id
    name TEXT NOT NULL DEFAULT '',
    phone_number TEXT DEFAULT '',
    email TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'rider' CHECK (role IN ('rider', 'driver', 'admin')),
    rating DOUBLE PRECISION DEFAULT 5.0,
    wallet_balance NUMERIC(10,2) DEFAULT 250.00,
    avatar_url TEXT DEFAULT '',
    fcm_token TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- ==========================================
-- 2. PASSENGERS TABLE
-- ==========================================
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

-- ==========================================
-- 3. VEHICLES TABLE
-- ==========================================
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

CREATE INDEX IF NOT EXISTS idx_vehicles_driver ON public.vehicles(driver_id);

-- ==========================================
-- 4. DRIVERS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    is_online BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    verification_status TEXT DEFAULT 'unregistered' CHECK (verification_status IN ('unregistered', 'submitted', 'verified', 'rejected')),
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

CREATE INDEX IF NOT EXISTS idx_drivers_online_available ON public.drivers(is_online, is_available);
CREATE INDEX IF NOT EXISTS idx_drivers_coords ON public.drivers(current_latitude, current_longitude);

-- Add Foreign Key from vehicles to drivers if not already constrained
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS fk_vehicles_driver;
ALTER TABLE public.vehicles ADD CONSTRAINT fk_vehicles_driver FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ==========================================
-- 5. RIDE REQUESTS TABLE
-- ==========================================
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
    payment_method TEXT DEFAULT 'cash',
    service_type TEXT DEFAULT 'ride',
    package_description TEXT,
    delivery_notes TEXT,
    passenger_count INT DEFAULT 1,
    is_delivery_location_confirmed BOOLEAN DEFAULT TRUE,
    recipient_phone TEXT,
    recipient_region TEXT,
    recipient_street TEXT,
    recipient_building TEXT,
    recipient_floor TEXT,
    recipient_landmark TEXT,
    recipient_token TEXT,
    pickup_photo_url TEXT,
    delivery_photo_url TEXT,
    cancel_reason TEXT,
    cancellation_reason TEXT,
    cancelled_by TEXT,
    cancelled_at TIMESTAMPTZ,
    expired_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON public.ride_requests(status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_passenger ON public.ride_requests(passenger_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_driver ON public.ride_requests(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_created ON public.ride_requests(created_at DESC);

-- ==========================================
-- 6. RIDE OFFERS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.ride_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    passenger_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    driver_name TEXT DEFAULT 'سائق',
    driver_avatar TEXT DEFAULT '',
    driver_rating DOUBLE PRECISION DEFAULT 5.0,
    vehicle_type TEXT DEFAULT 'car',
    vehicle_name TEXT DEFAULT '',
    license_plate TEXT DEFAULT '',
    price NUMERIC(10,2) NOT NULL,
    eta_minutes INT DEFAULT 5,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ride_offers_request ON public.ride_offers(request_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver ON public.ride_offers(driver_id);

-- ==========================================
-- 7. CHAT MESSAGES TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sender_name TEXT DEFAULT '',
    text TEXT DEFAULT '',
    is_driver BOOLEAN DEFAULT FALSE,
    type TEXT DEFAULT 'text',
    audio_url TEXT DEFAULT '',
    image_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_request ON public.chat_messages(request_id, created_at ASC);

-- ==========================================
-- 8. TYPING INDICATORS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.typing_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_request_user_typing UNIQUE (request_id, user_id)
);

-- ==========================================
-- 9. RATINGS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.ratings (
    id TEXT PRIMARY KEY, -- requestId_senderId
    request_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_role TEXT NOT NULL,
    rating DOUBLE PRECISION NOT NULL,
    comment TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ratings_receiver ON public.ratings(receiver_id);

-- ==========================================
-- 10. NOTIFICATIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC);

-- ==========================================
-- 11. TRANSACTIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    type TEXT NOT NULL, -- 'credit' or 'debit'
    balance_after NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON public.transactions(user_id, created_at DESC);

-- ==========================================
-- 12. SUPPORT CHATS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.support_chats (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 13. SUPPORT MESSAGES TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.support_chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    text TEXT DEFAULT '',
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_messages_user ON public.support_messages(user_id, created_at ASC);

-- ==========================================
-- 14. ADMIN NOTIFICATIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'admin_notifications',
    target TEXT DEFAULT 'all',
    target_city TEXT,
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 15. ADMIN NOTIFICATION RECEIPTS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.admin_notification_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES public.admin_notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    device TEXT DEFAULT 'flutter_client_sync',
    received_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 16. AUDIT LOGS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id TEXT,
    action TEXT NOT NULL,
    details JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- REALTIME PUBLICATION SETUP
-- ==========================================
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.drivers,
    public.ride_requests,
    public.ride_offers,
    public.chat_messages,
    public.typing_indicators,
    public.notifications,
    public.support_messages;

-- Enable REPLICA IDENTITY FULL for tables used in Realtime streams
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.ride_requests REPLICA IDENTITY FULL;
ALTER TABLE public.ride_offers REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.typing_indicators REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

-- ==========================================
-- STORAGE BUCKETS SETUP
-- ==========================================
INSERT INTO storage.buckets (id, name, public) VALUES 
    ('avatars', 'avatars', true),
    ('captains', 'captains', true),
    ('licenses', 'licenses', true),
    ('national_ids', 'national_ids', true),
    ('orders', 'orders', true),
    ('deliveries', 'deliveries', true),
    ('products', 'products', true),
    ('chat', 'chat', true),
    ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- STORAGE POLICIES
CREATE POLICY "Public Read Storage" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Storage" ON storage.objects FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'anon' OR auth.role() = 'service_role');
CREATE POLICY "Authenticated Update Storage" ON storage.objects FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'anon' OR auth.role() = 'service_role');
CREATE POLICY "Authenticated Delete Storage" ON storage.objects FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'anon' OR auth.role() = 'service_role');
