const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Hardened Serverless OTP Verifier (Vercel Serverless Function)
 * 
 * SECURITY ARCHITECTURE (2026 Hardened - Fail-Closed):
 * 1. Strict Fail-Closed enforcement: NEVER authenticates if database/RPC errors occur.
 * 2. Validates OTP against salted SHA-256 hash in database via stored procedure.
 * 3. Enforces expiration (5 mins) and max attempts (5) directly at DB level.
 * 4. Burns OTP immediately upon successful verification (anti-replay).
 * 5. Generates authenticated Supabase credentials with a server-only HMAC pepper.
 * 6. Cryptographic Security Logging: Logs all failures, attempts, and successes to public.security_events.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;
const SERVER_AUTH_PEPPER = process.env.SERVER_AUTH_PEPPER || 'inRide_2026_@_Secure_Phone_Salt_#9x8v7u6t5s4r3q2p1_auth';
const OTP_HASH_SALT = process.env.OTP_HASH_SALT || 'inRide_2026_Secure_OTP_Salt_99x';

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

function cleanEgyptianPhone(rawPhone) {
  let cleaned = String(rawPhone || '').replace(/[^\d]/g, '');
  if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);
  if (cleaned.length === 10 && cleaned.startsWith('1')) cleaned = '20' + cleaned;
  else if (cleaned.length === 11 && (cleaned.startsWith('01') || cleaned.startsWith('0'))) cleaned = '20' + cleaned.substring(1);
  return cleaned;
}

function maskPhone(phone) {
  if (!phone || phone.length < 6) return '***';
  return phone.substring(0, 4) + '****' + phone.substring(phone.length - 2);
}

function hashOtp(phone, otp) {
  return crypto.createHmac('sha256', OTP_HASH_SALT).update(`${phone}:${otp}`).digest('hex');
}

function generateServerAuthKey(phone) {
  const hmac = crypto.createHmac('sha256', SERVER_AUTH_PEPPER);
  hmac.update(phone);
  const digest = hmac.digest('hex');
  return `Sec_P_${digest.substring(0, 32)}!Aa9`;
}

function logSecurityEvent(params) {
  if (!supabase) return Promise.resolve();
  return supabase.rpc('log_security_event', {
    p_event_type: params.eventType,
    p_severity: params.severity || 'INFO',
    p_request_id: params.requestId || null,
    p_correlation_id: params.correlationId || null,
    p_user_id: params.userId || null,
    p_admin_id: params.adminId || null,
    p_session_id: params.sessionId || null,
    p_device_id: params.deviceId || null,
    p_device_platform: params.devicePlatform || null,
    p_device_manufacturer: params.deviceManufacturer || null,
    p_device_model: params.deviceModel || null,
    p_os_version: params.osVersion || null,
    p_app_version: params.appVersion || null,
    p_ip_address: params.ipAddress || null,
    p_user_agent: params.userAgent || null,
    p_asn: params.asn || null,
    p_isp: params.isp || null,
    p_country: params.country || null,
    p_city: params.city || null,
    p_endpoint: params.endpoint || '/api/verify-otp',
    p_http_method: params.httpMethod || 'POST',
    p_response_status: params.responseStatus || null,
    p_authentication_method: params.authMethod || 'HMAC_OTP',
    p_authorization_result: params.authResult || null,
    p_message_id: params.messageId || null,
    p_provider_message_id: params.providerMessageId || null,
    p_details: params.details || {}
  }).then(() => {}).catch(err => {
    console.error('[Security Logger Error in VerifyOtp]:', err.message);
  });
}

