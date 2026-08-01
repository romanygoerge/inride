-- ========================================================
-- INRIDE WALLET RECHARGE SYSTEM & STORAGE MIGRATION
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

-- Storage RLS Policies for wallet_receipts bucket
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

-- 2. Create Table for Wallet Recharge Requests
CREATE TABLE IF NOT EXISTS public.wallet_recharge_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL DEFAULT 'rider' CHECK (user_type IN ('rider', 'driver')),
  user_name TEXT DEFAULT '',
  user_phone TEXT DEFAULT '',
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL DEFAULT 'InstaPay',
  receipt_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by UUID
);

-- Indexing for performance
CREATE INDEX IF NOT EXISTS idx_recharge_user_id ON public.wallet_recharge_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_recharge_status ON public.wallet_recharge_requests(status);
CREATE INDEX IF NOT EXISTS idx_recharge_created_at ON public.wallet_recharge_requests(created_at DESC);

-- Enable RLS
ALTER TABLE public.wallet_recharge_requests ENABLE ROW LEVEL SECURITY;

-- Table RLS Policies
DROP POLICY IF EXISTS "Users can view their own recharge requests" ON public.wallet_recharge_requests;
CREATE POLICY "Users can view their own recharge requests"
  ON public.wallet_recharge_requests FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users can insert recharge requests" ON public.wallet_recharge_requests;
CREATE POLICY "Users can insert recharge requests"
  ON public.wallet_recharge_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role' OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Admin full control on recharge requests" ON public.wallet_recharge_requests;
CREATE POLICY "Admin full control on recharge requests"
  ON public.wallet_recharge_requests FOR ALL
  USING (true)
  WITH CHECK (true);

-- 3. RPC Function to Approve Recharge Request
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

  -- Insert completed transaction record
  INSERT INTO public.transactions (
    user_id,
    title,
    amount,
    type,
    balance_after,
    payment_method,
    receipt_url,
    notes,
    created_at
  ) VALUES (
    v_request.user_id,
    'شحن رصيد مقبول',
    v_request.amount,
    'charge',
    COALESCE(v_new_balance, 0),
    v_request.payment_method,
    v_request.receipt_url,
    'تم قبول طلب الشحن وإضافة الرصيد للمحفظة بواسطة الإدارة',
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

-- 4. RPC Function to Reject Recharge Request
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

  -- Insert rejected transaction record
  INSERT INTO public.transactions (
    user_id,
    title,
    amount,
    type,
    balance_after,
    payment_method,
    receipt_url,
    notes,
    created_at
  ) VALUES (
    v_request.user_id,
    'شحن رصيد مرفوض',
    v_request.amount,
    'charge_rejected',
    0,
    v_request.payment_method,
    v_request.receipt_url,
    CONCAT('تم رفض طلب الشحن. السبب: ', p_reason),
    NOW()
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم رفض طلب الشحن بنجاح');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
