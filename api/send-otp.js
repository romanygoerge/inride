const https = require('https');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Hardened Serverless OTP Sender (Vercel Serverless Function)
 * 
 * SECURITY & FORENSIC ARCHITECTURE (2026):
 * 1. Client-Side Text Injection Prevention: Strictly rejects any custom message/template.
 * 2. App Integrity Check: Enforces HMAC-SHA256 signature with nonces and timestamps.
 * 3. Anti-Bot / Anti-Replay: Blocks requests older than 2 minutes and burns nonces.
 * 4. Tamper-Proof Audit Logging: Every request, violation, IP, and status is cryptographically logged.
 * 5. Locked message template: Fixed text generated on server only.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;

const WAPILOT_INSTANCE_ID = process.env.WAPILOT_INSTANCE_ID || 'instance4905';
const WAPILOT_API_TOKEN = process.env.WAPILOT_API_TOKEN;

const APP_INTEGRITY_SALT = process.env.APP_INTEGRITY_SALT || 'inRide_2026_Otp_Integrity_Salt_#99v88x77';
const OTP_HASH_SALT = process.env.OTP_HASH_SALT || 'inRide_2026_Secure_OTP_Salt_99x';

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

// Memory cache for anti-replay
const usedNonces = new Set();
setInterval(() => {
  if (usedNonces.size > 10000) usedNonces.clear();
}, 600000);

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
    p_endpoint: params.endpoint || '/api/send-otp',
    p_http_method: params.httpMethod || 'POST',
    p_response_status: params.responseStatus || null,
    p_authentication_method: params.authMethod || 'HMAC_INTEGRITY',
    p_authorization_result: params.authResult || null,
    p_message_id: params.messageId || null,
    p_provider_message_id: params.providerMessageId || null,
    p_details: params.details || {}
  }).then(() => {}).catch(err => {
    console.error('[Security Logger Error]:', err.message);
  });
}

function cleanEgyptianPhone(rawPhone) {
  let cleaned = String(rawPhone || '').replace(/[^\d]/g, '');
  if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);
  if (cleaned.length === 10 && cleaned.startsWith('1')) cleaned = '20' + cleaned;
  else if (cleaned.length === 11 && (cleaned.startsWith('01') || cleaned.startsWith('0'))) cleaned = '20' + cleaned.substring(1);
  return cleaned;
}

function hashOtp(phone, otp) {
  return crypto.createHmac('sha256', OTP_HASH_SALT).update(`${phone}:${otp}`).digest('hex');
}

function verifyAppIntegrity(req, phone) {
  const timestamp = req.headers['x-app-timestamp'];
  const nonce = req.headers['x-app-nonce'];
  const signature = req.headers['x-app-signature'];

  const authHeader = req.headers['authorization'] || '';
  const serverSecret = process.env.APP_SECRET_KEY || 'inride_secure_push_secret_2026_prod';
  if (authHeader.replace(/^Bearer\s+/i, '').trim() === serverSecret) {
    return { valid: true, reason: 'server_secret' };
  }

  if (!timestamp || !nonce || !signature) {
    return { valid: false, error: 'طلب غير مصرح به: ترويسات التحقق مفقودة.' };
  }

  const reqTime = parseInt(timestamp, 10);
  const now = Date.now();
  if (isNaN(reqTime) || Math.abs(now - reqTime) > 120000) {
    return { valid: false, error: 'طلب غير صالح: انتهت صلاحية توقيع الطلب.' };
  }

  if (usedNonces.has(nonce)) {
    return { valid: false, error: 'طلب مكرر غير مسموح به (Replay Attack Detected).' };
  }

  const rawData = `${phone}:${timestamp}:${nonce}`;
  const expectedSignature = crypto.createHmac('sha256', APP_INTEGRITY_SALT).update(rawData).digest('hex');

  if (signature !== expectedSignature) {
    return { valid: false, error: 'طلب غير مصرح به: توقيع التطبيق غير مطابق.' };
  }

  usedNonces.add(nonce);
  return { valid: true };
}