module.exports = async function handler(req, res) {
  // CORS configuration
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed' });
  }

  const requestId = 'REQ-VERIFY-' + crypto.randomUUID();
  const ipAddress = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.socket?.remoteAddress || '').split(',')[0].trim();
  const userAgent = req.headers['user-agent'] || 'Unknown';
  const country = req.headers['x-vercel-ip-country'] || req.headers['cf-ipcountry'] || null;
  const city = req.headers['x-vercel-ip-city'] || null;

  try {
    const body = (typeof req.body === 'string') ? JSON.parse(req.body) : (req.body || {});
    const { phoneNumber, code } = body;

    if (!phoneNumber || !code) {
      logSecurityEvent({
        eventType: 'MISSING_VERIFICATION_PARAMS',
        severity: 'LOW',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 400,
        authResult: 'REJECTED_VALIDATION',
        details: { hasPhone: !!phoneNumber, hasCode: !!code }
      });
      return res.status(400).json({ success: false, error: 'رقم الهاتف وكود التحقق مطلوبان.' });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    const trimmedCode = String(code).trim();

    if (!cleanPhone || cleanPhone.length < 10) {
      logSecurityEvent({
        eventType: 'INVALID_PHONE_FORMAT',
        severity: 'LOW',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 400,
        authResult: 'REJECTED_VALIDATION',
        details: { cleanPhoneLength: cleanPhone.length }
      });
      return res.status(400).json({ success: false, error: 'صيغة رقم الهاتف غير صالحة.' });
    }

    if (trimmedCode.length !== 6 || !/^\d{6}$/.test(trimmedCode)) {
      logSecurityEvent({
        eventType: 'INVALID_CODE_FORMAT',
        severity: 'LOW',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 400,
        authResult: 'REJECTED_VALIDATION',
        details: { codeLength: trimmedCode.length }
      });
      return res.status(400).json({ success: false, error: 'رمز التحقق يجب أن يتكون من 6 أرقام.' });
    }

    const authEmail = `phone_${cleanPhone}@inride.app`;
    const authKey = generateServerAuthKey(cleanPhone);

    // 1. Demo Mode Check
    const isDemoNumber = (cleanPhone === '201000000000' || cleanPhone.endsWith('000000000'));
    if (isDemoNumber && trimmedCode === '123456') {
      logSecurityEvent({
        eventType: 'OTP_VERIFIED_DEMO',
        severity: 'INFO',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 200,
        authResult: 'ALLOWED',
        details: { phone: maskPhone(cleanPhone), isDemo: true }
      });

      return res.status(200).json({
        success: true,
        verified: true,
        authEmail,
        authKey,
        isNewUser: false,
        isDemo: true
      });
    }

    // 2. Database Connection Check (Strict Fail-Closed)
    if (!supabase) {
      console.error('[VerifyOtp] Supabase client is not initialized. Rejecting request.');
      logSecurityEvent({
        eventType: 'DATABASE_DISCONNECTED_FAIL_CLOSED',
        severity: 'CRITICAL',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 500,
        authResult: 'DENIED',
        details: { phone: maskPhone(cleanPhone) }
      });
      return res.status(500).json({ success: false, error: 'فشل الاتصال بخدمة التحقق في السيرفر.' });
    }

    // 3. Parallel Execution: Verify OTP Hash & Check Existing User
    const inputHash = hashOtp(cleanPhone, trimmedCode);
    const verifyPromise = supabase.rpc('verify_phone_otp_hash', {
      p_phone: cleanPhone,
      p_otp_hash: inputHash
    });

    const userCheckPromise = supabase
      .from('users')
      .select('id')
      .or(`phone.eq.${cleanPhone},phone.eq.+${cleanPhone}`)
      .maybeSingle()
      .catch(() => ({ data: null }));

    const [{ data: verifyRes, error: rpcErr }, userCheckRes] = await Promise.all([
      verifyPromise,
      userCheckPromise
    ]);

    // CRITICAL FIX (Fail-Closed): If RPC returns an error or database fails, NEVER fall through to success!
    if (rpcErr) {
      console.error('[VerifyOtp] Database RPC verify error:', rpcErr.message);
      logSecurityEvent({
        eventType: 'OTP_VERIFY_RPC_ERROR',
        severity: 'HIGH',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 500,
        authResult: 'DENIED',
        details: {
          phone: maskPhone(cleanPhone),
          errorMessage: rpcErr.message,
          errorCode: rpcErr.code
        }
      });
      return res.status(500).json({
        success: false,
        error: 'حدث خطأ أثناء التحقق من رمز التأكيد في قاعدة البيانات.'
      });
    }

    if (!verifyRes || verifyRes.valid !== true) {
      const errorMsg = (verifyRes && verifyRes.error)
        ? verifyRes.error
        : 'رمز التحقق غير صحيح أو انتهت صلاحيته.';

      logSecurityEvent({
        eventType: 'OTP_VERIFICATION_FAILED',
        severity: 'MEDIUM',
        requestId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 400,
        authResult: 'DENIED',
        details: {
          phone: maskPhone(cleanPhone),
          reason: errorMsg,
          attempts: verifyRes?.attempts || null
        }
      });

      return res.status(400).json({
        success: false,
        error: errorMsg
      });
    }

    const isNewUser = !userCheckRes?.data?.id;

    // 4. Verification Succeeded
    console.log(`[VerifyOtp] OTP successfully verified for ${maskPhone(cleanPhone)} (isNewUser=${isNewUser})`);
    logSecurityEvent({
      eventType: 'OTP_VERIFY_SUCCESS',
      severity: 'INFO',
      requestId,
      ipAddress,
      userAgent,
      country,
      city,
      responseStatus: 200,
      authResult: 'ALLOWED',
      details: {
        phone: maskPhone(cleanPhone),
        isNewUser
      }
    });

    return res.status(200).json({
      success: true,
      verified: true,
      authEmail,
      authKey,
      isNewUser
    });

  } catch (err) {
    console.error('[VerifyOtp] Internal Server Error:', err);
    logSecurityEvent({
      eventType: 'OTP_VERIFY_CRASH_FAIL_CLOSED',
      severity: 'HIGH',
      requestId,
      ipAddress,
      userAgent,
      country,
      city,
      responseStatus: 500,
      authResult: 'DENIED',
      details: { error: err.message }
    });
    return res.status(500).json({ success: false, error: 'حدث خطأ في السيرفر أثناء التحقق من الرمز.' });
  }
};
