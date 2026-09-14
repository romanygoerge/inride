const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Secure Serverless OTP Verifier (Vercel Serverless Function)
 * 
 * SECURITY ARCHITECTURE:
 * 1. Validates OTP against hashed database record.
 * 2. Enforces expiration (5 mins) and max attempts (3).
 * 3. Burns OTP immediately after successful verification (anti-replay).
 * 4. Generates authenticated Supabase credentials with a server-only HMAC pepper.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;
const SERVER_AUTH_PEPPER = process.env.SERVER_AUTH_PEPPER || 'inRide_2026_@_Secure_Phone_Salt_#9x8v7u6t5s4r3q2p1_auth';

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

function hashOtp(phone, otp) {
  const salt = process.env.OTP_HASH_SALT || 'inRide_2026_Secure_OTP_Salt_99x';
  return crypto.createHmac('sha256', salt).update(`${phone}:${otp}`).digest('hex');
}

function generateServerAuthKey(phone) {
  const hmac = crypto.createHmac('sha256', SERVER_AUTH_PEPPER);
  hmac.update(phone);
  const digest = hmac.digest('hex');
  return `Sec_P_${digest.substring(0, 32)}!Aa9`;
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
    const { phoneNumber, code } = req.body || {};
    if (!phoneNumber || !code) {
      return res.status(400).json({ success: false, error: 'رقم الهاتف ورمز التحقق مطلوبان.' });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    const trimmedCode = String(code).trim();

    if (trimmedCode.length !== 6) {
      return res.status(400).json({ success: false, error: 'رمز التحقق يجب أن يكون مكوناً من 6 أرقام.' });
    }

    const authEmail = `phone_${cleanPhone}@inride.app`;
    const authKey = generateServerAuthKey(cleanPhone);

    // 1. Demo Mode Check
    const isDemoNumber = (cleanPhone === '201000000000' || cleanPhone.endsWith('000000000'));
    if (isDemoNumber && trimmedCode === '123456') {
      return res.status(200).json({
        success: true,
        verified: true,
        authEmail,
        authKey,
        isDemo: true
      });
    }

    // 2. Database OTP Verification via secure RPC
    if (supabase) {
      const inputHash = hashOtp(cleanPhone, trimmedCode);
      const { data: verifyRes, error: rpcErr } = await supabase.rpc('verify_phone_otp_hash', {
        p_phone: cleanPhone,
        p_otp_hash: inputHash
      });

      if (rpcErr) {
        console.error('[VerifyOtp] RPC error:', rpcErr);
        return res.status(500).json({
          success: false,
          error: 'فشل التحقق من الرمز في قاعدة البيانات.'
        });
      }

      if (!verifyRes || verifyRes.valid !== true) {
        const errorMsg = (verifyRes && verifyRes.error)
          ? verifyRes.error
          : 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
        return res.status(400).json({
          success: false,
          error: errorMsg
        });
      }
    }

    console.log(`[VerifyOtp] OTP successfully verified for ${cleanPhone}`);

    return res.status(200).json({
      success: true,
      verified: true,
      authEmail,
      authKey
    });
  } catch (err) {
    console.error('[VerifyOtp] Internal Server Error:', err);
    return res.status(500).json({ success: false, error: 'حدث خطأ في السيرفر أثناء التحقق من الرمز.' });
  }
};
