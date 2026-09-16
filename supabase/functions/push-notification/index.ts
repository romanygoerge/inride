import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 405,
    });
  }

  try {
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (!token) {
      return new Response(JSON.stringify({ error: "Unauthorized: Missing authorization header" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
    const serverSecretKey = Deno.env.get("APP_SECRET_KEY");

    let isAuthorized = false;

    // Check 1: Server secret match (for backend-to-backend or admin calls)
    if (serverSecretKey && token === serverSecretKey) {
      isAuthorized = true;
    } else {
      // Check 2: Valid Supabase JWT token of an authenticated user
      const supabase = createClient(supabaseUrl, supabaseAnonKey);
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (user && !error) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      return new Response(JSON.stringify({ error: "Unauthorized: Invalid credentials or session expired" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const { recipientId, target, title, body, type, data, tokens } = await req.json();

    if (!body) {
      return new Response(JSON.stringify({ error: "Missing required parameter: body" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "388d1944-0b83-4942-8f80-b12584def7d7";
    const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");

    if (!ONESIGNAL_REST_API_KEY) {
      return new Response(JSON.stringify({ error: "Server error: ONESIGNAL_REST_API_KEY is not configured." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      });
    }

    // Build payload for OneSignal API
    const osPayload: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title || "inRide", ar: title || "inRide" },
      contents: { en: body, ar: body },
      data: {
        ...(data || {}),
        type: type || "system_alert",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      priority: 10,
    };

    if (Array.isArray(tokens) && tokens.length > 0) {
      osPayload.include_subscription_ids = tokens;
    } else if (recipientId && recipientId !== "ALL_USERS") {
      osPayload.include_aliases = { external_id: [recipientId] };
      osPayload.target_channel = "push";
    } else {
      osPayload.included_segments = ["All"];
    }

    const osResponse = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(osPayload),
    });

    const osResult = await osResponse.json();

    return new Response(JSON.stringify({ success: osResponse.ok, result: osResult }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: osResponse.status,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
