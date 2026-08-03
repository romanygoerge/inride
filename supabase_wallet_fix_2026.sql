-- ========================================================
-- INRIDE WALLET & FINANCIAL DASHBOARD COMPLETE SYSTEM FIX
-- ========================================================

-- 1. Create Storage Bucket for Wallet Receipts (if not exists)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'wallet_receipts',
  'wallet_receipts',
  true,
  10485760, -- 10MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public select on wallet_receipts" ON storage.objects;
CREATE POLICY "Public select on wallet_receipts"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'wallet_receipts');

DROP POLICY IF EXISTS "Authenticated insert on wallet_receipts" ON storage.objects;
CREATE POLICY "Authenticated insert on wallet_receipts"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'wallet_receipts');

DROP POLICY IF EXISTS "Allow anon upload on wallet_receipts" ON storage.objects;
CREATE POLICY "Allow anon upload on wallet_receipts"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'wallet_receipts');

DROP POLICY IF EXISTS "Allow admin update on wallet_receipts" ON storage.objects;
CREATE POLICY "Allow admin update on wallet_receipts"
  ON storage.objects FOR ALL
  USING (bucket_id = 'wallet_receipts');

-- 2. Create Financial Settlements Table for Period Reset History & Archive
CREATE TABLE IF NOT EXISTS public.financial_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_type TEXT NOT NULL,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  total_income NUMERIC(12, 2) DEFAULT 0,
  total_payouts NUMERIC(12, 2) DEFAULT 0,
  net_balance NUMERIC(12, 2) DEFAULT 0,
  settled_by TEXT DEFAULT 'مدير النظام',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.financial_settlements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public financial_settlements full access" ON public.financial_settlements;
CREATE POLICY "Public financial_settlements full access" ON public.financial_settlements FOR ALL USING (true) WITH CHECK (true);

-- 3. Ensure Columns Exist on public.transactions
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS is_settled BOOLEAN DEFAULT false;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS settlement_id UUID;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS receipt_url TEXT DEFAULT '';
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'InstaPay';
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS reference_code TEXT DEFAULT '';
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- 4. Ensure Table & Columns Exist on public.wallet_recharge_requests
CREATE TABLE IF NOT EXISTS public.wallet_recharge_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_type TEXT NOT NULL DEFAULT 'rider',
  user_name TEXT DEFAULT '',
  user_phone TEXT DEFAULT '',
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL DEFAULT 'InstaPay',
  receipt_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by UUID
);

ALTER TABLE public.wallet_recharge_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full control on recharge requests" ON public.wallet_recharge_requests;
CREATE POLICY "Admin full control on recharge requests" ON public.wallet_recharge_requests FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.wallet_recharge_requests ADD COLUMN IF NOT EXISTS rejection_reason TEXT DEFAULT '';
ALTER TABLE public.wallet_recharge_requests ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ;
ALTER TABLE public.wallet_recharge_requests ADD COLUMN IF NOT EXISTS processed_by UUID;

