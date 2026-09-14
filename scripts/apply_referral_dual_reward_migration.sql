-- ====================================================================
-- SUPABASE MIGRATION: REFERRAL SYSTEM WITH DUAL REWARDS AFTER 1ST RIDE
-- Project: inRide App 2026
-- Description:
--  1. Ensures rider_welcome_bonus exists in rewards_settings.
--  2. Ensures unique referral codes for all users.
--  3. apply_referral_code RPC with anti-fraud (cannot apply after trips completed).
--  4. handle_referral_and_missions_on_trip_completed:
--     Credits BOTH referrer and referee upon completing the 1st trip.
--  5. get_user_referral_summary RPC for fast mobile app loading.
-- ====================================================================

-- 1. Ensure columns exist on rewards_settings
ALTER TABLE public.rewards_settings 
ADD COLUMN IF NOT EXISTS rider_welcome_bonus NUMERIC(10,2) NOT NULL DEFAULT 15.00;

-- 2. Ensure columns on referrals table
ALTER TABLE public.referrals
ADD COLUMN IF NOT EXISTS welcome_bonus_amount NUMERIC(10,2) NOT NULL DEFAULT 15.00;

-- 3. Generator for clean referral codes
CREATE OR REPLACE FUNCTION public.generate_unique_referral_code()
RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code TEXT;
  v_exists BOOLEAN;
  v_i INT;
BEGIN
  LOOP
    v_code := 'IR';
    FOR v_i IN 1..5 LOOP
      v_code := v_code || SUBSTR(v_chars, FLOOR(RANDOM() * LENGTH(v_chars) + 1)::INT, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM public.users WHERE UPPER(referral_code) = UPPER(v_code)) INTO v_exists;
    IF NOT v_exists THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Backfill any user without a referral code
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.users WHERE referral_code IS NULL OR referral_code = '' LOOP
    UPDATE public.users 
    SET referral_code = public.generate_unique_referral_code() 
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- 5. Trigger for new users
CREATE OR REPLACE FUNCTION public.set_user_referral_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
    NEW.referral_code := public.generate_unique_referral_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_user_referral_code ON public.users;
CREATE TRIGGER trg_set_user_referral_code
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_user_referral_code();

-- 6. RPC: Apply referral code
CREATE OR REPLACE FUNCTION public.apply_referral_code(
  p_referred_id UUID,
  p_code TEXT,
  p_user_type TEXT DEFAULT 'rider'
)
RETURNS JSONB AS $$
DECLARE
  v_settings RECORD;
  v_referrer RECORD;
  v_clean_code TEXT;
  v_target_trips INT;
  v_reward_amount NUMERIC;
  v_welcome_amount NUMERIC;
BEGIN
  SELECT * INTO v_settings FROM public.rewards_settings WHERE id = 'default';
  IF v_settings IS NOT NULL AND NOT v_settings.is_referral_active THEN
    RETURN jsonb_build_object('success', false, 'message', 'نظام الإحالات متوقف حالياً من إدارة التطبيق');
  END IF;

  v_clean_code := UPPER(TRIM(p_code));

  -- Look up referrer
  SELECT * INTO v_referrer FROM public.users WHERE UPPER(referral_code) = v_clean_code;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'كود الدعوة غير صحيح أو غير موجود');
  END IF;

  IF v_referrer.id = p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكنك استخدام كود الدعوة الخاص بك');
  END IF;

  IF EXISTS(SELECT 1 FROM public.referrals WHERE referred_id = p_referred_id) THEN
    RETURN jsonb_build_object('success', false, 'message', 'تم استخدام كود دعوة لهذا الحساب مسبقاً');
  END IF;

  IF LOWER(p_user_type) = 'driver' THEN
    v_target_trips := COALESCE(v_settings.driver_referral_target_trips, 5);
    v_reward_amount := COALESCE(v_settings.driver_referral_bonus, 100.00);
    v_welcome_amount := COALESCE(v_settings.driver_welcome_bonus, 50.00);
  ELSE
    -- Anti-fraud: ensure rider hasn't already completed trips prior to applying referral code
    IF EXISTS(
      SELECT 1 FROM public.ride_requests 
      WHERE passenger_id = p_referred_id AND LOWER(COALESCE(status, '')) IN ('completed', 'finished')
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'عفواً، لا يمكن تطبيق كود الدعوة بعد إتمام رحلات بالفعل');
    END IF;

    v_target_trips := COALESCE(v_settings.rider_referral_target_trips, 1);
    v_reward_amount := COALESCE(v_settings.rider_referral_bonus, 20.00);
    v_welcome_amount := COALESCE(v_settings.rider_welcome_bonus, 15.00);
  END IF;

  INSERT INTO public.referrals (
    referrer_id,
    referred_id,
    referral_code,
    user_type,
    status,
    target_trips,
    completed_trips,
    reward_amount,
    welcome_bonus_amount
  ) VALUES (
    v_referrer.id,
    p_referred_id,
    v_clean_code,
    LOWER(p_user_type),
    'pending',
    v_target_trips,
    0,
    v_reward_amount,
    v_welcome_amount
  );

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم تفعيل كود الدعوة بنجاح! سيتم إضافة الرصيد لك ولمن دعاك فور إتمام رحلتك الأولى بنجاح.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Trigger function: Auto-reward on Trip Completion
CREATE OR REPLACE FUNCTION public.handle_referral_and_missions_on_trip_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_settings RECORD;
  v_driver_id UUID := NEW.driver_id;
  v_passenger_id UUID := NEW.passenger_id;
  v_ref RECORD;
  v_mission RECORD;
  v_new_bal NUMERIC;
  v_new_passenger_bal NUMERIC;
