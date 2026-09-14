-- ====================================================================
-- SUPABASE MIGRATION: DYNAMIC TIME-WINDOW / SHIFTS BONUS SYSTEM FOR DRIVERS
-- Project: inRide App 2026
-- Description:
--  1. Creates public.driver_mission_shifts table for managing custom time periods.
--  2. Updates driver_mission_progress to support shift-based missions.
--  3. Seeds default shift (07:00 AM to 12:00 PM, 5 trips, 50.00 EGP).
--  4. Updates handle_referral_and_missions_on_trip_completed trigger.
--  5. Creates get_active_driver_mission RPC for driver app UI.
-- ====================================================================

-- 1. Create table for Driver Time-Window Bonus Shifts
CREATE TABLE IF NOT EXISTS public.driver_mission_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL DEFAULT 'فترة الصباح',
  start_time TIME NOT NULL DEFAULT '07:00:00',
  end_time TIME NOT NULL DEFAULT '12:00:00',
  target_trips INT NOT NULL DEFAULT 5,
  reward_amount NUMERIC(10,2) NOT NULL DEFAULT 50.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default morning shift if empty
INSERT INTO public.driver_mission_shifts (title, start_time, end_time, target_trips, reward_amount, is_active)
SELECT 'فترة الصباح', '07:00:00'::TIME, '12:00:00'::TIME, 5, 50.00, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.driver_mission_shifts);

-- 2. Update driver_mission_progress schema
ALTER TABLE public.driver_mission_progress
ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES public.driver_mission_shifts(id) ON DELETE CASCADE;

ALTER TABLE public.driver_mission_progress
ADD COLUMN IF NOT EXISTS shift_title TEXT;

