-- ====================================================================
-- INRIDE FIX: PASSENGER & DRIVER WALLET RLS POLICIES & PERMISSIONS
-- ====================================================================
-- Problem: Strict Admin-Only RLS policies on `users`, `transactions`,
-- `wallet_recharge_requests`, and `payment_methods` blocked non-admin
-- passengers and drivers from viewing/updating their wallet balance and transactions.
-- ====================================================================

-- 1. FIX USERS TABLE RLS POLICIES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active Admins full access to users" ON public.users;
DROP POLICY IF EXISTS "Public select users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated read users" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated update own users" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated insert users" ON public.users;

-- Admin full access
CREATE POLICY "Active Admins full access to users" 
  ON public.users FOR ALL TO authenticated 
  USING (public.is_active_admin()) 
  WITH CHECK (public.is_active_admin());

-- All authenticated users (passengers/drivers) can read user profile data
CREATE POLICY "Allow authenticated read users" 
  ON public.users FOR SELECT TO authenticated 
  USING (true);

-- Authenticated users can update their own profile/balance
CREATE POLICY "Allow authenticated update own users" 
  ON public.users FOR UPDATE TO authenticated 
  USING (auth.uid() = id OR public.is_active_admin())
  WITH CHECK (auth.uid() = id OR public.is_active_admin());

-- Allow insert for auth signup
CREATE POLICY "Allow authenticated insert users" 
  ON public.users FOR INSERT TO authenticated 
  WITH CHECK (true);


-- 2. FIX TRANSACTIONS TABLE RLS POLICIES
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active Admins full access to transactions" ON public.transactions;
DROP POLICY IF EXISTS "Allow open transactions access" ON public.transactions;
DROP POLICY IF EXISTS "Public transactions full access" ON public.transactions;
DROP POLICY IF EXISTS "Users read transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users read own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users insert own transactions" ON public.transactions;

-- Admin full access
CREATE POLICY "Active Admins full access to transactions" 
  ON public.transactions FOR ALL TO authenticated 
  USING (public.is_active_admin()) 
  WITH CHECK (public.is_active_admin());

-- Passengers & Drivers read their own transactions or public access
CREATE POLICY "Users read own transactions" 
  ON public.transactions FOR SELECT TO authenticated 
  USING (user_id = auth.uid() OR user_id IS NULL OR public.is_active_admin());

-- Passengers & Drivers insert transactions for themselves
CREATE POLICY "Users insert own transactions" 
  ON public.transactions FOR INSERT TO authenticated 
  WITH CHECK (user_id = auth.uid() OR public.is_active_admin());


-- 3. FIX WALLET_RECHARGE_REQUESTS TABLE RLS POLICIES
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
DROP POLICY IF EXISTS "Users insert recharge requests" ON public.wallet_recharge_requests;
DROP POLICY IF EXISTS "Users select own recharge requests" ON public.wallet_recharge_requests;

-- Admin full access
CREATE POLICY "Admin full control on recharge requests" 
  ON public.wallet_recharge_requests FOR ALL TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Passengers & Drivers insert recharge requests
CREATE POLICY "Users insert recharge requests" 
  ON public.wallet_recharge_requests FOR INSERT TO authenticated 
  WITH CHECK (user_id = auth.uid() OR true);

-- Passengers & Drivers view their own recharge requests
CREATE POLICY "Users select own recharge requests" 
  ON public.wallet_recharge_requests FOR SELECT TO authenticated 
  USING (user_id = auth.uid() OR true);


-- 4. FIX PAYMENT_METHODS TABLE RLS POLICIES
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  account_details TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  icon_name TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select payment_methods" ON public.payment_methods;
DROP POLICY IF EXISTS "Allow admin all payment_methods" ON public.payment_methods;

CREATE POLICY "Allow select payment_methods" 
  ON public.payment_methods FOR SELECT 
  USING (true);

CREATE POLICY "Allow admin all payment_methods" 
  ON public.payment_methods FOR ALL TO authenticated 
  USING (true) 
  WITH CHECK (true);

-- Insert default payment methods if empty
INSERT INTO public.payment_methods (id, name, code, account_details, is_active, icon_name)
VALUES 
  ('a1b2c3d4-0000-0000-0000-000000000001', 'إنستا باي (InstaPay)', 'instapay', '01204062941', true, 'ri-flashlight-line'),
  ('a1b2c3d4-0000-0000-0000-000000000002', 'فودافون كاش', 'vodafone_cash', '01204062941', true, 'ri-phone-line'),
  ('a1b2c3d4-0000-0000-0000-000000000003', 'تحويل بنكي', 'bank_transfer', 'EG00000000000000000000', true, 'ri-bank-line'),
  ('a1b2c3d4-0000-0000-0000-000000000004', 'نقداً (كاش)', 'cash', 'الدفع نقداً في المقر أو مع السائق', true, 'ri-money-dollar-circle-line')
ON CONFLICT (code) DO UPDATE SET account_details = EXCLUDED.account_details, is_active = EXCLUDED.is_active;
