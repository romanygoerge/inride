const https = require('https');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Secure Serverless OTP Sender (Vercel Serverless Function)
 * 
 * SECURITY ARCHITECTURE:
 * 1. Master WA Pilot token is kept strictly on the server (never exposed to client).
 * 2. Rate limiting: strictly 1 OTP per 60 seconds per phone, max 5 per hour.
 * 3. Locked message template: clients cannot supply or customize message text.
 * 4. Cryptographic OTP generation and storage of salted SHA-256 hash in Supabase.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;
const WAPILOT_INSTANCE_ID = process.env.WAPILOT_INSTANCE_ID || 'instance4905';
const WAPILOT_API_TOKEN = process.env.WAPILOT_API_TOKEN;

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

// In-memory rate limiting fallback cache
const rateLimitMap = new Map();

function cleanEgyptianPhone(rawPhone) {
  let cleaned = String(rawPhone || '').replace(/[^\d]/g, '');
  if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);
  if (cleaned.length === 10 && cleaned.startsWith('1')) cleaned = '20' + cleaned;
  else if (cleaned.length === 11 && (cleaned.startsWith('01') || cleaned.startsWith('0'))) cleaned = '20' + cleaned.substring(1);
  return cleaned;
}

function hashOtp(phone, otp) {
  const salt = process.env.OTP_HASH_SALT || 'inRide_2026_Secure_OTP_Salt_99x';
  return crypto.createHmac('sha256', salt).update(`${phone}:${otp}`).digest('hex');
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
  // CORS configuration
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed' });
  }

  try {
    const { phoneNumber } = req.body || {};
    if (!phoneNumber) {
      return res.status(400).json({ success: false, error: 'رقم الهاتف مطلوب.' });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    if (cleanPhone.length < 10) {
      return res.status(400).json({ success: false, error: 'رقم الهاتف غير صالح.' });
    }

    const now = Date.now();

    // 1. Rate Limiting Check (Server Memory Sliding Window)
    const rateData = rateLimitMap.get(cleanPhone) || { lastRequest: 0, countPerHour: 0, windowStart: now };
    if (now - rateData.windowStart > 3600000) {
      rateData.countPerHour = 0;
      rateData.windowStart = now;
    }

    if (now - rateData.lastRequest < 60000) {
      const waitSeconds = Math.ceil((60000 - (now - rateData.lastRequest)) / 1000);
      return res.status(429).json({
        success: false,
        error: `يرجى الانتظار ${waitSeconds} ثانية قبل طلب رمز جديد.`
      });
    }

    if (rateData.countPerHour >= 5) {
      return res.status(429).json({
        success: false,
        error: 'لقد تجاوزت الحد الأقصى للمحاولات (5 محاولات بالساعة). يرجى المحاولة لاحقاً.'
      });
    }

    // 2. Database Rate Limiting Check (if Supabase Service Role is active)
    if (supabase) {
      try {
        const sixtySecAgo = new Date(now - 60000).toISOString();
        const { data: recentRequests } = await supabase
          .from('otp_requests')
          .select('created_at')
          .eq('phone_number', cleanPhone)
          .gte('created_at', sixtySecAgo)
          .limit(1);

        if (recentRequests && recentRequests.length > 0) {
          return res.status(429).json({
            success: false,
            error: 'يرجى الانتظار دقيقة واحدة قبل طلب رمز جديد.'
          });
        }
      } catch (dbErr) {
        console.warn('[SendOtp] DB check notice:', dbErr.message);
      }
    }

    // 3. Demo Account Fast-Path
    const isDemoNumber = (cleanPhone === '201000000000' || cleanPhone.endsWith('000000000'));
    if (isDemoNumber) {
      return res.status(200).json({
        success: true,
        message: 'تم إرسال رمز التحقق للحساب التجريبي بنجاح.',
        isDemo: true
      });
    }

    // 4. Generate Cryptographically Secure 6-Digit OTP
    const otpCode = crypto.randomInt(100000, 999999).toString();
    const otpHash = hashOtp(cleanPhone, otpCode);
    const expiresAt = new Date(now + 5 * 60 * 1000).toISOString(); // 5 minutes expiration

    // 5. Store OTP in Database via secure RPC
    if (supabase) {
      try {
        const { data: rpcRes, error: rpcErr } = await supabase.rpc('store_phone_otp', {
          p_phone: cleanPhone,
          p_otp_hash: otpHash,
          p_expires_at: expiresAt
        });
        if (rpcRes && rpcRes.rate_limited) {
          return res.status(429).json({
            success: false,
            error: rpcRes.error || 'يرجى الانتظار دقيقة واحدة قبل طلب رمز جديد.'
          });
        }
      } catch (insErr) {
        console.warn('[SendOtp] DB insert notice:', insErr.message);
      }
    }

    // 6. Send OTP via WA Pilot using LOCKED template
    const chatId = `${cleanPhone}@c.us`;
    const lockedMessageText = `رمز التحقق الخاص بك في تطبيق inRide هو: ${otpCode}\nيرجى عدم مشاركة هذا الرمز مع أي شخص.`;

    const waResponse = await postWaPilot(WAPILOT_INSTANCE_ID, WAPILOT_API_TOKEN, {
      chat_id: chatId,
      text: lockedMessageText
    });

    if (waResponse.status === 200 || waResponse.status === 201) {
      // Update rate limiter on success
      rateData.lastRequest = now;
      rateData.countPerHour += 1;
      rateLimitMap.set(cleanPhone, rateData);

      console.log(`[SendOtp] Successfully dispatched OTP to ${chatId}`);
      return res.status(200).json({
        success: true,
        message: 'تم إرسال رمز التحقق بنجاح 📲'
      });
    } else {
      console.error('[SendOtp] WA Pilot delivery error:', waResponse);
      const errMsg = (waResponse.data && waResponse.data.message) ? waResponse.data.message : 'فشل إرسال كود التحقق عبر الواتساب';
      return res.status(502).json({ success: false, error: errMsg });
    }
  } catch (err) {
    console.error('[SendOtp] Internal Server Error:', err);
    return res.status(500).json({ success: false, error: 'حدث خطأ في السيرفر أثناء إرسال رمز التحقق.' });
  }
};
