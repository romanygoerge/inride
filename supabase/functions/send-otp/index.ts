import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-timestamp, x-app-nonce, x-app-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const APP_INTEGRITY_SALT = Deno.env.get("APP_INTEGRITY_SALT") || "inRide_2026_Otp_Integrity_Salt_#99v88x77";
const OTP_HASH_SALT = Deno.env.get("OTP_HASH_SALT") || "inRide_2026_Secure_OTP_Salt_99x";

const usedNonces = new Set<string>();

function cleanEgyptianPhone(rawPhone: string): string {
  let cleaned = String(rawPhone || "").replace(/[^\d]/g, "");
  if (cleaned.startsWith("00")) cleaned = cleaned.substring(2);
  if (cleaned.length === 10 && cleaned.startsWith("1")) cleaned = "20" + cleaned;
  else if (cleaned.length === 11 && (cleaned.startsWith("01") || cleaned.startsWith("0"))) cleaned = "20" + cleaned.substring(1);
  return cleaned;
}

async function hmacSha256(key: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(data));
  return Array.from(new Uint8Array(signature)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function verifyAppIntegrity(req: Request, phone: string): Promise<{ valid: boolean; error?: string }> {
  const timestamp = req.headers.get("x-app-timestamp");
  const nonce = req.headers.get("x-app-nonce");
  const signature = req.headers.get("x-app-signature");

  const authHeader = req.headers.get("authorization") || "";
  const serverSecret = Deno.env.get("APP_SECRET_KEY") || "inride_secure_push_secret_2026_prod";
  if (authHeader.replace(/^Bearer\s+/i, "").trim() === serverSecret) {
    return { valid: true };
  }

  if (!timestamp || !nonce || !signature) {
    return { valid: false, error: "طلب غير مصرح به: ترويسات التحقق مفقودة." };
  }

  const reqTime = parseInt(timestamp, 10);
  const now = Date.now();
  if (isNaN(reqTime) || Math.abs(now - reqTime) > 120000) {
    return { valid: false, error: "طلب غير صالح: انتهت صلاحية توقيع الطلب." };
  }

  if (usedNonces.has(nonce)) {
    return { valid: false, error: "طلب مكرر غير مسموح به." };
  }

  const rawData = `${phone}:${timestamp}:${nonce}`;
  const expectedSignature = await hmacSha256(APP_INTEGRITY_SALT, rawData);

  if (signature !== expectedSignature) {
    return { valid: false, error: "طلب غير مصرح به: توقيع التطبيق غير مطابق." };
  }

  usedNonces.add(nonce);
  return { valid: true };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method Not Allowed" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 405,
    });
  }

  try {
    const { phoneNumber } = await req.json().catch(() => ({}));
    if (!phoneNumber) {
      return new Response(JSON.stringify({ success: false, error: "رقم الهاتف مطلوب." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    if (cleanPhone.length < 10) {
      return new Response(JSON.stringify({ success: false, error: "رقم الهاتف غير صالح." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const clientIp = (req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || "unknown").split(",")[0].trim();
    const userAgent = req.headers.get("user-agent") || "unknown";

    // 1. App Integrity Check
    const integrityResult = await verifyAppIntegrity(req, cleanPhone);
    if (!integrityResult.valid) {
      return new Response(JSON.stringify({ success: false, error: integrityResult.error }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      });
    }

    // 2. Database Rate Limiting
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY") || "";

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey);
      const { data: dbCheck, error: dbErr } = await supabase.rpc("verify_and_record_otp_request", {
        p_phone: cleanPhone,
        p_ip: clientIp,
        p_user_agent: userAgent,
      });

      if (!dbErr && dbCheck && dbCheck.allowed === false) {
        return new Response(JSON.stringify({ success: false, error: dbCheck.error || "يرجى الانتظار دقيقة واحدة." }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 429,
        });
      }
    }

    // 3. Demo Account Fast-Pass
    const isDemoNumber = (cleanPhone === "201000000000" || cleanPhone.endsWith("000000000"));
    if (isDemoNumber) {
      return new Response(JSON.stringify({ success: true, message: "تم إرسال رمز التحقق للحساب التجريبي بنجاح.", isDemo: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 4. Generate OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await hmacSha256(OTP_HASH_SALT, `${cleanPhone}:${otp}`);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey);
      await supabase.rpc("store_phone_otp", {
        p_phone: cleanPhone,
        p_otp_hash: otpHash,
        p_expires_at: expiresAt,
      });
    }

    // 5. Send WA Pilot
    const instanceId = Deno.env.get("WAPILOT_INSTANCE_ID") || "instance4905";
    const token = Deno.env.get("WAPILOT_API_TOKEN");

    if (!token) {
      return new Response(JSON.stringify({ success: false, error: "WAPILOT_API_TOKEN is not configured in Supabase secrets." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const message = `رمز التحقق الخاص بك لتطبيق inRide هو: *${otp}*\n\nيرجى عدم مشاركة هذا الرمز مع أي شخص.`;

    const waRes = await fetch(`https://api.wapilot.net/api/v2/${instanceId}/send-message`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "token": token,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: `${cleanPhone}@c.us`,
        text: message,
      }),
    });

    if (!waRes.ok) {
      return new Response(JSON.stringify({ success: false, error: "فشل إرسال كود التحقق عبر الواتساب." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 502,
      });
    }

    return new Response(JSON.stringify({ success: true, message: "تم إرسال رمز التحقق بنجاح 📲" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: (err as Error).message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
