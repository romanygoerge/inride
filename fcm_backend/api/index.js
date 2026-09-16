const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '388d1944-0b83-4942-8f80-b12584def7d7';
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

async function logSecurityEvent(params) {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/log_security_event`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
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
        p_endpoint: params.endpoint || '/api/push-notification',
        p_http_method: params.httpMethod || 'POST',
        p_response_status: params.responseStatus || null,
        p_authentication_method: params.authMethod || 'BEARER_TOKEN',
        p_authorization_result: params.authResult || null,
        p_message_id: params.messageId || null,
        p_provider_message_id: params.providerMessageId || null,
        p_details: params.details || {}
      })
    });
    if (!res.ok) {
      console.warn('[PushSecurityLogger] HTTP error logging security event:', res.status);
    }
  } catch (err) {
    console.error('[PushSecurityLogger] Exception:', err.message);
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const requestId = 'push_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
  const ipAddress = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || '127.0.0.1';
  const userAgent = req.headers['user-agent'] || 'Unknown';
  const country = req.headers['x-vercel-ip-country'] || 'EG';
  const city = req.headers['x-vercel-ip-city'] || 'Cairo';

  const authHeader = req.headers['authorization'] || '';
  const secretKey = process.env.APP_SECRET_KEY || process.env.APP_PUSH_SECRET_KEY || 'inride_secure_push_secret_2026_prod';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();

  let isAuthorized = false;
  let isServerSecret = false;
  let callerUserId = null;
  let isUserAdmin = false;

  if (token) {
    if (token === secretKey) {
      isAuthorized = true;
      isServerSecret = true;
    } else if (token.startsWith('eyJ')) {
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
            callerUserId = userData.id;

            if (userData.app_metadata?.role === 'admin' || userData.user_metadata?.role === 'admin') {
              isUserAdmin = true;
            } else {
              try {
                const adminCheckRes = await fetch(
                  `${SUPABASE_URL}/rest/v1/admins?id=eq.${encodeURIComponent(callerUserId)}&is_active=eq.true&select=id`,
                  {
                    headers: {
                      'apikey': SUPABASE_KEY,
                      'Authorization': `Bearer ${SUPABASE_KEY}`
                    }
                  }
                );
                if (adminCheckRes.ok) {
                  const adminRows = await adminCheckRes.json();
                  if (Array.isArray(adminRows) && adminRows.length > 0) {
                    isUserAdmin = true;
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (authErr) {
        console.warn('[PushNotification] JWT validation error:', authErr.message);
      }
    }
  }

  if (!isAuthorized) {
    await logSecurityEvent({
      eventType: 'UNAUTHORIZED_API_ACCESS_ATTEMPT',
      severity: 'HIGH',
      requestId,
      ipAddress,
      userAgent,
      country,
      city,
      responseStatus: 401,
      authMethod: 'BEARER_TOKEN',
      authResult: 'DENIED',
      details: { reason: 'missing_or_invalid_bearer_token' }
    });
    return res.status(401).json({ error: 'Unauthorized: Valid User Session or Authorization header required.' });
  }

  try {
    const { recipientId, target, title, body, type, data, tokens } = req.body || {};

    if (!body) return res.status(400).json({ error: 'Missing required parameter: body' });

    const isBroadcast = (target === 'all' || target === 'drivers' || target === 'riders' || target === 'city' || recipientId === 'ALL_USERS' || recipientId === 'broadcast' || recipientId === 'DRIVERS' || recipientId === 'RIDERS');

    if (isBroadcast && !isServerSecret && !isUserAdmin) {
      console.error(`[PushNotification] BLOCKED PRIVILEGE ESCALATION: User ${callerUserId} attempted unauthorized broadcast!`);
      await logSecurityEvent({
        eventType: 'PRIVILEGE_ESCALATION_ATTEMPT',
        severity: 'CRITICAL',
        requestId,
        userId: callerUserId,
        ipAddress,
        userAgent,
        country,
        city,
        responseStatus: 403,
        authResult: 'DENIED',
        details: {
          reason: 'non_admin_user_attempted_broadcast_push',
          attemptedTarget: target || recipientId,
          title: title || '',
          bodySnippet: String(body).substring(0, 100)
        }
      });
      return res.status(403).json({
        error: 'Forbidden: Broadcast notifications require administrator privileges.'
      });
    }

    if (!isBroadcast) {
      if (!recipientId || typeof recipientId !== 'string' || recipientId.trim() === '' || recipientId === 'null' || recipientId === 'undefined') {
        return res.status(400).json({ error: 'recipientId is strictly required for user-targeted notification' });
      }
    }

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

    if (!ONESIGNAL_REST_API_KEY) {
      return res.status(500).json({ error: 'Server configuration error: ONESIGNAL_REST_API_KEY is not set in environment variables.' });
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

    await logSecurityEvent({
      eventType: isBroadcast ? 'PUSH_BROADCAST_DISPATCHED' : 'PUSH_NOTIFICATION_DISPATCHED',
      severity: isBroadcast ? 'HIGH' : 'INFO',
      requestId,
      userId: callerUserId,
      adminId: isUserAdmin ? callerUserId : null,
      ipAddress,
      userAgent,
      country,
      city,
      responseStatus: 200,
      authResult: 'ALLOWED',
      details: {
        isBroadcast,
        target: target || recipientId,
        tokensCount: activeTokens.length,
        oneSignalId: resData?.id || null
      }
    });

    return res.status(200).json({ success: true, response: resData, tokensCount: activeTokens.length });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Internal Server Error' });
  }
};
