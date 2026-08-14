-- ================================================================
-- Supabase RPC Function: delete_own_account
-- Purpose: Safely delete user account and associated personal data
-- while preserving past trip records for accounting & audit purposes.
-- ================================================================

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_user_id_str text;
    v_active_trips_count int;
BEGIN
    -- 1. Get authenticated user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    v_user_id_str := v_user_id::text;

    -- 2. Verify no active trips exist
    SELECT COUNT(*) INTO v_active_trips_count
    FROM public.ride_requests
    WHERE (passenger_id = v_user_id_str OR driver_id = v_user_id_str)
      AND status IN ('pending', 'searching', 'bidding', 'driver_bidding', 'accepted', 'driver_on_way', 'arrived', 'in_progress', 'trip_started');

    IF v_active_trips_count > 0 THEN
        RAISE EXCEPTION 'active_trip_exists';
    END IF;

    -- 3. Delete user notifications
    DELETE FROM public.notifications WHERE user_id = v_user_id_str;

    -- 4. Delete Push Notification Tokens
    DELETE FROM public.user_fcm_tokens WHERE user_id = v_user_id_str;
    DELETE FROM public.device_tokens WHERE user_id = v_user_id_str;

    -- 5. Delete Saved Addresses
    DELETE FROM public.saved_addresses WHERE user_id = v_user_id_str;

    -- 6. Delete Support Messages & Chats
    DELETE FROM public.support_messages WHERE sender_id = v_user_id_str;
    DELETE FROM public.support_chats WHERE user_id = v_user_id_str;

    -- 7. Delete Driver specific records if applicable
    DELETE FROM public.driver_locations WHERE driver_id = v_user_id_str OR user_id = v_user_id_str;
    DELETE FROM public.driver_documents WHERE driver_id = v_user_id_str OR user_id = v_user_id_str;
    DELETE FROM public.vehicles WHERE driver_id = v_user_id_str OR user_id = v_user_id_str;
    DELETE FROM public.drivers WHERE id = v_user_id_str OR user_id = v_user_id_str;
    DELETE FROM public.passengers WHERE id = v_user_id_str OR user_id = v_user_id_str;

    -- 8. Delete user profile record
    DELETE FROM public.users WHERE id = v_user_id_str;

    -- 9. Delete user from auth.users (requires SECURITY DEFINER)
    DELETE FROM auth.users WHERE id = v_user_id;

    RETURN json_build_object('success', true, 'message', 'Account deleted successfully');
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
