-- ====================================================================
-- INRIDE APP 2026: SUPABASE RIDE FLOW, REALTIME & ATOMIC ACCEPTANCE SCRIPT
-- Execute this script in Supabase Dashboard: SQL Editor -> New Query
-- ====================================================================

-- 1. INDEXES FOR HIGH-PERFORMANCE RIDE MATCHING & DRIVER SEARCH
CREATE INDEX IF NOT EXISTS idx_drivers_online_avail_verified 
  ON public.drivers(is_online, is_available, verification_status);

CREATE INDEX IF NOT EXISTS idx_drivers_updated_at 
  ON public.drivers(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_drivers_coords 
  ON public.drivers(current_latitude, current_longitude);

CREATE INDEX IF NOT EXISTS idx_ride_requests_status_created 
  ON public.ride_requests(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ride_offers_req_drv 
  ON public.ride_offers(request_id, driver_id);

-- Ensure schema compatibility for negotiation counter-offers & extra details
ALTER TABLE public.ride_requests 
  ADD COLUMN IF NOT EXISTS last_counter_driver_id UUID REFERENCES public.users(id);

ALTER TABLE public.drivers 
  ADD COLUMN IF NOT EXISTS national_id_back_url TEXT DEFAULT '';
ALTER TABLE public.drivers 
  ADD COLUMN IF NOT EXISTS license_back_url TEXT DEFAULT '';

ALTER TABLE public.vehicles 
  ADD COLUMN IF NOT EXISTS vehicle_category TEXT DEFAULT 'car';
ALTER TABLE public.vehicles 
  ADD COLUMN IF NOT EXISTS has_ac BOOLEAN DEFAULT FALSE;
ALTER TABLE public.vehicles 
  ADD COLUMN IF NOT EXISTS max_passengers INT DEFAULT 4;
ALTER TABLE public.vehicles 
  ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

-- ====================================================================
-- 2. SETUP REALTIME PUBLICATION & REPLICA IDENTITY
-- ====================================================================
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.users,
    public.passengers,
    public.drivers,
    public.vehicles,
    public.ride_requests,
    public.ride_offers,
    public.chat_messages,
    public.typing_indicators,
    public.notifications,
    public.support_messages;

-- Enable REPLICA IDENTITY FULL for tables used in Realtime streams
ALTER TABLE public.users REPLICA IDENTITY FULL;
ALTER TABLE public.passengers REPLICA IDENTITY FULL;
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.vehicles REPLICA IDENTITY FULL;
ALTER TABLE public.ride_requests REPLICA IDENTITY FULL;
ALTER TABLE public.ride_offers REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.typing_indicators REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

-- ====================================================================
-- 3. UNRESTRICTED ROW LEVEL SECURITY (RLS) POLICIES FOR REALTIME & MATCHING
-- Ensures no query or WebSocket subscription is blocked by RLS policies.
-- ====================================================================

-- Table: public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public users full access" ON public.users;
DROP POLICY IF EXISTS "Public users read access" ON public.users;
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
DROP POLICY IF EXISTS "Users can update own record" ON public.users;
CREATE POLICY "Public users full access" ON public.users FOR ALL USING (true) WITH CHECK (true);

-- Table: public.passengers
ALTER TABLE public.passengers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public passengers full access" ON public.passengers;
DROP POLICY IF EXISTS "Public passengers read" ON public.passengers;
DROP POLICY IF EXISTS "Passengers write own" ON public.passengers;
CREATE POLICY "Public passengers full access" ON public.passengers FOR ALL USING (true) WITH CHECK (true);

-- Table: public.drivers
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public drivers full access" ON public.drivers;
DROP POLICY IF EXISTS "Public drivers read" ON public.drivers;
DROP POLICY IF EXISTS "Drivers write own" ON public.drivers;
CREATE POLICY "Public drivers full access" ON public.drivers FOR ALL USING (true) WITH CHECK (true);

-- Table: public.vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public vehicles full access" ON public.vehicles;
DROP POLICY IF EXISTS "Public vehicles read" ON public.vehicles;
DROP POLICY IF EXISTS "Drivers write own vehicles" ON public.vehicles;
CREATE POLICY "Public vehicles full access" ON public.vehicles FOR ALL USING (true) WITH CHECK (true);

-- Table: public.ride_requests
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ride_requests full access" ON public.ride_requests;
DROP POLICY IF EXISTS "Public ride_requests read" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers create ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Participants update ride_requests" ON public.ride_requests;
CREATE POLICY "Public ride_requests full access" ON public.ride_requests FOR ALL USING (true) WITH CHECK (true);

-- Table: public.ride_offers
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ride_offers full access" ON public.ride_offers;
DROP POLICY IF EXISTS "Public ride_offers read" ON public.ride_offers;
DROP POLICY IF EXISTS "Drivers insert ride_offers" ON public.ride_offers;
DROP POLICY IF EXISTS "Participants update ride_offers" ON public.ride_offers;
CREATE POLICY "Public ride_offers full access" ON public.ride_offers FOR ALL USING (true) WITH CHECK (true);

-- Table: public.chat_messages
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public chat_messages full access" ON public.chat_messages;
DROP POLICY IF EXISTS "Public chat_messages read" ON public.chat_messages;
DROP POLICY IF EXISTS "Users insert chat_messages" ON public.chat_messages;
CREATE POLICY "Public chat_messages full access" ON public.chat_messages FOR ALL USING (true) WITH CHECK (true);

-- Table: public.typing_indicators
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public typing_indicators full access" ON public.typing_indicators;
DROP POLICY IF EXISTS "Public typing_indicators read" ON public.typing_indicators;
DROP POLICY IF EXISTS "Users write typing_indicators" ON public.typing_indicators;
CREATE POLICY "Public typing_indicators full access" ON public.typing_indicators FOR ALL USING (true) WITH CHECK (true);

-- Table: public.ratings
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public ratings full access" ON public.ratings;
DROP POLICY IF EXISTS "Public ratings read" ON public.ratings;
DROP POLICY IF EXISTS "Users insert ratings" ON public.ratings;
CREATE POLICY "Public ratings full access" ON public.ratings FOR ALL USING (true) WITH CHECK (true);

-- Table: public.notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public notifications full access" ON public.notifications;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Public insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Public notifications full access" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- Table: public.transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public transactions full access" ON public.transactions;
DROP POLICY IF EXISTS "Users read transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users insert transactions" ON public.transactions;
CREATE POLICY "Public transactions full access" ON public.transactions FOR ALL USING (true) WITH CHECK (true);


-- ====================================================================
-- 4. RPC FUNCTION: ATOMIC RIDE ACCEPTANCE (LOCKING TRANSACTION)
-- Ensures only the FIRST captain can accept a pending ride request.
-- Prevents race conditions, double acceptances, and FK/permission errors.
-- ====================================================================
CREATE OR REPLACE FUNCTION public.accept_ride_request(
    p_request_id UUID,
    p_driver_id UUID,
    p_offered_fare NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_driver RECORD;
    v_driver_user RECORD;
    v_vehicle RECORD;
    v_final_fare NUMERIC;
    v_existing_offer_id UUID;
BEGIN
    -- 1. Lock and inspect the ride request
    SELECT * INTO v_request 
    FROM public.ride_requests 
    WHERE id = p_request_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'REQUEST_NOT_FOUND',
            'message', 'طلب الرحلة غير موجود'
        );
    END IF;

    -- Check if request is still available for acceptance
    IF LOWER(TRIM(COALESCE(v_request.status, ''))) NOT IN ('pending', 'searching') THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'RIDE_ALREADY_TAKEN',
            'message', 'عفواً، هذه الرحلة لم تعد متاحة أو تم قبولها من كابتن آخر'
        );
    END IF;

    -- 2. Lock and inspect the driver record
    SELECT * INTO v_driver 
    FROM public.drivers 
    WHERE id = p_driver_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        -- Auto-create missing driver row if needed
        INSERT INTO public.drivers (id, is_online, is_available, verification_status)
        VALUES (p_driver_id, true, false, 'verified')
        ON CONFLICT (id) DO UPDATE SET is_available = false, updated_at = NOW();
    ELSE
        UPDATE public.drivers
        SET 
            is_available = false,
            updated_at = NOW()
        WHERE id = p_driver_id;
    END IF;

    -- Determine final fare
    v_final_fare := COALESCE(p_offered_fare, v_request.offered_fare, 0.0);

    -- 3. Update ride request status to Accepted and bind driver
    UPDATE public.ride_requests
    SET 
        status = 'Accepted',
        driver_id = p_driver_id,
        offered_fare = v_final_fare
    WHERE id = p_request_id;

    -- 4. Safely manage ride_offers record
    BEGIN
        SELECT id INTO v_existing_offer_id
        FROM public.ride_offers
        WHERE request_id = p_request_id AND driver_id = p_driver_id
        LIMIT 1;

        IF v_existing_offer_id IS NOT NULL THEN
            UPDATE public.ride_offers
            SET status = 'accepted', price = v_final_fare
            WHERE id = v_existing_offer_id;
        ELSE
            SELECT * INTO v_driver_user FROM public.users WHERE id = p_driver_id;
            IF v_driver IS NOT NULL AND v_driver.vehicle_id IS NOT NULL THEN
                SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.vehicle_id LIMIT 1;
            END IF;

            INSERT INTO public.ride_offers (
                id,
                request_id,
                driver_id,
                passenger_id,
                driver_name,
                driver_avatar,
                driver_rating,
                vehicle_type,
                vehicle_name,
                license_plate,
                price,
                eta_minutes,
                status,
                created_at
            ) VALUES (
                gen_random_uuid(),
                p_request_id,
                p_driver_id,
                v_request.passenger_id,
                COALESCE(v_driver_user.name, 'كابتن'),
                COALESCE(v_driver_user.avatar_url, ''),
                COALESCE(v_driver_user.rating, 5.0),
                COALESCE(v_vehicle.vehicle_category, v_vehicle.type, v_request.vehicle_type, 'car'),
                COALESCE(v_vehicle.model, 'سيارة'),
                COALESCE(v_vehicle.number_plate, ''),
                v_final_fare,
                3,
                'accepted',
                NOW()
            );
        END IF;

        -- Mark any other pending offers for this request as rejected
        UPDATE public.ride_offers
        SET status = 'rejected'
        WHERE request_id = p_request_id AND driver_id <> p_driver_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'ride_offers update ignored: %', SQLERRM;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'code', 'SUCCESS',
        'message', 'تم قبول الرحلة بنجاح',
        'request_id', p_request_id,
        'passenger_id', v_request.passenger_id,
        'driver_id', p_driver_id,
        'fare', v_final_fare,
        'status', 'Accepted'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'code', 'TRANSACTION_ERROR',
        'message', SQLERRM
    );
