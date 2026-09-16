-- =========================================================
-- SUPABASE MIGRATION: UNIFY PASSENGER & CAPTAIN WALLETS
-- Project: inRide App 2026
-- Description: Unifies wallet balance for all users across
--              driver and passenger roles.
-- =========================================================

-- 1. Ensure all wallet balance columns exist
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC(10,2) DEFAULT 0.00;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS driver_wallet_balance NUMERIC(10,2) DEFAULT 0.00;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS passenger_wallet_balance NUMERIC(10,2) DEFAULT 0.00;

-- 2. Consolidate and unify existing user balances
-- Take the maximum available balance among wallet_balance, driver_wallet_balance, and passenger_wallet_balance
UPDATE public.users 
SET 
  wallet_balance = GREATEST(COALESCE(wallet_balance, 0.00), COALESCE(driver_wallet_balance, 0.00), COALESCE(passenger_wallet_balance, 0.00)),
  driver_wallet_balance = GREATEST(COALESCE(wallet_balance, 0.00), COALESCE(driver_wallet_balance, 0.00), COALESCE(passenger_wallet_balance, 0.00)),
  passenger_wallet_balance = GREATEST(COALESCE(wallet_balance, 0.00), COALESCE(driver_wallet_balance, 0.00), COALESCE(passenger_wallet_balance, 0.00))
WHERE driver_wallet_balance IS DISTINCT FROM wallet_balance 
   OR passenger_wallet_balance IS DISTINCT FROM wallet_balance
   OR driver_wallet_balance IS NULL 
   OR passenger_wallet_balance IS NULL 
   OR wallet_balance IS NULL;

-- 3. Create or replace the automatic wallet sync trigger function
-- Ensures 100% data consistency: any update to any wallet column automatically syncs all three
CREATE OR REPLACE FUNCTION public.sync_user_wallet_balances()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.wallet_balance := COALESCE(NEW.wallet_balance, NEW.driver_wallet_balance, NEW.passenger_wallet_balance, 0.00);
    NEW.driver_wallet_balance := NEW.wallet_balance;
    NEW.passenger_wallet_balance := NEW.wallet_balance;
  ELSIF TG_OP = 'UPDATE' THEN
    -- If wallet_balance was modified directly
    IF NEW.wallet_balance IS DISTINCT FROM OLD.wallet_balance THEN
      NEW.driver_wallet_balance := NEW.wallet_balance;
      NEW.passenger_wallet_balance := NEW.wallet_balance;
    -- Else if driver_wallet_balance was modified (e.g. legacy scripts or admin dashboard)
    ELSIF NEW.driver_wallet_balance IS DISTINCT FROM OLD.driver_wallet_balance THEN
      NEW.wallet_balance := NEW.driver_wallet_balance;
      NEW.passenger_wallet_balance := NEW.driver_wallet_balance;
    -- Else if passenger_wallet_balance was modified
    ELSIF NEW.passenger_wallet_balance IS DISTINCT FROM OLD.passenger_wallet_balance THEN
      NEW.wallet_balance := NEW.passenger_wallet_balance;
      NEW.driver_wallet_balance := NEW.passenger_wallet_balance;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if any, then recreate
DROP TRIGGER IF EXISTS trg_sync_user_wallet_balances ON public.users;
CREATE TRIGGER trg_sync_user_wallet_balances
BEFORE INSERT OR UPDATE OF wallet_balance, driver_wallet_balance, passenger_wallet_balance
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_wallet_balances();

-- 4. Update approve_wallet_recharge_request stored procedure to credit the unified wallet
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

  -- Credit unified wallet balance (trigger will auto-sync driver_wallet_balance and passenger_wallet_balance)
  UPDATE public.users
  SET wallet_balance = COALESCE(wallet_balance, 0) + v_request.amount
  WHERE id = v_request.user_id
  RETURNING wallet_balance INTO v_new_balance;

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
    'شحن رصيد المحفظة',
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
    'message', 'تم قبول طلب الشحن وإضافة الرصيد للمحفظة بنجاح',
    'new_balance', COALESCE(v_new_balance, 0)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
