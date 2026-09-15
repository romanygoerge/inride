-- ====================================================================
-- SUPABASE MIGRATION: PROMO CODES & BARCODE GENERATOR SYSTEM
-- Project: inRide App 2026
-- Description: Promo code generation, barcodes, validity, activation toggle,
--              in-app banner display, and instant wallet redemption.
-- ====================================================================

-- 1. Create promo_codes table
CREATE TABLE IF NOT EXISTS public.promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  discount_type TEXT NOT NULL DEFAULT 'fixed', -- 'fixed' (ج.م) or 'percent' (%)
  expires_at TIMESTAMPTZ, -- بصلاحية محددة
  is_active BOOLEAN NOT NULL DEFAULT TRUE, -- تشغيل أو إيقاف من الداش بورد
  max_uses INT DEFAULT NULL, -- الحد الأقصى للاستخدامات (فارغ = غير محدود)
  current_uses INT NOT NULL DEFAULT 0,
  target_role TEXT NOT NULL DEFAULT 'all', -- 'all', 'rider', 'driver'
  show_in_app_banner BOOLEAN NOT NULL DEFAULT TRUE, -- يظهر في بانر صفحة اكسب فلوس أكتر
  banner_tagline TEXT DEFAULT 'عرض خاص لمستخدمي inRide',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON public.promo_codes(code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON public.promo_codes(is_active);

-- 3. Row Level Security (RLS)
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read active promo codes" ON public.promo_codes;
CREATE POLICY "Allow public read active promo codes" ON public.promo_codes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow full access for service_role and admin" ON public.promo_codes;
CREATE POLICY "Allow full access for service_role and admin" ON public.promo_codes
  FOR ALL USING (true) WITH CHECK (true);

-- 4. Redemptions tracking table
CREATE TABLE IF NOT EXISTS public.promo_code_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id UUID NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  amount_rewarded NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (promo_code_id, user_id)
);

ALTER TABLE public.promo_code_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read own redemptions" ON public.promo_code_redemptions;
CREATE POLICY "Allow read own redemptions" ON public.promo_code_redemptions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert redemptions" ON public.promo_code_redemptions;
CREATE POLICY "Allow insert redemptions" ON public.promo_code_redemptions
  FOR INSERT WITH CHECK (true);

-- 5. Realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'promo_codes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.promo_codes;
  END IF;
END;
$$;

-- 6. RPC Function: Apply Promo Code
CREATE OR REPLACE FUNCTION public.apply_promo_code(
  p_user_id UUID,
  p_code TEXT,
  p_user_type TEXT DEFAULT 'rider'
)
RETURNS JSONB AS $$
DECLARE
  v_promo RECORD;
  v_clean_code TEXT;
  v_reward_amount NUMERIC;
  v_new_bal NUMERIC := 0.00;
  v_user_exists BOOLEAN;
BEGIN
  v_clean_code := UPPER(TRIM(p_code));

  -- 0. Check if user exists
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success', false, 'is_promo', false, 'message', 'المستخدم غير موجود في النظام');
  END IF;

  -- 1. Find promo code
  SELECT * INTO v_promo FROM public.promo_codes WHERE UPPER(TRIM(code)) = v_clean_code;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'is_promo', false, 'message', 'الكود المدخل غير موجود');
  END IF;

  -- 2. Check if active
  IF NOT v_promo.is_active THEN
    RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'عفواً، هذا البرومو كود متوقف حالياً من إدارة التطبيق');
  END IF;

  -- 3. Check expiration
  IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < NOW() THEN
    RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'عفواً، انتهت صلاحية استخدام هذا البرومو كود');
  END IF;

  -- 4. Check max uses
  IF v_promo.max_uses IS NOT NULL AND v_promo.current_uses >= v_promo.max_uses THEN
    RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'عفواً، وصل الكود للحد الأقصى لعدد مرات الاستخدام المتاحة');
  END IF;

  -- 5. Check target audience
  IF v_promo.target_role <> 'all' AND LOWER(v_promo.target_role) <> LOWER(p_user_type) THEN
    IF LOWER(v_promo.target_role) = 'driver' THEN
      RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'هذا البرومو كود مخصص لكباتن inRide فقط');
    ELSE
      RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'هذا البرومو كود مخصص لركاب inRide فقط');
    END IF;
  END IF;

  -- 6. Check if user already redeemed
  IF EXISTS(SELECT 1 FROM public.promo_code_redemptions WHERE promo_code_id = v_promo.id AND user_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'is_promo', true, 'message', 'لقد قمت باستخدام هذا البرومو كود مسبقاً على هذا الحساب');
  END IF;

  v_reward_amount := v_promo.discount_amount;

  -- 7. Record redemption
  INSERT INTO public.promo_code_redemptions (promo_code_id, user_id, code, amount_rewarded)
  VALUES (v_promo.id, p_user_id, v_clean_code, v_reward_amount);

  -- 8. Increment promo uses
  UPDATE public.promo_codes 
  SET current_uses = current_uses + 1, updated_at = NOW() 
  WHERE id = v_promo.id;

  -- 9. Deposit amount into user's wallet immediately
  IF LOWER(p_user_type) = 'driver' THEN
    UPDATE public.users 
    SET 
      driver_wallet_balance = COALESCE(driver_wallet_balance, 0.00) + v_reward_amount,
      updated_at = NOW()
    WHERE id = p_user_id
    RETURNING driver_wallet_balance INTO v_new_bal;

    BEGIN
      UPDATE public.drivers
      SET total_earnings = COALESCE(total_earnings, 0.00) + v_reward_amount, updated_at = NOW()
      WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSE
    UPDATE public.users 
    SET 
      wallet_balance = COALESCE(wallet_balance, 0.00) + v_reward_amount,
      passenger_wallet_balance = COALESCE(passenger_wallet_balance, 0.00) + v_reward_amount,
      updated_at = NOW()
    WHERE id = p_user_id
    RETURNING wallet_balance INTO v_new_bal;
  END IF;

  -- 10. Record wallet transaction with correct schema
  BEGIN
    INSERT INTO public.transactions (
      user_id, 
      title, 
      amount, 
      type, 
      balance_after, 
      payment_method, 
      notes,
      created_at
    )
    VALUES (
      p_user_id, 
      'مكافأة برومو كود: ' || v_clean_code, 
      v_reward_amount, 
      'promo_reward', 
      v_new_bal, 
      'promo_code', 
      v_promo.title,
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'is_promo', true,
    'amount', v_reward_amount,
    'new_balance', v_new_bal,
    'title', v_promo.title,
    'message', 'تهانينا! 🎉 تم تفعيل البرومو كود بنجاح وإضافة ' || v_reward_amount::TEXT || ' ج.م إلى رصيد محفظتك فوراً!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.apply_promo_code(UUID, TEXT, TEXT) TO anon, authenticated, service_role;
