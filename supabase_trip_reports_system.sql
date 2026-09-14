-- ================================================================
-- inRide Trip Reports & Complaints System (نظام البلاغات والشكاوى)
-- Supports reporting captain or passenger during, after, or on cancellation
-- ================================================================

CREATE TABLE IF NOT EXISTS public.trip_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES public.ride_requests(id) ON DELETE SET NULL,
    reporter_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    reporter_role TEXT NOT NULL CHECK (reporter_role IN ('passenger', 'driver')),
    reported_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    reported_role TEXT NOT NULL CHECK (reported_role IN ('passenger', 'driver')),
    passenger_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    passenger_name TEXT,
    passenger_phone TEXT,
    driver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    driver_name TEXT,
    driver_phone TEXT,
    trip_status TEXT, -- 'in_progress', 'completed', 'cancelled'
    pickup_address TEXT,
    destination_address TEXT,
    fare NUMERIC(10, 2),
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    admin_notes TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Fast query indexes
CREATE INDEX IF NOT EXISTS idx_trip_reports_trip_id ON public.trip_reports(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_reports_reporter ON public.trip_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_trip_reports_reported ON public.trip_reports(reported_id);
CREATE INDEX IF NOT EXISTS idx_trip_reports_status ON public.trip_reports(status);
CREATE INDEX IF NOT EXISTS idx_trip_reports_created ON public.trip_reports(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.trip_reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow select for all on trip_reports" ON public.trip_reports;
DROP POLICY IF EXISTS "Allow insert for all on trip_reports" ON public.trip_reports;
DROP POLICY IF EXISTS "Allow update for all on trip_reports" ON public.trip_reports;

-- Permissive policies for app users and admin dashboard (using anon/auth keys)
CREATE POLICY "Allow select for all on trip_reports"
ON public.trip_reports FOR SELECT
TO anon, authenticated, service_role
USING (true);

CREATE POLICY "Allow insert for all on trip_reports"
ON public.trip_reports FOR INSERT
TO anon, authenticated, service_role
WITH CHECK (true);

CREATE POLICY "Allow update for all on trip_reports"
ON public.trip_reports FOR UPDATE
TO anon, authenticated, service_role
USING (true)
WITH CHECK (true);

-- Enable Supabase Realtime
ALTER TABLE public.trip_reports REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'trip_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_reports;
  END IF;
END $$;
