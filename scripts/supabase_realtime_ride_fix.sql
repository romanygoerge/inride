-- SQL Migration: Real-Time Ride Communication, Atomic RPC & RLS Fixes

-- 1. Ensure Table Replica Identity for Supabase Realtime WebSocket payloads
ALTER TABLE public.ride_requests REPLICA IDENTITY FULL;
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.users REPLICA IDENTITY FULL;

-- 2. Ensure tables are included in Supabase Realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'ride_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_requests;
    END IF;
END $$;

-- 3. Atomic Ride Acceptance Function with Row-Level Locking (FOR UPDATE)
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RLS Policies for ride_requests
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public ride_requests read" ON public.ride_requests;
DROP POLICY IF EXISTS "Passengers create ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Participants update ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Public ride_requests full access" ON public.ride_requests;

CREATE POLICY "Public ride_requests full access" ON public.ride_requests FOR ALL USING (true) WITH CHECK (true);
