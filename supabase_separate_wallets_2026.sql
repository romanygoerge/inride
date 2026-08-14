-- ==========================================
-- SUPABASE MIGRATION: SEPARATE PASSENGER & CAPTAIN WALLETS
-- Project: inRide App 2026
-- ==========================================

-- 1. Add driver_wallet_balance column to users table if not exists
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_wallet_balance NUMERIC(10,2) DEFAULT 0.00;

-- Optional: Add passenger_wallet_balance alias column if not exists (defaults to wallet_balance)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS passenger_wallet_balance NUMERIC(10,2) DEFAULT 250.00;

-- Populate driver_wallet_balance with current wallet_balance if null for existing drivers
UPDATE public.users 
SET driver_wallet_balance = COALESCE(wallet_balance, 0.00)
WHERE driver_wallet_balance IS NULL AND role = 'driver';

-- 2. Add target_role column to wallet_recharge_requests if not exists
ALTER TABLE public.wallet_recharge_requests 
ADD COLUMN IF NOT EXISTS target_role TEXT DEFAULT 'rider';

-- Sync user_type to target_role if target_role is null
UPDATE public.wallet_recharge_requests 
SET target_role = COALESCE(user_type, 'rider')
WHERE target_role IS NULL;

-- 3. Update approve_wallet_recharge_request stored procedure to route balance top-up by role
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
  v_role TEXT;
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

  v_role := LOWER(COALESCE(v_request.target_role, v_request.user_type, 'rider'));

  IF v_role = 'driver' THEN
    -- Credit Captain Wallet
    UPDATE public.users
    SET driver_wallet_balance = COALESCE(driver_wallet_balance, 0) + v_request.amount
    WHERE id = v_request.user_id
    RETURNING driver_wallet_balance INTO v_new_balance;
  ELSE
    -- Credit Passenger Wallet
    UPDATE public.users
    SET wallet_balance = COALESCE(wallet_balance, 0) + v_request.amount,
        passenger_wallet_balance = COALESCE(wallet_balance, 0) + v_request.amount
    WHERE id = v_request.user_id
    RETURNING wallet_balance INTO v_new_balance;
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
    CASE WHEN v_role = 'driver' THEN 'شحن محفظة الكابتن' ELSE 'شحن محفظة الراكب' END,
    v_request.amount,
    'charge',
    v_new_balance,
    v_request.payment_method,
    v_request.receipt_url,
    'تمت الموافقة من الأدمن على طلب الشحن',
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إعتماد طلب الشحن وتحديث الرصيد بنجاح',
    'new_balance', v_new_balance,
    'role', v_role
  );
END;
$$;