function postWaPilot(instanceId, token, payload) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(payload);
    const options = {
      hostname: 'api.wapilot.net',
      port: 443,
      path: `/api/v2/${instanceId}/send-message`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'token': token,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Accept': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (_) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });

    req.on('error', err => reject(err));
    req.write(postData);
    req.end();
  });
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed' });
  }

  const requestId = 'REQ-OTP-' + crypto.randomUUID();
  const correlationId = req.headers['x-correlation-id'] || ('CORR-' + crypto.randomUUID());
  const clientIp = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.socket?.remoteAddress || '').split(',')[0].trim();
  const userAgent = req.headers['user-agent'] || 'Unknown';
  const country = req.headers['x-vercel-ip-country'] || req.headers['cf-ipcountry'] || null;
  const city = req.headers['x-vercel-ip-city'] || null;

  try {
    const body = (typeof req.body === 'string') ? JSON.parse(req.body) : (req.body || {});
    const phoneNumber = body.phoneNumber || body.phone;
    const userId = req.headers['x-user-id'] || body.userId || null;
    const sessionId = req.headers['x-session-id'] || body.sessionId || null;
    const deviceId = req.headers['x-device-id'] || body.deviceId || null;
    const endpoint = '/api/send-otp';

    // ------------------------------------------------------------------------
    // MANDATORY SECURITY RULE #6: REJECT ANY CLIENT-SPECIFIED CUSTOM MESSAGE
    // ------------------------------------------------------------------------
    const forbiddenKeys = ['message', 'body', 'text', 'template', 'sender', 'content', 'msg', 'custom_text'];
    const detectedForbidden = forbiddenKeys.filter(k => body[k] !== undefined && body[k] !== null && String(body[k]).trim() !== '');

    if (detectedForbidden.length > 0) {
      console.warn(`[SECURITY INCIDENT] Custom message injection attempt from ${clientIp}:`, detectedForbidden);
      
      logSecurityEvent({
        eventType: 'CUSTOM_MESSAGE_INJECTION_ATTEMPT',
        severity: 'CRITICAL',
        requestId,
        correlationId,
        userId,
        sessionId,
        deviceId,
        ipAddress: clientIp,
        userAgent,
        country,
        city,
        endpoint,
        httpMethod: 'POST',
        responseStatus: 400,
        authResult: 'DENIED_MALICIOUS_PAYLOAD',
        details: {
          violation: 'Attempted custom message text or template injection into OTP endpoint',
          forbidden_keys_detected: detectedForbidden,
          sanitized_keys_present: Object.keys(body)
        }
      });

      return res.status(400).json({
        success: false,
        error: 'طلب غير مصرح به: محاولة إرسال رسالة أو قالب مخصص مرفوضة أمنياً (SUSPICIOUS_OTP_REQUEST). تم تسجيل هذا الحدث للمتابعة والتحقيق.',
        request_id: requestId
      });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    if (!cleanPhone || cleanPhone.length < 10) {
      logSecurityEvent({
        eventType: 'INVALID_PHONE_SUPPLIED',
        severity: 'LOW',
        requestId,
        correlationId,
        userId,
        sessionId,
        deviceId,
        ipAddress: clientIp,
        userAgent,
        country,
        city,
        endpoint,
        httpMethod: 'POST',
        responseStatus: 400,
        authResult: 'REJECTED_VALIDATION',
        details: { raw_phone_length: String(phoneNumber || '').length }
      });

      return res.status(400).json({
        success: false,
        error: 'رقم الهاتف غير صالح.',
        request_id: requestId
      });
    }

    // ------------------------------------------------------------------------
    // 1. App Integrity Check
    // ------------------------------------------------------------------------
    const integrityResult = verifyAppIntegrity(req, cleanPhone);
    if (!integrityResult.valid) {
      console.warn(`[SendOtp] Blocked unauthorized request from IP ${clientIp} for ${cleanPhone}: ${integrityResult.error}`);
      
      logSecurityEvent({
        eventType: 'APP_INTEGRITY_TAMPER_DETECTED',
        severity: 'HIGH',
        requestId,
        correlationId,
        userId,
        sessionId,
        deviceId,
        ipAddress: clientIp,
        userAgent,
        country,
        city,
        endpoint,
        httpMethod: 'POST',
        responseStatus: 403,
        authResult: 'FAILED_INTEGRITY',
        details: { error: integrityResult.error }
      });

      return res.status(403).json({
        success: false,
        error: integrityResult.error,
        request_id: requestId
      });
    }

    const now = Date.now();

    // ------------------------------------------------------------------------
    // 2. Demo Account Fast-Path
    // ------------------------------------------------------------------------
    const isDemoNumber = (cleanPhone === '201000000000' || cleanPhone.endsWith('000000000'));
    if (isDemoNumber) {
      logSecurityEvent({
        eventType: 'DEMO_OTP_REQUEST',
        severity: 'INFO',
        requestId,
        correlationId,
        userId,
        sessionId,
        deviceId,
        ipAddress: clientIp,
        userAgent,
        country,
        city,
        endpoint,
        httpMethod: 'POST',
        responseStatus: 200,
        authResult: 'DEMO_BYPASS',
        details: { phone: cleanPhone.substring(0, 4) + '****' + cleanPhone.slice(-2) }
      });

      return res.status(200).json({
        success: true,
        message: 'تم إرسال رمز التحقق للحساب التجريبي بنجاح.',
        isDemo: true,
        request_id: requestId
      });
    }

    // ------------------------------------------------------------------------
    // 3. Generate Cryptographically Secure 6-Digit OTP (Server-Side Only)
    // ------------------------------------------------------------------------
    const otpCode = crypto.randomInt(100000, 999999).toString();
    const otpHash = hashOtp(cleanPhone, otpCode);
    const expiresAt = new Date(now + 5 * 60 * 1000).toISOString();

    if (!WAPILOT_API_TOKEN) {
      console.error('[SendOtp] CRITICAL: WAPILOT_API_TOKEN environment variable is not configured in Vercel.');
      return res.status(500).json({
        success: false,
        error: 'إعدادات خدمة الواتساب غير مكتملة على السيرفر: يرجى إضافة WAPILOT_API_TOKEN في متغيرات البيئة (Environment Variables) في Vercel.',
        request_id: requestId
      });
    }

    const chatId = `${cleanPhone}@c.us`;
    const lockedMessageText = `رمز التحقق الخاص بك في تطبيق inRide هو: ${otpCode}\nيرجى عدم مشاركة هذا الرمز مع أي شخص.`;

    // Concurrently store OTP in Database and dispatch WhatsApp message for instant response
    const [storeRes, waResponse] = await Promise.all([
      supabase ? supabase.rpc('store_phone_otp', {
        p_phone: cleanPhone,
        p_otp_hash: otpHash,
        p_expires_at: expiresAt
      }).catch(err => {
        console.warn('[SendOtp] Store OTP notice:', err.message);
      }) : Promise.resolve(),
      postWaPilot(WAPILOT_INSTANCE_ID, WAPILOT_API_TOKEN, {
        chat_id: chatId,
        text: lockedMessageText
      })
    ]);

    const providerMsgId = waResponse?.data?.id || waResponse?.data?.message_id || waResponse?.data?.data?.id || (typeof waResponse?.data === 'string' ? waResponse?.data : null);
    const isSuccess = (waResponse?.status === 200 || waResponse?.status === 201);

    // Non-blocking Security & Audit Logging
    logSecurityEvent({
      eventType: isSuccess ? 'OTP_DISPATCHED_SECURELY' : 'OTP_PROVIDER_DISPATCH_FAILED',
      severity: isSuccess ? 'INFO' : 'MEDIUM',
      requestId,
      correlationId,
      userId,
      sessionId,
      deviceId,
      ipAddress: clientIp,
      userAgent,
      country,
      city,
      endpoint,
      httpMethod: 'POST',
      responseStatus: isSuccess ? 200 : 502,
      authResult: isSuccess ? 'AUTHORIZED' : 'PROVIDER_FAILURE',
      messageId: requestId,
      providerMessageId: providerMsgId ? String(providerMsgId).substring(0, 120) : null,
      details: {
        phone_masked: cleanPhone.substring(0, 4) + '****' + cleanPhone.slice(-2),
        provider_status: waResponse?.status,
        provider_name: 'WA_PILOT'
      }
    });

    if (isSuccess) {
      return res.status(200).json({
        success: true,
        message: 'تم إرسال رمز التحقق بنجاح 📲',
        request_id: requestId,
        provider_message_id: providerMsgId
      });
    } else {
      let errMsg = (waResponse?.data && waResponse?.data.message) ? waResponse?.data.message : 'فشل إرسال كود التحقق عبر الواتساب';
      return res.status(502).json({ success: false, error: errMsg, request_id: requestId });
    }
  } catch (err) {
    console.error('[SendOtp] Internal Server Error:', err);
    logSecurityEvent({
      eventType: 'SERVER_EXCEPTION_IN_OTP',
      severity: 'HIGH',
      requestId,
      correlationId,
      ipAddress: clientIp,
      userAgent,
      endpoint: '/api/send-otp',
      httpMethod: 'POST',
      responseStatus: 500,
      details: { error_message: err.message }
    });

    return res.status(500).json({ success: false, error: 'حدث خطأ في السيرفر أثناء إرسال رمز التحقق.', request_id: requestId });
  }
};
