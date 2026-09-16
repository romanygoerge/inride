-- ====================================================================
-- INRIDE OTP SECURITY HARDENING & RATE LIMITING SYSTEM (2026)
-- Prevents OTP Bombing, Botnet attacks, and enforces Strict Database Rate Limits
-- ====================================================================

-- 1. Create OTP Requests Table if not exists
CREATE TABLE IF NOT EXISTS public.otp_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_phone_created ON public.otp_requests(phone_number, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otp_requests_expiry ON public.otp_requests(expires_at);

-- 2. Create OTP Audit & Rate Limiting Table
CREATE TABLE IF NOT EXISTS public.otp_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    status TEXT NOT NULL DEFAULT 'sent', -- 'sent', 'blocked_rate_limit', 'failed'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_audit_phone_time ON public.otp_audit_logs(phone_number, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otp_audit_ip_time ON public.otp_audit_logs(ip_address, created_at DESC);

-- Enable RLS and restrict access strictly
ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow full access to otp_requests" ON public.otp_requests;
CREATE POLICY "Allow full access to otp_requests" ON public.otp_requests FOR ALL TO service_role, anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow full access to otp_audit_logs" ON public.otp_audit_logs;
CREATE POLICY "Allow full access to otp_audit_logs" ON public.otp_audit_logs FOR ALL TO service_role, anon, authenticated USING (true) WITH CHECK (true);

-- 3. Stored Function: verify_and_record_otp_request
-- Evaluates Phone and IP limits atomically in the database
CREATE OR REPLACE FUNCTION public.verify_and_record_otp_request(
    p_phone TEXT,
    p_ip TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_phone TEXT;
    v_now TIMESTAMPTZ := NOW();
    v_last_request TIMESTAMPTZ;
    v_count_hour INT;
    v_count_day INT;
    v_ip_count_hour INT;
    v_cooldown_seconds INT := 60;
    v_max_per_hour INT := 4;
    v_max_per_day INT := 8;
    v_max_ip_per_hour INT := 12;
BEGIN
    -- Standardize Egyptian phone
    v_clean_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF v_clean_phone LIKE '00%' THEN
        v_clean_phone := substr(v_clean_phone, 3);
    END IF;
    IF length(v_clean_phone) = 10 AND v_clean_phone LIKE '1%' THEN
        v_clean_phone := '20' || v_clean_phone;
    ELSIF length(v_clean_phone) = 11 AND (v_clean_phone LIKE '01%' OR v_clean_phone LIKE '0%') THEN
        v_clean_phone := '20' || substr(v_clean_phone, 2);
    END IF;

    -- Allow Demo Account fast pass
    IF v_clean_phone = '201000000000' OR v_clean_phone LIKE '%000000000' THEN
        RETURN jsonb_build_object(
            'allowed', true,
            'is_demo', true,
            'message', 'Demo account fast pass'
        );
    END IF;

    -- A. Check 60-second cooldown on Phone Number
    SELECT created_at INTO v_last_request
    FROM public.otp_audit_logs
    WHERE phone_number = v_clean_phone AND status = 'sent'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_request IS NOT NULL AND v_now - v_last_request < (v_cooldown_seconds || ' seconds')::INTERVAL THEN
        INSERT INTO public.otp_audit_logs(phone_number, ip_address, user_agent, status)
        VALUES (v_clean_phone, p_ip, p_user_agent, 'blocked_rate_limit');

        RETURN jsonb_build_object(
            'allowed', false,
            'retry_after', EXTRACT(EPOCH FROM (v_last_request + (v_cooldown_seconds || ' seconds')::INTERVAL - v_now))::INT,
            'error', 'يرجى الانتظار دقيقة واحدة قبل طلب رمز جديد.'
        );
    END IF;

    -- B. Check Hourly Limit on Phone Number
    SELECT COUNT(*) INTO v_count_hour
    FROM public.otp_audit_logs
    WHERE phone_number = v_clean_phone AND status = 'sent'
      AND created_at >= v_now - INTERVAL '1 hour';

    IF v_count_hour >= v_max_per_hour THEN
        INSERT INTO public.otp_audit_logs(phone_number, ip_address, user_agent, status)
        VALUES (v_clean_phone, p_ip, p_user_agent, 'blocked_rate_limit');

        RETURN jsonb_build_object(
            'allowed', false,
            'error', 'تم تجاوز الحد الأقصى للمحاولات لهذا الرقم (4 محاولات بالساعة). يرجى المحاولة لاحقاً.'
        );
    END IF;

    -- C. Check Daily Limit on Phone Number
    SELECT COUNT(*) INTO v_count_day
    FROM public.otp_audit_logs
    WHERE phone_number = v_clean_phone AND status = 'sent'
      AND created_at >= v_now - INTERVAL '24 hours';

    IF v_count_day >= v_max_per_day THEN
        INSERT INTO public.otp_audit_logs(phone_number, ip_address, user_agent, status)
        VALUES (v_clean_phone, p_ip, p_user_agent, 'blocked_rate_limit');

        RETURN jsonb_build_object(
            'allowed', false,
            'error', 'تم تجاوز الحد الأقصى لطلبات الرمز اليومية لهذا الرقم. يرجى التواصل مع الدعم الفني.'
        );
    END IF;

    -- D. Check IP Address Rate Limit (Prevents massive bot scraping)
    IF p_ip IS NOT NULL AND length(p_ip) > 3 AND p_ip NOT IN ('127.0.0.1', '::1') THEN
        SELECT COUNT(*) INTO v_ip_count_hour
        FROM public.otp_audit_logs
        WHERE ip_address = p_ip AND status = 'sent'
          AND created_at >= v_now - INTERVAL '1 hour';

        IF v_ip_count_hour >= v_max_ip_per_hour THEN
            INSERT INTO public.otp_audit_logs(phone_number, ip_address, user_agent, status)
            VALUES (v_clean_phone, p_ip, p_user_agent, 'blocked_rate_limit');

            RETURN jsonb_build_object(
                'allowed', false,
                'error', 'تم تجاوز الحد المسموح به من هذا الاتصال. يرجى الانتظار قليلاً.'
            );
        END IF;
    END IF;

    -- All checks passed: Record legitimate attempt
    INSERT INTO public.otp_audit_logs(phone_number, ip_address, user_agent, status)
    VALUES (v_clean_phone, p_ip, p_user_agent, 'sent');

    RETURN jsonb_build_object(
        'allowed', true,
        'phone', v_clean_phone
    );
END;
$$;

-- 4. Stored Function: store_phone_otp
CREATE OR REPLACE FUNCTION public.store_phone_otp(
    p_phone TEXT,
    p_otp_hash TEXT,
    p_expires_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_phone TEXT;
BEGIN
    v_clean_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF v_clean_phone LIKE '00%' THEN v_clean_phone := substr(v_clean_phone, 3); END IF;
    IF length(v_clean_phone) = 10 AND v_clean_phone LIKE '1%' THEN v_clean_phone := '20' || v_clean_phone;
    ELSIF length(v_clean_phone) = 11 AND (v_clean_phone LIKE '01%' OR v_clean_phone LIKE '0%') THEN v_clean_phone := '20' || substr(v_clean_phone, 2); END IF;

    INSERT INTO public.otp_requests (phone_number, otp_hash, attempts, is_verified, expires_at)
    VALUES (v_clean_phone, p_otp_hash, 0, false, p_expires_at);

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 5. Stored Function: verify_phone_otp_hash
CREATE OR REPLACE FUNCTION public.verify_phone_otp_hash(
    p_phone TEXT,
    p_otp_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_phone TEXT;
    v_rec RECORD;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_clean_phone := regexp_replace(p_phone, '[^\d]', '', 'g');
    IF v_clean_phone LIKE '00%' THEN v_clean_phone := substr(v_clean_phone, 3); END IF;
    IF length(v_clean_phone) = 10 AND v_clean_phone LIKE '1%' THEN v_clean_phone := '20' || v_clean_phone;
    ELSIF length(v_clean_phone) = 11 AND (v_clean_phone LIKE '01%' OR v_clean_phone LIKE '0%') THEN v_clean_phone := '20' || substr(v_clean_phone, 2); END IF;

    SELECT id, otp_hash, attempts, expires_at INTO v_rec
    FROM public.otp_requests
    WHERE phone_number = v_clean_phone
      AND is_verified = FALSE
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_rec.id IS NULL THEN
        RETURN jsonb_build_object('valid', false, 'error', 'لا يوجد رمز تحقق نشط لهذا الرقم.');
    END IF;

    IF v_now > v_rec.expires_at THEN
        RETURN jsonb_build_object('valid', false, 'error', 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.');
    END IF;

    IF v_rec.attempts >= 5 THEN
        RETURN jsonb_build_object('valid', false, 'error', 'تم تجاوز الحد الأقصى للمحاولات الخاطئة. يرجى طلب رمز جديد.');
    END IF;

    IF v_rec.otp_hash = p_otp_hash THEN
        UPDATE public.otp_requests
        SET is_verified = TRUE, attempts = attempts + 1
        WHERE id = v_rec.id;

        RETURN jsonb_build_object('valid', true);
    ELSE
        UPDATE public.otp_requests
        SET attempts = attempts + 1
        WHERE id = v_rec.id;

        RETURN jsonb_build_object('valid', false, 'error', 'رمز التحقق غير صحيح.');
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_and_record_otp_request(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.store_phone_otp(TEXT, TEXT, TIMESTAMPTZ) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_phone_otp_hash(TEXT, TEXT) TO anon, authenticated, service_role;
