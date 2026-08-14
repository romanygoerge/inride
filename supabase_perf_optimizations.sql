-- ====================================================================
-- SUPABASE PERFORMANCE OPTIMIZATION SCRIPT FOR INRIDE APP
-- Highly optimized composite indexes, RLS query tuning, and RPC lock optimizations
-- ====================================================================

-- 1. COMPOSITE INDEXES FOR RIDE REQUESTS (HIGH CONCURRENCY MATCHING)
CREATE INDEX IF NOT EXISTS idx_ride_requests_status_created 
  ON public.ride_requests(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ride_requests_passenger_status 
  ON public.ride_requests(passenger_id, status);

CREATE INDEX IF NOT EXISTS idx_ride_requests_driver_status 
  ON public.ride_requests(driver_id, status);

-- 2. COMPOSITE INDEXES FOR DRIVER SEARCH & REALTIME PINGS
CREATE INDEX IF NOT EXISTS idx_drivers_online_avail_coords 
  ON public.drivers(is_online, is_available, current_latitude, current_longitude);

CREATE INDEX IF NOT EXISTS idx_drivers_updated_at 
  ON public.drivers(updated_at DESC);

-- 3. COMPOSITE INDEXES FOR RIDE OFFERS & CHAT MESSAGES
CREATE INDEX IF NOT EXISTS idx_ride_offers_req_status 
  ON public.ride_offers(request_id, status);

CREATE INDEX IF NOT EXISTS idx_chat_messages_req_created 
  ON public.chat_messages(request_id, created_at ASC);

-- 4. FINANCIAL TRANSACTIONS & NOTIFICATIONS INDEXES
CREATE INDEX IF NOT EXISTS idx_transactions_user_created 
  ON public.transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
  ON public.notifications(user_id, is_read, created_at DESC);

-- 5. ATOMIC RIDE ACCEPTANCE RPC WITH HIGH-CONCURRENCY LOCK TUNING
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
    v_final_fare NUMERIC;
    v_existing_offer_id UUID;
BEGIN
    -- Fast non-blocking check first
    SELECT * INTO v_request 
    FROM public.ride_requests 
    WHERE id = p_request_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'REQUEST_NOT_FOUND',
            'message', 'طلب الرحلة غير موجود'
        );
    END IF;

    IF LOWER(TRIM(COALESCE(v_request.status, ''))) NOT IN ('pending', 'searching') THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'RIDE_ALREADY_TAKEN',
            'message', 'عفواً، هذه الرحلة لم تعد متاحة أو تم قبولها من كابتن آخر'
        );
    END IF;

    -- Now lock ride request atomically FOR UPDATE
    SELECT * INTO v_request 
    FROM public.ride_requests 
    WHERE id = p_request_id 
    FOR UPDATE NOWAIT;

    -- Lock driver record safely
    UPDATE public.drivers
    SET is_available = false, updated_at = NOW()
    WHERE id = p_driver_id;

    IF NOT FOUND THEN
        INSERT INTO public.drivers (id, is_online, is_available, verification_status)
        VALUES (p_driver_id, true, false, 'verified')
        ON CONFLICT (id) DO UPDATE SET is_available = false, updated_at = NOW();
    END IF;

    v_final_fare := COALESCE(p_offered_fare, v_request.offered_fare, 0.0);

    -- Update ride request status to Accepted
    UPDATE public.ride_requests
    SET status = 'Accepted', driver_id = p_driver_id, offered_fare = v_final_fare
    WHERE id = p_request_id;

    -- Update offer status if present
    UPDATE public.ride_offers
    SET status = 'accepted', price = v_final_fare
    WHERE request_id = p_request_id AND driver_id = p_driver_id;

    RETURN jsonb_build_object(
        'success', true,
        'code', 'RIDE_ACCEPTED',
        'message', 'تم قبول الرحلة بنجاح',
        'request_id', p_request_id,
        'driver_id', p_driver_id,
        'fare', v_final_fare
    );

EXCEPTION
    WHEN lock_not_available THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'RIDE_ALREADY_TAKEN',
            'message', 'تم تقديم طلب قبول متزامن من كابتن آخر'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'ERROR',
            'message', SQLERRM
        );
END;
$$;

-- 6. UPDATE QUERY STATISTICS FOR POSTGRES QUERY PLANNER
ANALYZE public.users;
ANALYZE public.drivers;
ANALYZE public.ride_requests;
ANALYZE public.ride_offers;
ANALYZE public.transactions;
ANALYZE public.chat_messages;
ANALYZE public.notifications;
