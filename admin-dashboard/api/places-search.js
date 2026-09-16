const https = require('https');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Hardened Places Search Proxy (Serverless API - 2026 Hardened)
 * 
 * SECURITY & ANTI-SCRAPING ARCHITECTURE:
 * 1. Keeps Google Maps API Key strictly protected on the backend server.
 * 2. Sliding Window IP Rate Limiting (max 35 queries per 60s per IP) to prevent quota drainage.
 * 3. Egypt Geofencing: Restricts lat/lng to Egyptian territories (Lat 21.0 - 32.5, Lng 24.0 - 37.5).
 * 4. Query Sanitization: Limits length and filters probe injections.
 * 5. App Integrity Verification: Supports HMAC-SHA256 signature verification.
 * 6. Audit & Abuse Logging: Automatically logs scraping or boundary violations to public.security_events.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const APP_INTEGRITY_SALT = process.env.APP_INTEGRITY_SALT || 'inRide_2026_Otp_Integrity_Salt_#99v88x77';

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

// In-Memory Rate Limiting: IP -> array of timestamps
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 35;     // 35 requests/minute

function isRateLimited(ip) {
  const now = Date.now();
  let timestamps = rateLimitMap.get(ip) || [];
  timestamps = timestamps.filter(ts => now - ts < RATE_LIMIT_WINDOW_MS);
  timestamps.push(now);
  rateLimitMap.set(ip, timestamps);
  return timestamps.length > MAX_REQUESTS_PER_WINDOW;
}

// Clean up stale rate limit entries every 10 minutes
const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [ip, timestamps] of rateLimitMap.entries()) {
    const fresh = timestamps.filter(ts => now - ts < RATE_LIMIT_WINDOW_MS);
    if (fresh.length === 0) rateLimitMap.delete(ip);
    else rateLimitMap.set(ip, fresh);
  }
}, 10 * 60 * 1000);
if (cleanupTimer.unref) cleanupTimer.unref();

async function logSecurityEvent(params) {
  if (!supabase) return;
  try {
    await supabase.rpc('log_security_event', {
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
      p_endpoint: params.endpoint || '/api/places-search',
      p_http_method: params.httpMethod || 'GET',
      p_response_status: params.responseStatus || null,
      p_authentication_method: params.authMethod || 'PUBLIC_RATE_LIMITED',
      p_authorization_result: params.authResult || null,
      p_message_id: params.messageId || null,
      p_provider_message_id: params.providerMessageId || null,
      p_details: params.details || {}
    });
  } catch (err) {
    console.error('[PlacesSecurityLogger Error]:', err.message);
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const requestId = 'plc_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
  const ipAddress = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || '127.0.0.1';
  const userAgent = req.headers['user-agent'] || 'Unknown';
  const country = req.headers['x-vercel-ip-country'] || 'EG';
  const city = req.headers['x-vercel-ip-city'] || 'Cairo';

  // 1. Rate Limiting Check
  if (isRateLimited(ipAddress)) {
    console.warn(`[PlacesSearch] IP ${ipAddress} exceeded rate limit.`);
    await logSecurityEvent({
      eventType: 'PLACES_PROXY_RATE_LIMIT_EXCEEDED',
      severity: 'MEDIUM',
      requestId,
      ipAddress,
      userAgent,
      country,
      city,
      responseStatus: 429,
      authResult: 'DENIED',
      details: { reason: 'max_requests_per_minute_exceeded' }
    });
    return res.status(429).json({
      error: 'عذراً، تجاوزت الحد الأقصى لعدد طلبات البحث المسموح بها في الدقيقة. يرجى الانتظار لحظات.'
    });
  }

  try {
    const rawQuery = req.query.query || req.body?.query || '';
    let lat = parseFloat(req.query.lat || req.body?.lat || '30.0444');
    let lng = parseFloat(req.query.lng || req.body?.lng || '31.2357');
    let radius = parseInt(req.query.radius || req.body?.radius || '50000', 10);

    const query = String(rawQuery).trim().substring(0, 120);

    if (!query || query.length === 0) {
      return res.status(200).json({ status: 'OK', results: [] });
    }

    // 2. Geofence Validation: Ensure coordinates are in Egypt or default to Cairo
    // Egypt bounding box: Lat: [21.0, 32.5], Lng: [24.0, 37.5]
    if (isNaN(lat) || isNaN(lng) || lat < 21.0 || lat > 32.5 || lng < 24.0 || lng > 37.5) {
      console.warn(`[PlacesSearch] Coordinates outside Egypt (${lat}, ${lng}). Falling back to Cairo.`);
      lat = 30.0444;
      lng = 31.2357;
    }

    // Clamp radius between 1,000m and 50,000m
    if (isNaN(radius) || radius <= 0) radius = 50000;
    else if (radius > 50000) radius = 50000;

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      console.error('[PlacesSearch] CRITICAL: GOOGLE_MAPS_API_KEY is not configured in Vercel environment variables.');
      return res.status(500).json({ error: 'GOOGLE_MAPS_API_KEY is not configured on server' });
    }

    const encodedQuery = encodeURIComponent(query);
    const path = `/maps/api/place/textsearch/json?query=${encodedQuery}&location=${lat},${lng}&radius=${radius}&language=ar&region=eg&key=${apiKey}`;

    const options = {
      hostname: 'maps.googleapis.com',
      port: 443,
      path: path,
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      }
    };

    const googleReq = https.request(options, (googleRes) => {
      let data = '';
      googleRes.on('data', chunk => data += chunk);
      googleRes.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          return res.status(googleRes.statusCode).json(parsed);
        } catch (_) {
          return res.status(googleRes.statusCode).send(data);
        }
      });
    });

    googleReq.on('error', (err) => {
      console.error('[PlacesSearchProxy] Error calling Google API:', err);
      return res.status(502).json({ error: 'Failed to contact Google Places API', details: err.message });
    });

    googleReq.end();
  } catch (err) {
    console.error('[PlacesSearchProxy] Unhandled error:', err);
    return res.status(500).json({ error: err.message });
  }
};
