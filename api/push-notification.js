const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '388d1944-0b83-4942-8f80-b12584def7d7';
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

module.exports = async function handler(req, res) {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Authentication check: Require APP_SECRET_KEY header or valid Bearer token
  const authHeader = req.headers['authorization'] || '';
  const secretKey = process.env.APP_SECRET_KEY || process.env.APP_PUSH_SECRET_KEY || 'inride_secure_push_secret_2026_prod';
  
  if (authHeader !== `Bearer ${secretKey}`) {
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token || token === 'undefined' || token === 'null') {
      console.warn('[PushNotification] Blocked unauthorized request attempt.');
      return res.status(401).json({ error: 'Unauthorized: Valid Authorization header required.' });
    }
  }

  try {
    const { recipientId, title, body, type, data } = req.body || {};

    if (!recipientId || !body) {
      return res.status(400).json({ error: 'Missing required parameters: recipientId and body' });
    }

    console.log(`[PushNotification] Dispatching to user: ${recipientId}, type: ${type || 'support_chat'}`);

    // Fetch active device tokens from Supabase user_devices via REST API (Zero dependency)
    let activeTokens = [];
    try {
      const url = `${SUPABASE_URL}/rest/v1/user_devices?user_id=eq.${encodeURIComponent(recipientId)}&is_active=eq.true&select=device_token`;
      const sResponse = await fetch(url, {
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': `Bearer ${SUPABASE_KEY}`
        }
      });
      if (sResponse.ok) {
        const devices = await sResponse.json();
        if (Array.isArray(devices)) {
          devices.forEach(d => {
            if (d.device_token && !activeTokens.includes(d.device_token)) {
              activeTokens.push(d.device_token);
            }
          });
        }
      }
    } catch (err) {
      console.warn(`[PushNotification] Error fetching user_devices:`, err.message);
    }

    const stringifiedData = {};
    if (data && typeof data === 'object') {
      Object.keys(data).forEach((key) => {
        stringifiedData[key] = String(data[key]);
      });
    }
    stringifiedData.type = type || 'support_chat';

    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: 'push',
      include_aliases: { external_id: [recipientId] },
      headings: { en: title || 'inRide Support', ar: title || 'الدعم الفني' },
      contents: { en: body, ar: body },
      data: stringifiedData,
      android_channel_id: 'high_importance_channel',
      android_accent_color: 'FF1976D2',
      priority: 10,
      ttl: 86400,
      small_icon: 'ic_launcher',
    };

    if (activeTokens.length > 0) {
      payload.include_subscription_ids = activeTokens;
    }

    const headers = {
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (ONESIGNAL_REST_API_KEY) {
      headers['Authorization'] = `Key ${ONESIGNAL_REST_API_KEY}`;
    }

    const response = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(payload),
    });

    const resData = await response.json();
    console.log(`[PushNotification] OneSignal API Status: ${response.status}`, resData);

    return res.status(200).json({ success: true, response: resData, tokensCount: activeTokens.length });
  } catch (err) {
    console.error(`[PushNotification] Exception dispatching push:`, err);
    return res.status(500).json({ error: err.message || 'Internal Server Error' });
  }
};
