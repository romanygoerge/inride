const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '388d1944-0b83-4942-8f80-b12584def7d7';
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY || Buffer.from('b3NfdjJfYXBwX2hjZ3JzcmFscW5ldWZkNGF3ZXN5anh4eDI3N3Ayb2Vwdm95dWJlbWltcmhrc2ZteHl0bHBvNmtjeXFzcjV3ZXFwcmNicnVzeDRxcXRsbnM3dHgzanNhdnc3amp3a2RqNXB6ZGh6YmE=', 'base64').toString('utf8');

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

  // Authentication check: Accepts Supabase User Auth JWT or Server Secret Key
  const authHeader = req.headers['authorization'] || '';
  const secretKey = process.env.APP_SECRET_KEY || process.env.APP_PUSH_SECRET_KEY || 'inride_secure_push_secret_2026_prod';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();

  let isAuthorized = false;

  if (token) {
    if (token === secretKey) {
      isAuthorized = true;
    } else if (token.startsWith('eyJ')) {
      // Validate Supabase User JWT session
      try {
        const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'apikey': SUPABASE_KEY
          }
        });
        if (userRes.ok) {
          const userData = await userRes.json();
          if (userData && userData.id) {
            isAuthorized = true;
          }
        }
      } catch (authErr) {
        console.warn('[PushNotification] JWT validation error:', authErr.message);
      }
    }
  }

  if (!isAuthorized) {
    console.warn('[PushNotification] Blocked unauthorized request attempt.');
    return res.status(401).json({ error: 'Unauthorized: Valid User Session or Authorization header required.' });
  }

  try {
    const { recipientId, target, title, body, type, data, tokens } = req.body || {};

    if (!body) {
      return res.status(400).json({ error: 'Missing required parameter: body' });
    }

    // A notification is a broadcast if explicitly targeted to all, drivers, riders, or city!
    const isBroadcast = (target === 'all' || target === 'drivers' || target === 'riders' || target === 'city' || recipientId === 'ALL_USERS' || recipientId === 'broadcast' || recipientId === 'DRIVERS' || recipientId === 'RIDERS');

    // For non-broadcast notifications, recipientId is strictly required
    if (!isBroadcast) {
      if (!recipientId || typeof recipientId !== 'string' || recipientId.trim() === '' || recipientId === 'null' || recipientId === 'undefined') {
        console.warn('[PushNotification] BLOCKED: recipientId is missing or invalid for private notification.');
        return res.status(400).json({ error: 'recipientId is strictly required for user-targeted notification' });
      }
    }

    console.log(`[PushNotification] Dispatching push: ${isBroadcast ? 'BROADCAST (' + (target || recipientId) + ')' : 'User: ' + recipientId}, type: ${type || 'system_alert'}`);

    // Fetch active device tokens from Supabase user_devices via REST API (Zero dependency)
    let activeTokens = [];
    if (Array.isArray(tokens)) {
      tokens.forEach(t => {
        if (t && typeof t === 'string' && t.length > 10 && !activeTokens.includes(t)) {
          activeTokens.push(t);
        }
      });
    }

    try {
      const url = isBroadcast
        ? `${SUPABASE_URL}/rest/v1/user_devices?is_active=eq.true&select=device_token`
        : `${SUPABASE_URL}/rest/v1/user_devices?user_id=eq.${encodeURIComponent(recipientId)}&is_active=eq.true&select=device_token`;
      
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
    stringifiedData.type = type || (isBroadcast ? 'system_broadcast' : 'support_chat');

    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: 'push',
      headings: { en: title || 'inRide', ar: title || 'تطبيق inRide' },
      contents: { en: body, ar: body },
      data: stringifiedData,
      android_accent_color: 'FF1976D2',
      android_channel_id: 'high_importance_channel',
      android_sound: 'notification',
      ios_sound: 'default',
      sound: 'default',
      priority: 10,
      android_visibility: 1,
      ios_interruption_level: 'time-sensitive',
      ttl: 86400,
      small_icon: 'ic_launcher',
    };

    if (isBroadcast) {
      if (target === 'drivers' || recipientId === 'DRIVERS') {
        payload.filters = [{ field: 'tag', key: 'role', relation: '=', value: 'driver' }];
      } else if (target === 'riders' || recipientId === 'RIDERS') {
        payload.filters = [{ field: 'tag', key: 'role', relation: '=', value: 'rider' }];
      } else {
        payload.included_segments = ['Subscribed Users', 'Total Subscriptions'];
      }
      if (activeTokens.length > 0) {
        payload.include_subscription_ids = activeTokens.slice(0, 2000);
      }
    } else {
      payload.include_aliases = { external_id: [recipientId] };
      if (activeTokens.length > 0) {
        payload.include_subscription_ids = activeTokens;
      }
    }

    const headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': `Key ${ONESIGNAL_REST_API_KEY}`
    };

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
