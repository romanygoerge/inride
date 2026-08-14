// load_tests/helpers/auth_helper.js

import http from 'k6/http';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { getRandomEmail, getRandomPhoneNumber, getRandomUUID } from './data_generator.js';

/**
 * Ensure a user row exists in public.users to prevent Foreign Key violations during stress testing
 */
export function ensureUserExists(userId = null, role = 'rider') {
  const id = userId || getRandomUUID();
  const email = getRandomEmail(role);
  const phone = getRandomPhoneNumber();

  const userPayload = JSON.stringify({
    id: id,
    name: `K6 User ${role.toUpperCase()} ${id.substring(0, 5)}`,
    phone_number: phone,
    email: email,
    role: role === 'driver' ? 'driver' : 'rider',
    wallet_balance: 500.0,
    rating: 5.0,
  });

  const url = `${SUPABASE_URL}/rest/v1/users`;
  const res = http.post(url, userPayload, {
    headers: getHeaders(null, 'resolution=merge-duplicates,return=representation'),
  });

  return {
    id: id,
    email: email,
    phone: phone,
    role: role,
    headers: getHeaders(),
  };
}

/**
 * Register or login a virtual user to get an authentic JWT Access Token
 */
export function getAuthenticatedUser(role = 'rider') {
  const email = getRandomEmail(role);
  const password = 'TestPassword123!';
  const phone = getRandomPhoneNumber();

  const signupUrl = `${SUPABASE_URL}/auth/v1/signup`;
  const payload = JSON.stringify({
    email: email,
    password: password,
    data: {
      name: `K6 VU ${role.toUpperCase()} ${getRandomUUID().substring(0, 6)}`,
      phone_number: phone,
      role: role,
    },
  });

  const res = http.post(signupUrl, payload, { headers: getHeaders() });

  let token = null;
  let userId = null;

  if (res.status === 200 || res.status === 201) {
    try {
      const body = JSON.parse(res.body);
      token = body.access_token;
      userId = body.user ? body.user.id : null;
    } catch (e) {}
  }

  if (!token) {
    const loginUrl = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
    const loginPayload = JSON.stringify({ email: email, password: password });
    const loginRes = http.post(loginUrl, loginPayload, { headers: getHeaders() });
    if (loginRes.status === 200) {
      try {
        const body = JSON.parse(loginRes.body);
        token = body.access_token;
        userId = body.user ? body.user.id : null;
      } catch (e) {}
    }
  }

  if (!userId) {
    userId = getRandomUUID();
  }

  // Ensure row exists in public.users
  ensureUserExists(userId, role);

  return {
    email,
    userId,
    token,
    role,
    headers: getHeaders(token),
  };
}
