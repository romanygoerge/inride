-- ================================================================
-- Supabase Migration: Demo Account System & Realtime Management
-- Allows instant testing for Captains & Passengers without admin review
-- ================================================================

-- 1. Extend app_settings with Demo Mode parameters
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_mode_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_passenger_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_driver_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_phone TEXT DEFAULT '01000000000';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_otp TEXT DEFAULT '123456';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_driver_name TEXT DEFAULT 'كابتن تجريبي (Demo)';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS demo_passenger_name TEXT DEFAULT 'راكب تجريبي (Demo)';

-- 2. Initialize or Update default configuration
UPDATE public.app_settings 
SET 
  demo_mode_enabled = COALESCE(demo_mode_enabled, false),
  demo_passenger_enabled = COALESCE(demo_passenger_enabled, false),
  demo_driver_enabled = COALESCE(demo_driver_enabled, false),
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
    v_vehicle_id uuid;
    v_email text;
    v_cleaned_phone text;
    v_e164_phone text;
    v_role text;
BEGIN
    v_cleaned_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF length(v_cleaned_phone) = 11 AND v_cleaned_phone LIKE '0%' THEN
        v_cleaned_phone := substr(v_cleaned_phone, 2);
    END IF;
    v_e164_phone := '+20' || v_cleaned_phone;
    v_email := 'phone_20' || v_cleaned_phone || '@inride.app';
    v_role := CASE WHEN p_role = 'driver' THEN 'driver' ELSE 'rider' END;

    -- Find existing auth user ID if exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
    
    IF v_user_id IS NULL THEN
        IF auth.uid() IS NOT NULL THEN
            v_user_id := auth.uid();
        ELSE
            RETURN json_build_object('success', true, 'status', 'auth_pending_creation', 'email', v_email);
        END IF;
    END IF;

    -- Upsert in public.users table
    INSERT INTO public.users (
        id, name, phone_number, email, role, rating, wallet_balance, credit_limit, created_at, updated_at
    ) VALUES (
        v_user_id,
        p_name,
        v_e164_phone,
        v_email,
        v_role,
        5.00,
        500.00,
        -100.00,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        phone_number = EXCLUDED.phone_number,
        role = EXCLUDED.role,
        wallet_balance = GREATEST(COALESCE(users.wallet_balance, 0), 500.00),
        updated_at = NOW();

    IF v_role = 'driver' THEN
        SELECT id INTO v_vehicle_id FROM public.vehicles WHERE driver_id = v_user_id LIMIT 1;
        IF v_vehicle_id IS NULL THEN
            v_vehicle_id := gen_random_uuid();
            INSERT INTO public.vehicles (
                id, driver_id, model, number_plate, color, type, year, status, vehicle_category, has_ac, max_passengers, created_at
            ) VALUES (
                v_vehicle_id,
                v_user_id,
                'تويوتا كورولا 2024',
                'أ ب ج 1234',
                'أبيض لؤلؤي',
                'car',
                2024,
                'active',
                'car',
                true,
                4,
                NOW()
            );
        ELSE
            UPDATE public.vehicles SET
                model = 'تويوتا كورولا 2024',
                number_plate = 'أ ب ج 1234',
                color = 'أبيض لؤلؤي',
                type = 'car',
                vehicle_category = 'car',
                status = 'active',
                has_ac = true,
                max_passengers = 4
            WHERE id = v_vehicle_id;
        END IF;

        INSERT INTO public.drivers (
            id, is_online, is_available, verification_status, vehicle_id, rating, total_earnings, total_trips, national_id_url, license_url, vehicle_front_url, address, updated_at
        ) VALUES (
            v_user_id,
            true,
            true,
            'verified',
            v_vehicle_id,
            5.00,
            1500.00,
            12,
            'https://placehold.co/600x400.png?text=National+ID',
            'https://placehold.co/600x400.png?text=Driver+License',
            'https://placehold.co/600x400.png?text=Vehicle+Front',
            'مدينة السادات، المنوفية',
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            is_online = true,
            is_available = true,
            verification_status = 'verified',
            vehicle_id = v_vehicle_id,
            updated_at = NOW();
    ELSE
        INSERT INTO public.passengers (
            id, name, phone, email, rating, total_trips, address, gender, created_at
        ) VALUES (
            v_user_id,
            p_name,
            v_e164_phone,
            v_email,
            5.00,
            8,
            'مدينة السادات، المنوفية',
            'ذكر',
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            phone = EXCLUDED.phone,
            email = EXCLUDED.email,
            gender = 'ذكر';
    END IF;

    RETURN json_build_object(
        'success', true,
        'user_id', v_user_id::text,
        'role', v_role,
        'message', 'Demo account successfully configured and verified in DB'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_or_reset_demo_account(text, text, text) TO anon, authenticated, service_role;

-- 4. Stored Procedure: purge_demo_account
DROP FUNCTION IF EXISTS public.purge_demo_account(text);
DROP FUNCTION IF EXISTS public.purge_demo_account(text, boolean);

CREATE OR REPLACE FUNCTION public.purge_demo_account(
    p_phone text DEFAULT '01000000000',
    p_disable_feature boolean DEFAULT true
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_cleaned_phone text;
    v_email text;
BEGIN
    -- 1. Disable demo mode in app_settings if requested
    IF p_disable_feature THEN
        UPDATE public.app_settings 
        SET demo_mode_enabled = false, 
            demo_passenger_enabled = false,
            demo_driver_enabled = false,
            updated_at = NOW() 
        WHERE id = 'default';
    END IF;

    -- 2. Delete all records associated with demo phone
    v_cleaned_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF length(v_cleaned_phone) = 11 AND v_cleaned_phone LIKE '0%' THEN
        v_cleaned_phone := substr(v_cleaned_phone, 2);
    END IF;
    v_email := 'phone_20' || v_cleaned_phone || '@inride.app';

    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;
    
    IF v_user_id IS NOT NULL THEN
        DELETE FROM public.driver_locations WHERE driver_id = v_user_id::text;
        DELETE FROM public.driver_documents WHERE driver_id = v_user_id::text;
        DELETE FROM public.vehicles WHERE driver_id = v_user_id;
        DELETE FROM public.drivers WHERE id = v_user_id;
        DELETE FROM public.passengers WHERE id = v_user_id;
        BEGIN
            DELETE FROM public.profiles WHERE id = v_user_id::text;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        DELETE FROM public.users WHERE id = v_user_id;
        DELETE FROM auth.users WHERE id = v_user_id;
    END IF;

    RETURN json_build_object(
        'success', true, 
        'demo_mode_enabled', NOT p_disable_feature, 
        'message', 'Demo feature disabled and accounts purged successfully'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.purge_demo_account(text, boolean) TO anon, authenticated, service_role;
