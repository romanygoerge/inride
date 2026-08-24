-- ================================================================
-- Supabase Migration: Demo Account System & Realtime Management
-- Allows instant testing for Captains & Passengers without admin review
-- ================================================================

-- 1. Extend app_settings with Demo Mode parameters
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_mode_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_phone TEXT DEFAULT '01000000000';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_otp TEXT DEFAULT '123456';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_driver_name TEXT DEFAULT 'كابتن تجريبي (Demo)';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_passenger_name TEXT DEFAULT 'راكب تجريبي (Demo)';

-- 2. Initialize or Update default configuration
UPDATE public.app_settings 
SET 
  demo_mode_enabled = COALESCE(demo_mode_enabled, true),
  demo_phone = COALESCE(demo_phone, '01000000000'),
  demo_otp = COALESCE(demo_otp, '123456'),
  demo_driver_name = COALESCE(demo_driver_name, 'كابتن تجريبي (Demo)'),
  demo_passenger_name = COALESCE(demo_passenger_name, 'راكب تجريبي (Demo)')
WHERE id = 'default';

-- 3. Stored Procedure: setup_or_reset_demo_account
CREATE OR REPLACE FUNCTION public.setup_or_reset_demo_account(
    p_role text DEFAULT 'driver',
    p_phone text DEFAULT '01000000000',
    p_name text DEFAULT 'حساب تجريبي (Demo)'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_user_id_str text;
    v_email text;
    v_cleaned_phone text;
    v_e164_phone text;
BEGIN
    v_cleaned_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF length(v_cleaned_phone) = 11 AND v_cleaned_phone LIKE '0%' THEN
        v_cleaned_phone := substr(v_cleaned_phone, 2);
    END IF;
    v_e164_phone := '+20' || v_cleaned_phone;
    v_email := 'phone_20' || v_cleaned_phone || '@inride.app';

    -- Find existing auth user ID if exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
    
    IF v_user_id IS NULL THEN
        -- If current caller is authenticated
        IF auth.uid() IS NOT NULL THEN
            v_user_id := auth.uid();
        ELSE
            RETURN json_build_object('success', true, 'status', 'auth_pending_creation', 'email', v_email);
        END IF;
    END IF;

    v_user_id_str := v_user_id::text;

    -- Upsert in users table
    INSERT INTO public.users (
        id, name, phone_number, email, role, rating, wallet_balance, driver_wallet_balance, status, created_at, updated_at
    ) VALUES (
        v_user_id_str,
        p_name,
        v_e164_phone,
        v_email,
        CASE WHEN p_role = 'driver' THEN 'driver' ELSE 'rider' END,
        5.00,
        500.00,
        500.00,
        'active',
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        phone_number = EXCLUDED.phone_number,
        role = EXCLUDED.role,
        status = 'active',
        wallet_balance = GREATEST(users.wallet_balance, 500.00),
        driver_wallet_balance = GREATEST(COALESCE(users.driver_wallet_balance, 0), 500.00),
        updated_at = NOW();

    -- Upsert in profiles table
    INSERT INTO public.profiles (
        id, full_name, email, phone, role, created_at, updated_at
    ) VALUES (
        v_user_id_str,
        p_name,
        v_email,
        v_e164_phone,
        CASE WHEN p_role = 'driver' THEN 'captain' ELSE 'user' END,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        updated_at = NOW();

    IF p_role = 'driver' THEN
        -- Upsert in drivers table with VERIFIED status
        INSERT INTO public.drivers (
            id, name, phone, email, verification_status, is_online, is_approved, rating, total_trips, total_earnings, wallet_balance, vehicle_type, vehicle_name, license_plate, created_at, updated_at
        ) VALUES (
            v_user_id_str,
            p_name,
            v_e164_phone,
            v_email,
            'verified',
            true,
            true,
            5.00,
            12,
            1500.00,
            500.00,
            'car',
            'تويوتا كورولا 2024',
            'أ ب ج 1234',
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            phone = EXCLUDED.phone,
            verification_status = 'verified',
            is_approved = true,
            updated_at = NOW();

        -- Upsert a verified vehicle for the demo driver
        INSERT INTO public.vehicles (
            id, driver_id, vehicle_category, type, model, color, number_plate, is_verified, status, created_at, updated_at
        ) VALUES (
            'veh_' || substr(v_user_id_str, 1, 8),
            v_user_id_str,
            'car',
            'car',
            'تويوتا كورولا 2024',
            'أبيض لؤلؤي',
            'أ ب ج 1234',
            true,
            'active',
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            is_verified = true,
            status = 'active',
            updated_at = NOW();

    ELSE
        -- Upsert in passengers table
        INSERT INTO public.passengers (
            id, name, phone, email, rating, total_trips, total_spent, wallet_balance, created_at, updated_at
        ) VALUES (
            v_user_id_str,
            p_name,
            v_e164_phone,
            v_email,
            5.00,
            8,
            650.00,
            500.00,
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            phone = EXCLUDED.phone,
            wallet_balance = GREATEST(passengers.wallet_balance, 500.00),
            updated_at = NOW();
    END IF;

    RETURN json_build_object(
        'success', true,
        'user_id', v_user_id_str,
        'role', p_role,
        'verification_status', 'verified',
        'message', 'Demo account prepared and verified successfully'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_or_reset_demo_account(text, text, text) TO anon, authenticated, service_role;

-- 4. Stored Procedure: purge_demo_account
CREATE OR REPLACE FUNCTION public.purge_demo_account(
    p_phone text DEFAULT '01000000000'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_user_id_str text;
    v_cleaned_phone text;
    v_email text;
BEGIN
    v_cleaned_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF length(v_cleaned_phone) = 11 AND v_cleaned_phone LIKE '0%' THEN
        v_cleaned_phone := substr(v_cleaned_phone, 2);
    END IF;
    v_email := 'phone_20' || v_cleaned_phone || '@inride.app';

    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
    
    IF v_user_id IS NOT NULL THEN
        v_user_id_str := v_user_id::text;
        DELETE FROM public.driver_locations WHERE driver_id = v_user_id_str;
        DELETE FROM public.driver_documents WHERE driver_id = v_user_id_str;
        DELETE FROM public.vehicles WHERE driver_id = v_user_id_str;
        DELETE FROM public.drivers WHERE id = v_user_id_str;
        DELETE FROM public.passengers WHERE id = v_user_id_str;
        DELETE FROM public.profiles WHERE id = v_user_id_str;
        DELETE FROM public.users WHERE id = v_user_id_str;
        DELETE FROM auth.users WHERE id = v_user_id;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Demo account purged successfully');
END;
$$;

GRANT EXECUTE ON FUNCTION public.purge_demo_account(text) TO anon, authenticated, service_role;