-- Drop old single-per-day unique constraint and replace with flexible index
ALTER TABLE public.driver_mission_progress DROP CONSTRAINT IF EXISTS uq_driver_daily_mission;
DROP INDEX IF EXISTS idx_uq_driver_mission_shift;
CREATE UNIQUE INDEX IF NOT EXISTS idx_uq_driver_mission_shift 
ON public.driver_mission_progress(driver_id, mission_date, COALESCE(shift_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Enable RLS on driver_mission_shifts
ALTER TABLE public.driver_mission_shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read driver_mission_shifts" ON public.driver_mission_shifts;
CREATE POLICY "Public read driver_mission_shifts" ON public.driver_mission_shifts
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins manage driver_mission_shifts" ON public.driver_mission_shifts;
CREATE POLICY "Admins manage driver_mission_shifts" ON public.driver_mission_shifts
FOR ALL USING (true) WITH CHECK (true);

-- 3. Update handle_referral_and_missions_on_trip_completed
CREATE OR REPLACE FUNCTION public.handle_referral_and_missions_on_trip_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_settings RECORD;
  v_driver_id UUID := NEW.driver_id;
  v_passenger_id UUID := NEW.passenger_id;
  v_ref RECORD;
  v_mission RECORD;
  v_shift RECORD;
  v_new_bal NUMERIC;
  v_new_passenger_bal NUMERIC;
  v_cairo_time TIME;
  v_cairo_date DATE;
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
  -- A. Driver Time-Window Shift Mission / Daily Mission
  -- --------------------------------------------------------
  IF v_driver_id IS NOT NULL AND (v_settings.is_missions_active IS TRUE) THEN
    -- Get current Cairo local time & date
    v_cairo_time := (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::TIME;
    v_cairo_date := (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::DATE;

    -- Look for any active shift matching the current Cairo time
    SELECT * INTO v_shift
    FROM public.driver_mission_shifts
    WHERE is_active = TRUE
      AND (
        (start_time <= end_time AND v_cairo_time >= start_time AND v_cairo_time <= end_time)
        OR
        (start_time > end_time AND (v_cairo_time >= start_time OR v_cairo_time <= end_time))
      )
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_shift IS NOT NULL THEN
      -- Process shift-based mission
      INSERT INTO public.driver_mission_progress (
        driver_id,
        shift_id,
        shift_title,
        mission_date,
        target_trips,
        completed_trips,
        reward_amount
      ) VALUES (
        v_driver_id,
        v_shift.id,
        v_shift.title,
        v_cairo_date,
        v_shift.target_trips,
        0,
        v_shift.reward_amount
      )
      ON CONFLICT (driver_id, mission_date, COALESCE(shift_id, '00000000-0000-0000-0000-000000000000'::uuid)) DO NOTHING;

      UPDATE public.driver_mission_progress
      SET 
        completed_trips = completed_trips + 1,
        updated_at = NOW()
      WHERE driver_id = v_driver_id 
        AND shift_id = v_shift.id
        AND mission_date = v_cairo_date
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
          'بونص ' || v_shift.title || ' 🏆',
          v_mission.reward_amount,
          'bonus',
          v_new_bal,
          'wallet',
          'مكافأة إتمام ' || v_mission.target_trips || ' رحلات خلال الفترة من ' || TO_CHAR(v_shift.start_time, 'HH12:MI AM') || ' إلى ' || TO_CHAR(v_shift.end_time, 'HH12:MI AM'),
          NOW()
        );

        BEGIN
          INSERT INTO public.notifications (
            user_id, title, body, type, is_read, data, created_at
          ) VALUES (
            v_driver_id,
            'بونص ' || v_shift.title || ' 🏆',
            'تهانينا يا كابتن! أكملت تارجت ' || v_shift.title || ' (' || v_mission.target_trips || ' رحلات) وتم إيداع ' || v_mission.reward_amount || ' ج.م في محفظتك بنجاح!',
            'wallet',
            FALSE,
            jsonb_build_object('amount', v_mission.reward_amount, 'type', 'shift_mission_reward'),
            NOW()
          );
        EXCEPTION WHEN OTHERS THEN
          NULL;
        END;
      END IF;

    ELSE
      -- Fallback: General Daily Mission if no specific shift matches
      INSERT INTO public.driver_mission_progress (
        driver_id,
        shift_id,
        shift_title,
        mission_date,
        target_trips,
        completed_trips,
        reward_amount
      ) VALUES (
        v_driver_id,
        NULL,
        'تحدي اليوم',
        v_cairo_date,
        COALESCE(v_settings.daily_mission_trips, 8),
        0,
        COALESCE(v_settings.daily_mission_reward, 80.00)
      )
      ON CONFLICT (driver_id, mission_date, COALESCE(shift_id, '00000000-0000-0000-0000-000000000000'::uuid)) DO NOTHING;

      UPDATE public.driver_mission_progress
      SET 
        completed_trips = completed_trips + 1,
        updated_at = NOW()
      WHERE driver_id = v_driver_id 
        AND shift_id IS NULL
        AND mission_date = v_cairo_date
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
          'مكافأة إتمام ' || v_mission.target_trips || ' رحلات لليوم ' || v_cairo_date::text,
          NOW()
        );
      END IF;
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
        -- 1. Credit Referrer
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

        -- 2. Credit Referee
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

-- 4. RPC: Get Active Driver Mission (For Mobile App)
CREATE OR REPLACE FUNCTION public.get_active_driver_mission(p_driver_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_settings RECORD;
  v_cairo_time TIME;
  v_cairo_date DATE;
  v_shift RECORD;
  v_progress RECORD;
  v_target INT;
  v_reward NUMERIC(10,2);
  v_done INT := 0;
  v_completed BOOLEAN := FALSE;
  v_title TEXT := 'تحدي اليوم';
  v_start_str TEXT := '';
  v_end_str TEXT := '';
  v_is_shift BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_settings FROM public.rewards_settings WHERE id = 'default';
  IF v_settings IS NULL OR v_settings.is_missions_active IS NOT TRUE THEN
    RETURN jsonb_build_object('is_active', false);
  END IF;

  v_cairo_time := (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::TIME;
  v_cairo_date := (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::DATE;

  -- Check matching active shift
  SELECT * INTO v_shift
  FROM public.driver_mission_shifts
  WHERE is_active = TRUE
    AND (
      (start_time <= end_time AND v_cairo_time >= start_time AND v_cairo_time <= end_time)
      OR
      (start_time > end_time AND (v_cairo_time >= start_time OR v_cairo_time <= end_time))
    )
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_shift IS NOT NULL THEN
    v_is_shift := TRUE;
    v_title := v_shift.title;
    v_target := v_shift.target_trips;
    v_reward := v_shift.reward_amount;
    v_start_str := TO_CHAR(v_shift.start_time, 'HH12:MI AM');
    v_end_str := TO_CHAR(v_shift.end_time, 'HH12:MI AM');

    SELECT * INTO v_progress
    FROM public.driver_mission_progress
    WHERE driver_id = p_driver_id
      AND shift_id = v_shift.id
      AND mission_date = v_cairo_date;

    IF v_progress IS NOT NULL THEN
      v_done := v_progress.completed_trips;
      v_completed := v_progress.is_completed OR v_progress.is_rewarded;
    END IF;

    RETURN jsonb_build_object(
      'is_active', true,
      'is_shift', true,
      'shift_id', v_shift.id,
      'title', v_title,
      'start_time', v_start_str,
      'end_time', v_end_str,
      'target_trips', v_target,
      'reward_amount', v_reward,
      'completed_trips', v_done,
      'is_completed', v_completed,
      'remaining_trips', GREATEST(0, v_target - v_done)
    );
  ELSE
    -- General daily mission
    v_target := COALESCE(v_settings.daily_mission_trips, 8);
    v_reward := COALESCE(v_settings.daily_mission_reward, 80.00);

    SELECT * INTO v_progress
    FROM public.driver_mission_progress
    WHERE driver_id = p_driver_id
      AND shift_id IS NULL
      AND mission_date = v_cairo_date;

    IF v_progress IS NOT NULL THEN
      v_done := v_progress.completed_trips;
      v_completed := v_progress.is_completed OR v_progress.is_rewarded;
    END IF;

    RETURN jsonb_build_object(
      'is_active', true,
      'is_shift', false,
      'title', 'تحدي اليوم',
      'target_trips', v_target,
      'reward_amount', v_reward,
      'completed_trips', v_done,
      'is_completed', v_completed,
      'remaining_trips', GREATEST(0, v_target - v_done)
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_active_driver_mission(UUID) TO anon, authenticated, service_role;
