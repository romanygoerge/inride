// load_tests/config/env.js

export const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
export const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';

export const PUSH_API_URL = __ENV.PUSH_API_URL || 'https://fylruevfksmqnkykqkin.supabase.co/api/push-notification';

/**
 * Build standard headers for PostgREST & RPC calls
 */
export function getHeaders(token = null, prefer = null) {
  const headers = {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': token ? `Bearer ${token}` : `Bearer ${SUPABASE_ANON_KEY}`,
  };

  if (prefer) {
    headers['Prefer'] = prefer;
  }

  return headers;
}
