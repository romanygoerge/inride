-- ====================================================================
-- SUPABASE MIGRATION: REFERRALS & DRIVER MISSIONS SYSTEM
-- Project: inRide App 2026
-- ====================================================================

-- 1. Ensure wallet and referral_code columns in users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_wallet_balance NUMERIC(10,2) DEFAULT 0.00;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS passenger_wallet_balance NUMERIC(10,2) DEFAULT 0.00;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS referral_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_referral_code 
ON public.users(referral_code) WHERE referral_code IS NOT NULL;

-- 2. Generator for clean referral codes
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

-- Populate existing users who don't have referral code
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

-- Trigger to auto-generate referral code on new user insert
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

-- 3. Settings table for Master Toggles and Rule Configuration
CREATE TABLE IF NOT EXISTS public.rewards_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  is_referral_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_missions_active BOOLEAN NOT NULL DEFAULT TRUE,
  driver_referral_bonus NUMERIC(10,2) NOT NULL DEFAULT 100.00,
  driver_referral_target_trips INT NOT NULL DEFAULT 5,
  driver_welcome_bonus NUMERIC(10,2) NOT NULL DEFAULT 50.00,
  rider_referral_bonus NUMERIC(10,2) NOT NULL DEFAULT 20.00,
  rider_referral_target_trips INT NOT NULL DEFAULT 1,
  daily_mission_trips INT NOT NULL DEFAULT 8,
  daily_mission_reward NUMERIC(10,2) NOT NULL DEFAULT 80.00,
  daily_mission_min_hours NUMERIC(4,1) NOT NULL DEFAULT 0.0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by TEXT DEFAULT 'admin'
);

INSERT INTO public.rewards_settings (id) 
VALUES ('default') 
ON CONFLICT (id) DO NOTHING;

-- 4. Referrals tracking table
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL,
  user_type TEXT NOT NULL DEFAULT 'driver', -- 'driver' or 'rider'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'rewarded'
  target_trips INT NOT NULL DEFAULT 5,
  completed_trips INT NOT NULL DEFAULT 0,
  reward_amount NUMERIC(10,2) NOT NULL DEFAULT 100.00,
  welcome_bonus_amount NUMERIC(10,2) NOT NULL DEFAULT 50.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  rewarded_at TIMESTAMPTZ,
  notes TEXT,
  CONSTRAINT uq_referred_user UNIQUE (referred_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- 5. Driver Daily Mission Progress table
CREATE TABLE IF NOT EXISTS public.driver_mission_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  mission_date DATE NOT NULL DEFAULT CURRENT_DATE,
  target_trips INT NOT NULL DEFAULT 8,
  completed_trips INT NOT NULL DEFAULT 0,
  reward_amount NUMERIC(10,2) NOT NULL DEFAULT 80.00,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  is_rewarded BOOLEAN NOT NULL DEFAULT FALSE,
  rewarded_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_driver_daily_mission UNIQUE (driver_id, mission_date)
);

CREATE INDEX IF NOT EXISTS idx_mission_driver_date ON public.driver_mission_progress(driver_id, mission_date);

-- 6. RPC: Apply referral code during registration
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
    RETURN jsonb_build_object('success', false, 'message', 'نظام الإحالات متوقف حالياً');
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
    v_target_trips := COALESCE(v_settings.rider_referral_target_trips, 1);
    v_reward_amount := COALESCE(v_settings.rider_referral_bonus, 20.00);
    v_welcome_amount := 0.00;
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
    'message', 'تم تفعيل كود الدعوة بنجاح! سيتم إضافة المكافأة بعد إتمام ' || v_target_trips || ' رحلات.'
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
  -- C. Rider Referral Reward
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
        -- Credit referrer
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

-- 8. Enable Row Level Security (RLS)
ALTER TABLE public.rewards_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_mission_progress ENABLE ROW LEVEL SECURITY;

-- Allow public read on rewards_settings so apps know whether rewards are active
DROP POLICY IF EXISTS "Public read rewards_settings" ON public.rewards_settings;
CREATE POLICY "Public read rewards_settings" ON public.rewards_settings
FOR SELECT USING (true);

-- Allow admins full access on rewards_settings
DROP POLICY IF EXISTS "Admins manage rewards_settings" ON public.rewards_settings;
CREATE POLICY "Admins manage rewards_settings" ON public.rewards_settings
FOR ALL USING (true) WITH CHECK (true);

-- Allow users to see their referrals
DROP POLICY IF EXISTS "Users read own referrals" ON public.referrals;
CREATE POLICY "Users read own referrals" ON public.referrals
FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Admins manage referrals" ON public.referrals;
CREATE POLICY "Admins manage referrals" ON public.referrals
FOR ALL USING (true) WITH CHECK (true);

-- Allow drivers to read their mission progress
DROP POLICY IF EXISTS "Drivers read own mission progress" ON public.driver_mission_progress;
CREATE POLICY "Drivers read own mission progress" ON public.driver_mission_progress
FOR SELECT USING (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Admins manage mission progress" ON public.driver_mission_progress;
CREATE POLICY "Admins manage mission progress" ON public.driver_mission_progress
FOR ALL USING (true) WITH CHECK (true);