BEGIN
  IF LOWER(COALESCE(NEW.status, '')) NOT IN ('completed', 'finished') THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_settings FROM public.rewards_settings WHERE id = 'default';
  IF v_settings IS NULL THEN
    INSERT INTO public.rewards_settings(id) VALUES ('default') ON CONFLICT (id) DO NOTHING;
    SELECT * INTO v_settings FROM public.rewards_settings WHERE id = 'default';
  END IF;

  -- --------------------------------------------------------
  -- A. Driver Daily Mission
  -- --------------------------------------------------------
  IF v_driver_id IS NOT NULL AND (v_settings.is_missions_active IS TRUE) THEN
    INSERT INTO public.driver_mission_progress (
      driver_id,
      mission_date,
      target_trips,
      completed_trips,
      reward_amount
    ) VALUES (
      v_driver_id,
      CURRENT_DATE,
      COALESCE(v_settings.daily_mission_trips, 8),
      0,
      COALESCE(v_settings.daily_mission_reward, 80.00)
    )
    ON CONFLICT (driver_id, mission_date) DO NOTHING;

    UPDATE public.driver_mission_progress
    SET 
      completed_trips = completed_trips + 1,
      updated_at = NOW()
    WHERE driver_id = v_driver_id 
      AND mission_date = CURRENT_DATE
      AND is_rewarded = FALSE
    RETURNING * INTO v_mission;

    IF v_mission IS NOT NULL AND v_mission.completed_trips >= v_mission.target_trips AND v_mission.is_rewarded = FALSE THEN
      UPDATE public.driver_mission_progress
      SET 
        is_completed = TRUE,
        is_rewarded = TRUE,
        rewarded_at = NOW()
      WHERE id = v_mission.id;

      UPDATE public.users
      SET driver_wallet_balance = COALESCE(driver_wallet_balance, 0) + v_mission.reward_amount
      WHERE id = v_driver_id
      RETURNING driver_wallet_balance INTO v_new_bal;

      INSERT INTO public.transactions (
        id, user_id, title, amount, type, balance_after, payment_method, notes, created_at
      ) VALUES (
        gen_random_uuid(),
        v_driver_id,
        'بونص إنجاز تحدي اليوم 🏆',
        v_mission.reward_amount,
        'bonus',
        v_new_bal,
        'wallet',
        'مكافأة إتمام ' || v_mission.target_trips || ' رحلات لليوم ' || CURRENT_DATE::text,
        NOW()
      );
    END IF;
  END IF;

  -- --------------------------------------------------------
  -- B. Driver Referral Reward
  -- --------------------------------------------------------
  IF v_driver_id IS NOT NULL AND (v_settings.is_referral_active IS TRUE) THEN
    SELECT * INTO v_ref 
    FROM public.referrals
    WHERE referred_id = v_driver_id AND user_type = 'driver' AND status = 'pending';

    IF FOUND THEN
      UPDATE public.referrals
      SET completed_trips = completed_trips + 1
      WHERE id = v_ref.id
      RETURNING * INTO v_ref;

      IF v_ref.completed_trips >= v_ref.target_trips THEN
        -- Credit referrer
        UPDATE public.users
        SET driver_wallet_balance = COALESCE(driver_wallet_balance, 0) + v_ref.reward_amount
        WHERE id = v_ref.referrer_id
        RETURNING driver_wallet_balance INTO v_new_bal;

        INSERT INTO public.transactions (
          id, user_id, title, amount, type, balance_after, payment_method, notes, created_at
        ) VALUES (
          gen_random_uuid(),
          v_ref.referrer_id,
          'مكافأة دعوة كابتن جديد 🎁',
          v_ref.reward_amount,
          'bonus',
          v_new_bal,
          'wallet',
          'مكافأة إكمال الكابتن المدعو ' || v_ref.target_trips || ' رحلات بنجاح',
          NOW()
        );

        -- Optional welcome bonus for referred driver
        IF v_ref.welcome_bonus_amount > 0 THEN
          UPDATE public.users
          SET driver_wallet_balance = COALESCE(driver_wallet_balance, 0) + v_ref.welcome_bonus_amount
          WHERE id = v_driver_id
          RETURNING driver_wallet_balance INTO v_new_bal;

          INSERT INTO public.transactions (
            id, user_id, title, amount, type, balance_after, payment_method, notes, created_at
          ) VALUES (
            gen_random_uuid(),
            v_driver_id,
            'بونص ترحيبي للتسجيل بكود دعوة 🎉',
            v_ref.welcome_bonus_amount,
            'bonus',
            v_new_bal,
            'wallet',
            'هدية ترحيبية من inRide بعد إتمام الرحلات المطلوبة',
            NOW()
          );
        END IF;

        UPDATE public.referrals
        SET status = 'rewarded', rewarded_at = NOW()
        WHERE id = v_ref.id;
      END IF;
    END IF;
  END IF;

  -- --------------------------------------------------------
  -- C. Rider Referral Reward (Dual Reward: Referrer + Referee)
  -- --------------------------------------------------------
  IF v_passenger_id IS NOT NULL AND (v_settings.is_referral_active IS TRUE) THEN
    SELECT * INTO v_ref 
    FROM public.referrals
    WHERE referred_id = v_passenger_id AND user_type = 'rider' AND status = 'pending';

    IF FOUND THEN
      UPDATE public.referrals
      SET completed_trips = completed_trips + 1
      WHERE id = v_ref.id
      RETURNING * INTO v_ref;

      IF v_ref.completed_trips >= v_ref.target_trips THEN
        -- 1. Credit Referrer (الداعي)
        UPDATE public.users
        SET 
          wallet_balance = COALESCE(wallet_balance, 0) + v_ref.reward_amount,
          passenger_wallet_balance = COALESCE(passenger_wallet_balance, wallet_balance, 0) + v_ref.reward_amount
        WHERE id = v_ref.referrer_id
        RETURNING wallet_balance INTO v_new_bal;

        INSERT INTO public.transactions (
          id, user_id, title, amount, type, balance_after, payment_method, notes, created_at
        ) VALUES (
          gen_random_uuid(),
          v_ref.referrer_id,
          'مكافأة دعوة صديق 🎁',
          v_ref.reward_amount,
          'bonus',
          v_new_bal,
          'wallet',
          'مكافأة دعوة صديق أتم أول رحلة بنجاح',
          NOW()
        );

        -- Notification to Referrer
        BEGIN
          INSERT INTO public.notifications (
            user_id, title, body, type, is_read, data, created_at
          ) VALUES (
            v_ref.referrer_id,
            'مكافأة دعوة صديق 🎁',
            'تهانينا! أتم صديقك أول رحلة، وتمت إضافة ' || v_ref.reward_amount || ' ج.م إلى محفظتك بنجاح!',
            'wallet',
            FALSE,
            jsonb_build_object('amount', v_ref.reward_amount, 'type', 'referral_bonus'),
            NOW()
          );
        EXCEPTION WHEN OTHERS THEN
          NULL;
        END;

        -- 2. Credit Referee (المدعو - الراكب الجديد)
        IF v_ref.welcome_bonus_amount > 0 THEN
          UPDATE public.users
          SET 
            wallet_balance = COALESCE(wallet_balance, 0) + v_ref.welcome_bonus_amount,
            passenger_wallet_balance = COALESCE(passenger_wallet_balance, wallet_balance, 0) + v_ref.welcome_bonus_amount
          WHERE id = v_passenger_id
          RETURNING wallet_balance INTO v_new_passenger_bal;

          INSERT INTO public.transactions (
            id, user_id, title, amount, type, balance_after, payment_method, notes, created_at
          ) VALUES (
            gen_random_uuid(),
            v_passenger_id,
            'هدية ترحيبية بكود الدعوة 🎉',
            v_ref.welcome_bonus_amount,
            'bonus',
            v_new_passenger_bal,
            'wallet',
            'رصيد مجاني ترحيبي بعد إتمام رحلتك الأولى بنجاح',
            NOW()
          );

          -- Notification to Referee
          BEGIN
            INSERT INTO public.notifications (
              user_id, title, body, type, is_read, data, created_at
            ) VALUES (
              v_passenger_id,
              'هدية ترحيبية من inRide 🎉',
              'تهانينا على إتمام رحلتك الأولى! تمت إضافة ' || v_ref.welcome_bonus_amount || ' ج.م كرصيد مجاني في محفظتك!',
              'wallet',
              FALSE,
              jsonb_build_object('amount', v_ref.welcome_bonus_amount, 'type', 'welcome_bonus'),
              NOW()
            );
          EXCEPTION WHEN OTHERS THEN
            NULL;
          END;
        END IF;

        UPDATE public.referrals
        SET status = 'rewarded', rewarded_at = NOW()
        WHERE id = v_ref.id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger
