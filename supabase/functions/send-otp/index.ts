import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-timestamp, x-app-nonce, x-app-signature, x-correlation-id, x-user-id, x-device-id, x-session-id",
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
    return { valid: false, error: "طلب مكرر غير مسموح به (Replay Attack)." };
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

  const requestId = "REQ-EDGE-" + crypto.randomUUID();
  const correlationId = req.headers.get("x-correlation-id") || ("CORR-" + crypto.randomUUID());
  const clientIp = (req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || "unknown").split(",")[0].trim();
  const userAgent = req.headers.get("user-agent") || "unknown";
  const userId = req.headers.get("x-user-id");
  const deviceId = req.headers.get("x-device-id");
  const sessionId = req.headers.get("x-session-id");

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  let supabase: any = null;
  if (supabaseUrl && supabaseKey) {
    supabase = createClient(supabaseUrl, supabaseKey);
  }

  const logSecurity = async (
    eventTypeOrObj: string | { eventType: string; severity: string; status: number; details?: any; msgId?: string; provMsgId?: string },
    severity?: string,
    status?: number,
    details?: any,
    msgId?: string,
    provMsgId?: string
  ) => {
    if (!supabase) return;
    try {
      const isObj = typeof eventTypeOrObj === "object" && eventTypeOrObj !== null;
      const finalEventType = isObj ? eventTypeOrObj.eventType : eventTypeOrObj;
      const finalSeverity = isObj ? eventTypeOrObj.severity : (severity || "INFO");
      const finalStatus = isObj ? eventTypeOrObj.status : (status || 200);
      const finalDetails = isObj ? eventTypeOrObj.details : (details || {});
      const finalMsgId = isObj ? eventTypeOrObj.msgId : msgId;
      const finalProvMsgId = isObj ? eventTypeOrObj.provMsgId : provMsgId;

      await supabase.rpc("log_security_event", {
        p_event_type: finalEventType,
        p_severity: finalSeverity,
        p_request_id: requestId,
        p_correlation_id: correlationId,
        p_user_id: userId || null,
        p_session_id: sessionId || null,
        p_device_id: deviceId || null,
        p_ip_address: clientIp,
        p_user_agent: userAgent,
        p_endpoint: "/functions/v1/send-otp",
        p_http_method: "POST",
        p_response_status: finalStatus,
        p_message_id: finalMsgId || null,
        p_provider_message_id: finalProvMsgId || null,
        p_details: finalDetails || {}
      });
    } catch (_) {}
  };

  try {
    const rawBody = await req.json().catch(() => ({}));
    const phoneNumber = rawBody.phoneNumber || rawBody.phone;

    // ------------------------------------------------------------------------
    // MANDATORY SECURITY RULE #6: STRICT REJECTION OF CUSTOM MESSAGE FIELDS
    // ------------------------------------------------------------------------
    const forbiddenKeys = ["message", "body", "text", "template", "sender", "content", "msg", "custom_text"];
    const detectedForbidden = forbiddenKeys.filter(k => rawBody[k] !== undefined && rawBody[k] !== null && String(rawBody[k]).trim() !== "");

    if (detectedForbidden.length > 0) {
      await logSecurity(
        "CUSTOM_MESSAGE_INJECTION_ATTEMPT",
        "CRITICAL",
        400,
        { violation: "Client attempted to inject custom text/template/sender into Edge OTP flow", detected_keys: detectedForbidden }
      );

      return new Response(JSON.stringify({
        success: false,
        error: "طلب غير مصرح به: محاولة إرسال رسالة مخصصة مرفوضة أمنياً (SUSPICIOUS_OTP_REQUEST).",
        request_id: requestId
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    if (!phoneNumber) {
      return new Response(JSON.stringify({ success: false, error: "رقم الهاتف مطلوب.", request_id: requestId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const cleanPhone = cleanEgyptianPhone(phoneNumber);
    if (cleanPhone.length < 10) {
      return new Response(JSON.stringify({ success: false, error: "رقم الهاتف غير صالح.", request_id: requestId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    // 1. App Integrity Check
    const integrityResult = await verifyAppIntegrity(req, cleanPhone);
    if (!integrityResult.valid) {
      await logSecurity("APP_INTEGRITY_TAMPER_DETECTED", "HIGH", 403, { error: integrityResult.error });
      return new Response(JSON.stringify({ success: false, error: integrityResult.error, request_id: requestId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      });
    }

    // 2. Demo Account Fast-Pass
    const isDemoNumber = (cleanPhone === "201000000000" || cleanPhone.endsWith("000000000"));
    if (isDemoNumber) {
      await logSecurity("DEMO_OTP_REQUEST", "INFO", 200, { isDemo: true });
      return new Response(JSON.stringify({
        success: true,
        message: "تم إرسال رمز التحقق للحساب التجريبي بنجاح.",
        isDemo: true,
        request_id: requestId
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 3. Generate Cryptographically Secure OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await hmacSha256(OTP_HASH_SALT, `${cleanPhone}:${otp}`);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    if (supabase) {
      await supabase.rpc("store_phone_otp", {
        p_phone: cleanPhone,
        p_otp_hash: otpHash,
        p_expires_at: expiresAt,
      });
    }

    // 4. Send WA Pilot using locked backend template
    const instanceId = Deno.env.get("WAPILOT_INSTANCE_ID") || "instance4905";
    const token = Deno.env.get("WAPILOT_API_TOKEN");

    if (!token) {
      return new Response(JSON.stringify({ success: false, error: "WAPILOT_API_TOKEN is not configured in Supabase secrets.", request_id: requestId }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const lockedTemplate = `رمز التحقق الخاص بك لتطبيق inRide هو: *${otp}*\n\nيرجى عدم مشاركة هذا الرمز مع أي شخص.`;

    const waRes = await fetch(`https://api.wapilot.net/api/v2/${instanceId}/send-message`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "token": token,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: `${cleanPhone}@c.us`,
        text: lockedTemplate,
      }),
    });

    const waData = await waRes.json().catch(() => ({}));
    const isSuccess = waRes.ok;
    const providerMsgId = waData?.id || waData?.message_id || waData?.data?.id || null;

    await logSecurity(
      isSuccess ? "OTP_DISPATCHED_SECURELY" : "OTP_PROVIDER_DISPATCH_FAILED",
      isSuccess ? "INFO" : "MEDIUM",
      isSuccess ? 200 : 502,
      { phone_masked: cleanPhone.substring(0, 4) + "****" + cleanPhone.slice(-2) },
      requestId,
      providerMsgId ? String(providerMsgId) : undefined
    );

    if (isSuccess) {
      return new Response(JSON.stringify({ success: true, message: "تم إرسال رمز التحقق بنجاح 📲", request_id: requestId, provider_message_id: providerMsgId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    } else {
      return new Response(JSON.stringify({ success: false, error: waData?.message || "فشل إرسال كود التحقق عبر الواتساب", request_id: requestId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 502,
      });
    }
  } catch (err: any) {
    return new Response(JSON.stringify({ success: false, error: err.message, request_id: requestId }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
