const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

/**
 * inRide Defensive Canary / Honeypot Endpoint (2026)
 * Safe defensive mechanism that detects active reconnaissance or unauthorized probing.
 * Never performs real actions. Always logs full forensic telemetry and drops the request.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const requestId = 'CANARY-' + crypto.randomUUID();
  const clientIp = (req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || req.socket?.remoteAddress || '').split(',')[0].trim();
  const userAgent = req.headers['user-agent'] || 'Unknown/Automated';
  const userId = req.headers['x-user-id'] || null;
  const sessionId = req.headers['x-session-id'] || null;
  const deviceId = req.headers['x-device-id'] || null;
  const probedEndpoint = req.url || '/api/canary';

  const country = req.headers['x-vercel-ip-country'] || req.headers['cf-ipcountry'] || null;
  const city = req.headers['x-vercel-ip-city'] || null;

  console.warn(`[DEFENSIVE CANARY TRIGGERED] IP: ${clientIp}, Endpoint: ${probedEndpoint}, UA: ${userAgent}`);

  if (supabase) {
    try {
      await supabase.rpc('log_security_event', {
        p_event_type: 'CANARY_HONEYPOT_TRIGGERED',
        p_severity: 'CRITICAL',
        p_request_id: requestId,
        p_correlation_id: req.headers['x-correlation-id'] || ('CORR-' + crypto.randomUUID()),
        p_user_id: userId,
        p_session_id: sessionId,
        p_device_id: deviceId,
        p_ip_address: clientIp,
        p_user_agent: userAgent,
        p_country: country,
        p_city: city,
        p_endpoint: probedEndpoint,
        p_http_method: req.method,
        p_response_status: 403,
        p_details: {
          alert: 'Defensive Canary probe triggered',
          note: 'Reconnaissance activity or automated honeypot hit detected.',
          query_params: req.query || {}
        }
      });
    } catch (dbErr) {
      console.error('[Canary] Failed logging security event:', dbErr.message);
    }
  }

  return res.status(403).json({
    success: false,
    error: 'Access Denied: Resource is forbidden or decommissioned.',
    request_id: requestId
  });
};
