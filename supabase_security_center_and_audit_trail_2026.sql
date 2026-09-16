-- ====================================================================
-- INRIDE ENTERPRISE SECURITY MONITORING + DIGITAL FORENSICS SYSTEM (2026)
-- Complete Append-Only Cryptographic Audit Trail, Incidents & Tamper Proofing
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- --------------------------------------------------------------------
-- 1. Security Events Table
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.security_events (
    seq_num BIGSERIAL,
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    request_id TEXT,
    correlation_id TEXT,
    user_id UUID,
    admin_id UUID,
    session_id TEXT,
    device_id TEXT,
    device_platform TEXT,
    device_manufacturer TEXT,
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    ip_address TEXT,
    user_agent TEXT,
    asn TEXT,
    isp TEXT,
    country TEXT,
    city TEXT,
    endpoint TEXT,
    http_method TEXT,
    response_status INT,
    authentication_method TEXT,
    authorization_result TEXT,
    message_id TEXT,
    provider_message_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    prev_hash TEXT,
    event_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Optimized forensic query indexes
CREATE INDEX IF NOT EXISTS idx_sec_events_created_at ON public.security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sec_events_severity ON public.security_events(severity);
CREATE INDEX IF NOT EXISTS idx_sec_events_event_type ON public.security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_sec_events_user_id ON public.security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_admin_id ON public.security_events(admin_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_device_id ON public.security_events(device_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_ip_address ON public.security_events(ip_address);
CREATE INDEX IF NOT EXISTS idx_sec_events_request_id ON public.security_events(request_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_correlation_id ON public.security_events(correlation_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_message_id ON public.security_events(message_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_provider_msg_id ON public.security_events(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_sec_events_session_id ON public.security_events(session_id);

-- --------------------------------------------------------------------
-- 2. Security Incidents Management Table
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.security_incidents (
    id TEXT PRIMARY KEY, -- Formatted: INC-2026-XXXX
    title TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'CONTAINED', 'RESOLVED', 'CLOSED')),
    affected_account TEXT,
    device_id TEXT,
    ip_address TEXT,
    request_ids TEXT[] DEFAULT '{}'::TEXT[],
    message_ids TEXT[] DEFAULT '{}'::TEXT[],
    event_ids UUID[] DEFAULT '{}'::UUID[],
    timeline JSONB DEFAULT '[]'::jsonb,
    evidence_references JSONB DEFAULT '[]'::jsonb,
    admin_notes TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sec_incidents_status ON public.security_incidents(status);
CREATE INDEX IF NOT EXISTS idx_sec_incidents_severity ON public.security_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_sec_incidents_created ON public.security_incidents(created_at DESC);

-- Incident to Event Junction
CREATE TABLE IF NOT EXISTS public.security_incident_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id TEXT NOT NULL REFERENCES public.security_incidents(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES public.security_events(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_incident_event UNIQUE (incident_id, event_id)
);

-- --------------------------------------------------------------------
-- 3. Incident ID Generation Sequence
-- --------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_incident_number START WITH 1;

CREATE OR REPLACE FUNCTION public.generate_incident_id()
RETURNS TEXT AS $$
DECLARE
    v_seq INT;
    v_year TEXT;
BEGIN
    v_seq := nextval('public.seq_incident_number');
    v_year := to_char(NOW(), 'YYYY');
    RETURN 'INC-' || v_year || '-' || lpad(v_seq::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------------------
-- 4. Cryptographic Hash-Chaining & Append-Only Logger
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_security_event(
    p_event_type TEXT,
    p_severity TEXT,
    p_request_id TEXT DEFAULT NULL,
    p_correlation_id TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_device_platform TEXT DEFAULT NULL,
    p_device_manufacturer TEXT DEFAULT NULL,
    p_device_model TEXT DEFAULT NULL,
    p_os_version TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_asn TEXT DEFAULT NULL,
    p_isp TEXT DEFAULT NULL,
    p_country TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_endpoint TEXT DEFAULT NULL,
    p_http_method TEXT DEFAULT NULL,
    p_response_status INT DEFAULT NULL,
    p_authentication_method TEXT DEFAULT NULL,
    p_authorization_result TEXT DEFAULT NULL,
    p_message_id TEXT DEFAULT NULL,
    p_provider_message_id TEXT DEFAULT NULL,
    p_details JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_prev_hash TEXT;
    v_new_id UUID;
    v_payload TEXT;
    v_event_hash TEXT;
    v_now TIMESTAMPTZ;
BEGIN
    v_now := clock_timestamp();
    v_new_id := gen_random_uuid();

    -- Fetch the most recent event hash to form the blockchain-like audit trail
    SELECT event_hash INTO v_prev_hash
    FROM public.security_events
    ORDER BY seq_num DESC
    LIMIT 1;

    IF v_prev_hash IS NULL OR v_prev_hash = '' THEN
        v_prev_hash := 'GENESIS_BLOCK_INRIDE_SECURITY_AUDIT_2026';
    END IF;

    -- Cryptographic Payload string for SHA-256 calculation
    v_payload := v_prev_hash || '|' ||
                 v_new_id::text || '|' ||
                 p_event_type || '|' ||
                 p_severity || '|' ||
                 COALESCE(p_request_id, '') || '|' ||
                 COALESCE(p_correlation_id, '') || '|' ||
                 COALESCE(p_user_id::text, '') || '|' ||
                 COALESCE(p_session_id, '') || '|' ||
                 COALESCE(p_device_id, '') || '|' ||
                 COALESCE(p_ip_address, '') || '|' ||
                 COALESCE(p_endpoint, '') || '|' ||
                 COALESCE(p_message_id, '') || '|' ||
                 COALESCE(p_provider_message_id, '') || '|' ||
                 v_now::text;

    v_event_hash := encode(digest(v_payload, 'sha256'), 'hex');

    INSERT INTO public.security_events (
        id, event_type, severity, timestamp, request_id, correlation_id,
        user_id, admin_id, session_id, device_id, device_platform,
        device_manufacturer, device_model, os_version, app_version,
        ip_address, user_agent, asn, isp, country, city,
        endpoint, http_method, response_status, authentication_method,
        authorization_result, message_id, provider_message_id, details,
        prev_hash, event_hash, created_at
    ) VALUES (
        v_new_id, p_event_type, p_severity, v_now, p_request_id, p_correlation_id,
        p_user_id, p_admin_id, p_session_id, p_device_id, p_device_platform,
        p_device_manufacturer, p_device_model, p_os_version, p_app_version,
        p_ip_address, p_user_agent, p_asn, p_isp, p_country, p_city,
        p_endpoint, p_http_method, p_response_status, p_authentication_method,
        p_authorization_result, p_message_id, p_provider_message_id, p_details,
        v_prev_hash, v_event_hash, v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'event_id', v_new_id,
        'event_hash', v_event_hash,
        'prev_hash', v_prev_hash,
        'timestamp', v_now
    );
END;
$$;

-- --------------------------------------------------------------------
-- 5. Anti-Tampering Trigger (Strict Append-Only Immutability)
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_prevent_security_events_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'CRITICAL SECURITY VIOLATION: security_events records are append-only and cryptographically sealed. Modifications or deletions are strictly prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_security_events_modification ON public.security_events;
CREATE TRIGGER trg_block_security_events_modification
BEFORE UPDATE OR DELETE ON public.security_events
FOR EACH ROW
EXECUTE FUNCTION public.trg_prevent_security_events_tampering();

-- --------------------------------------------------------------------
-- 6. Audit Trail Hash Chain Integrity Verifier
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_security_events_integrity()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_expected_prev TEXT := 'GENESIS_BLOCK_INRIDE_SECURITY_AUDIT_2026';
    v_calc_hash TEXT;
    v_payload TEXT;
    v_total INT := 0;
    v_valid INT := 0;
BEGIN
    FOR r IN (
        SELECT id, event_type, severity, request_id, correlation_id,
               user_id, session_id, device_id, ip_address, endpoint,
               message_id, provider_message_id, prev_hash, event_hash,
               created_at
        FROM public.security_events
        ORDER BY seq_num ASC
    ) LOOP
        v_total := v_total + 1;

        -- Verify link to previous event hash
        IF r.prev_hash <> v_expected_prev THEN
            RETURN jsonb_build_object(
                'valid', false,
                'status', 'BROKEN_CHAIN',
                'failed_at_id', r.id,
                'total_checked', v_total,
                'expected_prev', v_expected_prev,
                'actual_prev', r.prev_hash
            );
        END IF;

        -- Recalculate hash
        v_payload := r.prev_hash || '|' ||
                     r.id::text || '|' ||
                     r.event_type || '|' ||
                     r.severity || '|' ||
                     COALESCE(r.request_id, '') || '|' ||
                     COALESCE(r.correlation_id, '') || '|' ||
                     COALESCE(r.user_id::text, '') || '|' ||
                     COALESCE(r.session_id, '') || '|' ||
                     COALESCE(r.device_id, '') || '|' ||
                     COALESCE(r.ip_address, '') || '|' ||
                     COALESCE(r.endpoint, '') || '|' ||
                     COALESCE(r.message_id, '') || '|' ||
                     COALESCE(r.provider_message_id, '') || '|' ||
                     r.created_at::text;

        v_calc_hash := encode(digest(v_payload, 'sha256'), 'hex');

        IF v_calc_hash <> r.event_hash THEN
            RETURN jsonb_build_object(
                'valid', false,
                'status', 'HASH_MISMATCH',
                'failed_at_id', r.id,
                'total_checked', v_total,
                'expected_hash', v_calc_hash,
                'actual_hash', r.event_hash
            );
        END IF;

        v_valid := v_valid + 1;
        v_expected_prev := r.event_hash;
    END LOOP;

    RETURN jsonb_build_object(
        'valid', true,
        'status', 'CHAIN_VERIFIED_INTACT',
        'total_events', v_total,
        'verified_events', v_valid,
        'latest_hash', v_expected_prev
    );
END;
$$;

-- --------------------------------------------------------------------
-- 7. Row-Level Security (RLS) & Role-Based Access Control
-- --------------------------------------------------------------------
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_incident_events ENABLE ROW LEVEL SECURITY;

-- Revoke all permissions from public and anon
REVOKE ALL ON public.security_events FROM anon, public;
REVOKE ALL ON public.security_incidents FROM anon, public;
REVOKE ALL ON public.security_incident_events FROM anon, public;

-- Drop previous policies if any
DROP POLICY IF EXISTS "Admins read security events" ON public.security_events;
DROP POLICY IF EXISTS "Service role manages security events" ON public.security_events;
DROP POLICY IF EXISTS "Admins manage security incidents" ON public.security_incidents;
DROP POLICY IF EXISTS "Service role manages security incidents" ON public.security_incidents;

-- Policy: Only authenticated Admin users or service_role can view security events
CREATE POLICY "Admins read security events"
ON public.security_events
FOR SELECT
TO authenticated
USING (
    public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Service role manages security events"
ON public.security_events
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Incidents RLS
CREATE POLICY "Admins manage security incidents"
ON public.security_incidents
FOR ALL
TO authenticated
USING (
    public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Service role manages security incidents"
ON public.security_incidents
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Incident Events Junction RLS
CREATE POLICY "Admins manage incident events"
ON public.security_incident_events
FOR ALL
TO authenticated
USING (
    public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Service role manages incident events"
ON public.security_incident_events
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