-- 5. RPC Function to Approve Recharge Request
CREATE OR REPLACE FUNCTION public.approve_wallet_recharge_request(
  p_request_id UUID,
  p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request RECORD;
  v_new_balance NUMERIC;
BEGIN
  -- Fetch request from wallet_recharge_requests
  SELECT * INTO v_request
  FROM public.wallet_recharge_requests
  WHERE id = p_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'طلب الشحن غير موجود');
  END IF;

  IF v_request.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'تم معالجة هذا الطلب سابقاً');
  END IF;

  -- Increment user balance in users table
  UPDATE public.users
  SET wallet_balance = COALESCE(wallet_balance, 0) + v_request.amount
  WHERE id = v_request.user_id
  RETURNING wallet_balance INTO v_new_balance;

  -- Also update profiles table if exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    UPDATE public.profiles
    SET wallet_balance = COALESCE(wallet_balance, 0) + v_request.amount
    WHERE id = v_request.user_id;
  END IF;

  -- Mark request as approved
  UPDATE public.wallet_recharge_requests
  SET 
    status = 'approved',
    processed_at = NOW(),
    processed_by = p_admin_id
  WHERE id = p_request_id;

  -- Update existing charge_pending transaction if present, otherwise insert new
  UPDATE public.transactions
  SET
    type = 'charge',
    title = 'شحن رصيد مقبول',
    balance_after = COALESCE(v_new_balance, 0),
    notes = 'تم قبول طلب الشحن وتفعيل الرصيد بواسطة الإدارة',
    payment_method = v_request.payment_method,
    receipt_url = v_request.receipt_url
  WHERE user_id = v_request.user_id 
    AND (type = 'charge_pending' OR id = p_request_id)
    AND ABS(amount - v_request.amount) < 0.01;

  IF NOT FOUND THEN
    INSERT INTO public.transactions (
      id,
      user_id,
      title,
      amount,
      type,
      balance_after,
      payment_method,
      receipt_url,
      notes,
      is_settled,
      created_at
    ) VALUES (
      gen_random_uuid(),
      v_request.user_id,
      'شحن رصيد مقبول',
      v_request.amount,
      'charge',
      COALESCE(v_new_balance, 0),
      v_request.payment_method,
      v_request.receipt_url,
      'تم قبول طلب الشحن وإضافة الرصيد للمحفظة بواسطة الإدارة',
      false,
      NOW()
    );
  END IF;

  -- Insert notification for user
  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    created_at
  ) VALUES (
    v_request.user_id,
    '✅ تم قبول طلب الشحن',
    CONCAT('تم قبول طلب الشحن بمبلغ ', v_request.amount, ' ج.م بنجاح. رصيدك الحالي: ', COALESCE(v_new_balance, 0), ' ج.م'),
    'wallet',
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم قبول طلب الشحن بنجاح وإضافة الرصيد',
    'new_balance', COALESCE(v_new_balance, 0)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 6. RPC Function to Reject Recharge Request
CREATE OR REPLACE FUNCTION public.reject_wallet_recharge_request(
  p_request_id UUID,
  p_reason TEXT DEFAULT 'إيصال غير سليم أو تحويل مفقود',
  p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request RECORD;
BEGIN
  -- Fetch request
  SELECT * INTO v_request
  FROM public.wallet_recharge_requests
  WHERE id = p_request_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'طلب الشحن غير موجود');
  END IF;

  IF v_request.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'تم معالجة هذا الطلب سابقاً');
  END IF;

  -- Update request to rejected
  UPDATE public.wallet_recharge_requests
  SET 
    status = 'rejected',
    rejection_reason = p_reason,
    processed_at = NOW(),
    processed_by = p_admin_id
  WHERE id = p_request_id;

  -- Update existing charge_pending transaction if present, otherwise insert new
  UPDATE public.transactions
  SET
    type = 'charge_rejected',
    title = 'طلب شحن مرفوض',
    notes = CONCAT('تم رفض طلب الشحن. السبب: ', p_reason)
  WHERE user_id = v_request.user_id 
    AND (type = 'charge_pending' OR id = p_request_id)
    AND ABS(amount - v_request.amount) < 0.01;

  IF NOT FOUND THEN
    INSERT INTO public.transactions (
      id,
      user_id,
      title,
      amount,
      type,
      balance_after,
      payment_method,
      receipt_url,
      notes,
      is_settled,
      created_at
    ) VALUES (
      gen_random_uuid(),
      v_request.user_id,
      'طلب شحن مرفوض',
      v_request.amount,
      'charge_rejected',
      0,
      v_request.payment_method,
      v_request.receipt_url,
      CONCAT('تم رفض طلب الشحن. السبب: ', p_reason),
      false,
      NOW()
    );
  END IF;

  -- Insert notification for user
  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    created_at
  ) VALUES (
    v_request.user_id,
    '❌ تم رفض طلب الشحن',
    CONCAT('نأسف، تعذر قبول طلب الشحن الخاص بك. السبب: ', p_reason),
    'wallet',
    NOW()
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم رفض طلب الشحن بنجاح');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