DROP TRIGGER IF EXISTS trg_handle_referral_and_missions ON public.ride_requests;
CREATE TRIGGER trg_handle_referral_and_missions
AFTER UPDATE OF status ON public.ride_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_referral_and_missions_on_trip_completed();

-- 8. Fast User Referral Summary for Profile & Invite Screens
CREATE OR REPLACE FUNCTION public.get_user_referral_summary(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user RECORD;
  v_settings RECORD;
  v_total_invites INT := 0;
  v_completed_invites INT := 0;
  v_total_earned NUMERIC(10,2) := 0.00;
  v_redeemed RECORD;
  v_code TEXT;
BEGIN
  -- Ensure user has unique referral code
  SELECT id, referral_code INTO v_user FROM public.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المستخدم غير موجود');
  END IF;

  IF v_user.referral_code IS NULL OR v_user.referral_code = '' THEN
    v_code := public.generate_unique_referral_code();
    UPDATE public.users SET referral_code = v_code WHERE id = p_user_id;
  ELSE
    v_code := v_user.referral_code;
  END IF;

  -- Fetch system settings
  SELECT * INTO v_settings FROM public.rewards_settings WHERE id = 'default';

  -- Calculate stats where this user is referrer
  SELECT 
    COUNT(*)::INT,
    COALESCE(COUNT(*) FILTER (WHERE status = 'rewarded'), 0)::INT,
    COALESCE(SUM(reward_amount) FILTER (WHERE status = 'rewarded'), 0.00)
  INTO v_total_invites, v_completed_invites, v_total_earned
  FROM public.referrals
  WHERE referrer_id = p_user_id;

  -- Check if this user was referred by someone
  SELECT * INTO v_redeemed FROM public.referrals WHERE referred_id = p_user_id LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'referral_code', v_code,
    'total_invites', v_total_invites,
    'completed_invites', v_completed_invites,
    'total_earned', v_total_earned,
    'is_referral_active', COALESCE(v_settings.is_referral_active, true),
    'rider_referral_bonus', COALESCE(v_settings.rider_referral_bonus, 20.00),
    'rider_welcome_bonus', COALESCE(v_settings.rider_welcome_bonus, 15.00),
    'has_redeemed_code', (v_redeemed.id IS NOT NULL),
    'redeemed_code', v_redeemed.referral_code,
    'redeemed_status', COALESCE(v_redeemed.status, 'none'),
    'redeemed_welcome_bonus', COALESCE(v_redeemed.welcome_bonus_amount, 0.00)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_user_referral_summary(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(UUID, TEXT, TEXT) TO anon, authenticated, service_role;