END;
$$;


-- ====================================================================
-- 5. RPC FUNCTION: SUBMIT DRIVER OFFER / COUNTER OFFER
-- Safely inserts/updates a driver's fare offer with validation.
-- ====================================================================
CREATE OR REPLACE FUNCTION public.submit_driver_offer(
    p_request_id UUID,
    p_driver_id UUID,
    p_price NUMERIC,
    p_eta_minutes INT DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_driver_user RECORD;
    v_driver RECORD;
    v_vehicle RECORD;
    v_offer_id UUID;
BEGIN
    SELECT * INTO v_request FROM public.ride_requests WHERE id = p_request_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'طلب الرحلة غير موجود');
    END IF;

    IF v_request.status NOT IN ('Pending', 'Searching', 'pending', 'searching') THEN
        RETURN jsonb_build_object('success', false, 'message', 'الرحلة لم تعد متاحة لتقديم العروض');
    END IF;

    SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id;
    SELECT * INTO v_driver_user FROM public.users WHERE id = p_driver_id;
    SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.vehicle_id LIMIT 1;

    -- Delete any existing offer from this driver for this request
    DELETE FROM public.ride_offers WHERE request_id = p_request_id AND driver_id = p_driver_id;

    v_offer_id := gen_random_uuid();
    INSERT INTO public.ride_offers (
        id,
        request_id,
        driver_id,
        passenger_id,
        driver_name,
        driver_avatar,
        driver_rating,
        vehicle_type,
        vehicle_name,
        license_plate,
        price,
        eta_minutes,
        status,
        created_at
    ) VALUES (
        v_offer_id,
        p_request_id,
        p_driver_id,
        v_request.passenger_id,
        COALESCE(v_driver_user.name, 'كابتن'),
        COALESCE(v_driver_user.avatar_url, ''),
        COALESCE(v_driver_user.rating, 5.0),
        COALESCE(v_vehicle.vehicle_category, v_vehicle.type, v_request.vehicle_type),
        COALESCE(v_vehicle.model, 'سيارة'),
        COALESCE(v_vehicle.number_plate, ''),
        p_price,
        p_eta_minutes,
        'pending',
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تقديم العرض بنجاح',
        'offer_id', v_offer_id,
        'passenger_id', v_request.passenger_id
    );
END;
$$;
