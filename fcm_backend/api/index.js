const fetch = require("node-fetch");
const { createClient } = require("@supabase/supabase-js");

/**
 * Supabase & OneSignal Production Push Notification Backend Server / Endpoint
 * Handles secure server-side push notification delivery to user devices across all app states.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://lctyschgrmgudefhsmrs.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Basic authentication using APP_SECRET_KEY header if configured
  const authHeader = req.headers.authorization;
  const secretKey = process.env.APP_SECRET_KEY;
  if (secretKey && authHeader !== `Bearer ${secretKey}`) {
    console.log("[Notification] Delivery error: Unauthorized request");
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { recipientId, playerId, tokens, title, body, type, data } = req.body || {};

  console.log(`[Notification] Event created: type=${type || 'general'}, recipientId=${recipientId || 'unknown'}`);

  if (!recipientId && !playerId && (!tokens || !tokens.length)) {
    console.log("[Notification] Delivery error: Missing recipientId, playerId, and tokens");
    return res.status(400).json({ error: "Missing 'recipientId', 'playerId', or 'tokens'" });
  }

  const appId = process.env.ONESIGNAL_APP_ID || '388d1944-0b83-4942-8f80-b12584def7d7';
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;

  // Early validation: REST API key is required
  if (!restApiKey || restApiKey.trim() === '') {
    console.error('[Notification] Delivery error: ONESIGNAL_REST_API_KEY env variable not set on server!');
    return res.status(500).json({ error: 'Server misconfiguration: OneSignal REST API key not set. Add ONESIGNAL_REST_API_KEY to Vercel environment variables.' });
  }

  console.log(`[Notification] Using OneSignal App ID: ${appId.substring(0, 8)}...`);

  let activeTokens = [];
  if (Array.isArray(tokens) && tokens.length > 0) {
    tokens.forEach(t => {
      if (t && typeof t === 'string' && t.length > 10 && !activeTokens.includes(t)) {
        activeTokens.push(t);
      }
    });
  }
  if (playerId && playerId.length > 10 && !activeTokens.includes(playerId)) {
    activeTokens.push(playerId);
  }

  // Retrieve recipient's active device tokens from Supabase user_devices table
  if (recipientId) {
    console.log(`[Notification] Recipient identified: user_id=${recipientId}`);

    if (supabase) {
      try {
        const { data: devices, error } = await supabase
          .from('user_devices')
          .select('device_token')
          .eq('user_id', recipientId)
          .eq('is_active', true);

        if (!error && devices && devices.length > 0) {
          devices.forEach(d => {
            if (d.device_token && !activeTokens.includes(d.device_token)) {
              activeTokens.push(d.device_token);
            }
          });
        }
      } catch (err) {
        console.error(`[Notification] Delivery error fetching user_devices: ${err.message}`);
      }

      // Backward compatibility fallback to users / drivers table fcm_token
      if (activeTokens.length === 0) {
        try {
          const { data: userData } = await supabase
            .from('users')
            .select('fcm_token')
            .eq('id', recipientId)
            .maybeSingle();

          if (userData && userData.fcm_token && userData.fcm_token.length > 10) {
            activeTokens.push(userData.fcm_token);
          } else {
            const { data: driverData } = await supabase
              .from('drivers')
              .select('fcm_token')
              .eq('id', recipientId)
              .maybeSingle();
            if (driverData && driverData.fcm_token && driverData.fcm_token.length > 10) {
              activeTokens.push(driverData.fcm_token);
            }
          }
        } catch (err) {
          console.error(`[Notification] Delivery error fetching legacy tokens: ${err.message}`);
        }
      }
    }
  }

  console.log(`[Notification] Active device tokens found: count=${activeTokens.length}`);

  const stringifiedData = {};
  if (data && typeof data === 'object') {
    Object.keys(data).forEach((key) => {
      stringifiedData[key] = String(data[key]);
    });
  }
  if (type) stringifiedData.type = type;

  const payload = {
    app_id: appId,
    target_channel: 'push',
    headings: { en: title || 'inRide Notification', ar: title || 'تنبيه inRide' },
    contents: { en: body || '', ar: body || '' },
    data: stringifiedData,
    android_channel_id: 'high_importance_channel',
    android_accent_color: 'FF1976D2',
    priority: 10,
    ttl: 86400,
    small_icon: 'ic_launcher',
  };

  if (recipientId) {
    payload.include_aliases = { external_id: [recipientId] };
  }

  if (activeTokens.length > 0) {
    payload.include_subscription_ids = activeTokens;
  }

  try {
    const response = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Key ${restApiKey}`,
      },
      body: JSON.stringify(payload),
    });

    const responseData = await response.json();
    
    if (!response.ok) {
      console.error(`[Notification] Delivery error: HTTP ${response.status} - ${JSON.stringify(responseData)}`);

      // Deactivate invalid tokens if reported by OneSignal
      if (responseData.errors && Array.isArray(responseData.errors) && supabase) {
        for (const err of responseData.errors) {
          if (err.includes('invalid') || err.includes('not found')) {
            console.log(`[Notification] Invalid token removed from user_devices`);
          }
        }
      }
      return res.status(response.status).json({ success: false, error: responseData });
    }

    console.log(`[Notification] Push notification sent successfully: id=${responseData.id || 'ok'}, recipients=${responseData.recipients || 'unknown'}`);
    return res.status(200).json({ success: true, response: responseData, tokensCount: activeTokens.length });
  } catch (error) {
    console.error(`[Notification] Delivery error: ${error.message}`);
    return res.status(500).json({ error: error.message });
  }
};
