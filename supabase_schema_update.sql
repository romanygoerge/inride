-- ====================================================================
-- SUPABASE COMPLETE SCHEMA UPDATE & RLS SECURITY POLICIES SCRIPT
-- Project: inRide App 2026
-- Execute this script in Supabase Dashboard: SQL Editor -> New Query
-- ====================================================================

-- 1. ADD MISSING COLUMNS IF NOT PRESENT
ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS national_id_back_url TEXT DEFAULT '';
ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS license_back_url TEXT DEFAULT '';
ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS vehicle_front_url TEXT DEFAULT '';
ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS vehicle_back_url TEXT DEFAULT '';

ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS vehicle_category TEXT DEFAULT 'car';
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS has_ac BOOLEAN DEFAULT FALSE;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS max_passengers INT DEFAULT 4;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS credit_limit NUMERIC(10,2) DEFAULT -100.00;

ALTER TABLE public.passengers ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '';
ALTER TABLE public.passengers ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT '';

-- APP SETTINGS TABLE FOR PRICING RULES & SURGE
CREATE TABLE IF NOT EXISTS public.app_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    first_km_fare NUMERIC(10,2) DEFAULT 20.00,
    extra_km_fare NUMERIC(10,2) DEFAULT 5.00,
    ac_km_fare NUMERIC(10,2) DEFAULT 1.00,
    heat_hour_km_fare NUMERIC(10,2) DEFAULT 1.00,
    heat_start_hour INT DEFAULT 11,
    heat_end_hour INT DEFAULT 15,
    default_fare_car NUMERIC(10,2) DEFAULT 45.00,
    default_fare_scooter NUMERIC(10,2) DEFAULT 20.00,
    default_fare_motorcycle NUMERIC(10,2) DEFAULT 15.00,
    commission_rate NUMERIC(10,2) DEFAULT 10.00,
    min_fare NUMERIC(10,2) DEFAULT 10.00,
    max_fare NUMERIC(10,2) DEFAULT 500.00,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.app_settings (id, first_km_fare, extra_km_fare, ac_km_fare, heat_hour_km_fare, heat_start_hour, heat_end_hour)
VALUES ('default', 20.00, 5.00, 1.00, 1.00, 11, 15)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public app_settings access" ON public.app_settings;
CREATE POLICY "Public app_settings access" ON public.app_settings FOR ALL USING (true);

-- 2. SETUP REALTIME PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.drivers,
    public.ride_requests,
    public.ride_offers,
    public.chat_messages,
    public.typing_indicators,
    public.notifications,
    public.support_messages;

-- 3. ENABLE REPLICA IDENTITY FULL FOR REALTIME STREAMS
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.ride_requests REPLICA IDENTITY FULL;
ALTER TABLE public.ride_offers REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.typing_indicators REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

-- 4. ROW LEVEL SECURITY (RLS) POLICIES FOR ALL TABLES

-- Table: public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public users read access" ON public.users;
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record" ON public.users;

CREATE POLICY "Public users read access" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert own record" ON public.users FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'anon' OR auth.role() = 'service_role');
CREATE POLICY "Users can update own record" ON public.users FOR UPDATE USING (auth.uid() = id OR auth.role() = 'anon' OR auth.role() = 'service_role');

-- Table: public.passengers
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public passengers read" ON public.passengers;
DROP POLICY IF EXISTS "Passengers write own" ON public.passengers;

CREATE POLICY "Public passengers read" ON public.passengers FOR SELECT USING (true);
CREATE POLICY "Passengers write own" ON public.passengers FOR ALL USING (auth.uid() = id OR auth.role() = 'anon' OR auth.role() = 'service_role');

-- Table: public.drivers
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public drivers read" ON public.drivers;
DROP POLICY IF EXISTS "Drivers write own" ON public.drivers;

CREATE POLICY "Public drivers read" ON public.drivers FOR SELECT USING (true);
CREATE POLICY "Drivers write own" ON public.drivers FOR ALL USING (auth.uid() = id OR auth.role() = 'anon' OR auth.role() = 'service_role');

-- Table: public.vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public vehicles read" ON public.vehicles;
DROP POLICY IF EXISTS "Drivers write own vehicles" ON public.vehicles;

CREATE POLICY "Public vehicles read" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "Drivers write own vehicles" ON public.vehicles FOR ALL USING (auth.uid() = driver_id OR auth.role() = 'anon' OR auth.role() = 'service_role');

-- Table: public.ride_requests
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ride_requests read" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers create ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Participants update ride_requests" ON public.ride_requests;

CREATE POLICY "Public ride_requests read" ON public.ride_requests FOR SELECT USING (true);
CREATE POLICY "Passengers create ride_requests" ON public.ride_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Participants update ride_requests" ON public.ride_requests FOR UPDATE USING (true);

-- Table: public.ride_offers
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ride_offers read" ON public.ride_offers;
DROP POLICY IF EXISTS "Drivers insert ride_offers" ON public.ride_offers;
DROP POLICY IF EXISTS "Participants update ride_offers" ON public.ride_offers;

CREATE POLICY "Public ride_offers read" ON public.ride_offers FOR SELECT USING (true);
CREATE POLICY "Drivers insert ride_offers" ON public.ride_offers FOR INSERT WITH CHECK (true);
CREATE POLICY "Participants update ride_offers" ON public.ride_offers FOR UPDATE USING (true);

-- Table: public.chat_messages
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public chat_messages read" ON public.chat_messages;
DROP POLICY IF EXISTS "Users insert chat_messages" ON public.chat_messages;

CREATE POLICY "Public chat_messages read" ON public.chat_messages FOR SELECT USING (true);
CREATE POLICY "Users insert chat_messages" ON public.chat_messages FOR INSERT WITH CHECK (true);

-- Table: public.typing_indicators
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public typing_indicators read" ON public.typing_indicators;
DROP POLICY IF EXISTS "Users write typing_indicators" ON public.typing_indicators;

CREATE POLICY "Public typing_indicators read" ON public.typing_indicators FOR SELECT USING (true);
CREATE POLICY "Users write typing_indicators" ON public.typing_indicators FOR ALL USING (true);

-- Table: public.ratings
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ratings read" ON public.ratings;
DROP POLICY IF EXISTS "Users insert ratings" ON public.ratings;

CREATE POLICY "Public ratings read" ON public.ratings FOR SELECT USING (true);
CREATE POLICY "Users insert ratings" ON public.ratings FOR INSERT WITH CHECK (true);

-- Table: public.notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Public insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;

CREATE POLICY "Users read own notifications" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "Public insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (true);

-- Table: public.transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users insert transactions" ON public.transactions;

CREATE POLICY "Users read transactions" ON public.transactions FOR SELECT USING (true);
CREATE POLICY "Users insert transactions" ON public.transactions FOR INSERT WITH CHECK (true);

-- Table: public.support_chats
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Support chats policy" ON public.support_chats;
CREATE POLICY "Support chats policy" ON public.support_chats FOR ALL USING (true);

-- Table: public.support_messages
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Support messages policy" ON public.support_messages;
CREATE POLICY "Support messages policy" ON public.support_messages FOR ALL USING (true);

-- Automatic user profile creation trigger on auth.users
CREATE OR REPLACE FUNCTION public.handle_new_auth_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email, phone_number, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone_number', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'rider')
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

