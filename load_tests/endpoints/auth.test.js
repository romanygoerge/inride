// load_tests/endpoints/auth.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { getRandomEmail, getRandomPhoneNumber } from '../helpers/data_generator.js';

export const options = {
  scenarios: {
    auth_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const email = getRandomEmail('auth_test');
  const password = 'SecurePassword123!';
  const phone = getRandomPhoneNumber();

  // 1. Signup Request
  const signupUrl = `${SUPABASE_URL}/auth/v1/signup`;
  const signupBody = JSON.stringify({
    email: email,
    password: password,
    data: { name: 'K6 Test User', phone_number: phone, role: 'rider' },
  });

  const signupRes = http.post(signupUrl, signupBody, { headers: getHeaders() });
  check(signupRes, {
    'Signup status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'Signup response has body': (r) => r.body.length > 0,
  });

  sleep(0.5);

  // 2. Token / Login Request
  const loginUrl = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const loginBody = JSON.stringify({
    email: email,
    password: password,
  });

  const loginRes = http.post(loginUrl, loginBody, { headers: getHeaders() });
  let token = null;

  check(loginRes, {
    'Login status is 200': (r) => r.status === 200,
    'Login contains access_token': (r) => {
      if (r.status === 200) {
        try {
          const resJson = JSON.parse(r.body);
          token = resJson.access_token;
          return !!token;
        } catch (e) {
          return false;
        }
      }
      return false;
    },
  });

  sleep(0.5);

  // 3. User Profile Info Fetch
  if (token) {
    const userUrl = `${SUPABASE_URL}/auth/v1/user`;
    const userRes = http.get(userUrl, { headers: getHeaders(token) });
    check(userRes, {
      'Fetch auth user status is 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
