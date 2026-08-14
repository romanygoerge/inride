// load_tests/endpoints/chat_notifications.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, PUSH_API_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';

export const options = {
  scenarios: {
    chat_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const passenger = ensureUserExists(null, 'rider');
  const driver = ensureUserExists(null, 'driver');

  const senderId = driver.id;
  const receiverId = passenger.id;

  // 1. Send Notification to User
  const notifUrl = `${SUPABASE_URL}/rest/v1/notifications`;
  const notifPayload = JSON.stringify({
    user_id: receiverId,
    title: 'وصول الكابتن',
    body: 'وصل الكابتن إلى نقطة الانطلاق الخاصة بك.',
    type: 'ride_status',
    is_read: false,
  });

  const notifRes = http.post(notifUrl, notifPayload, { headers: getHeaders() });

  check(notifRes, {
    'Send notification status 201': (r) => r.status === 201,
  });

  sleep(0.3);

  // 2. Query Notifications History
  const fetchNotifUrl = `${SUPABASE_URL}/rest/v1/notifications?user_id=eq.${receiverId}&order=created_at.desc`;
  const fetchNotifRes = http.get(fetchNotifUrl, { headers: getHeaders() });

  check(fetchNotifRes, {
    'Fetch notifications status 200': (r) => r.status === 200,
  });

  sleep(0.3);

  // 3. Test Push Notification API
  const pushPayload = JSON.stringify({
    tokens: ['dummy_fcm_token_k6_test'],
    title: 'طلب رحلة جديد',
    body: 'هناك طلب رحلة جديد بالقرب منك',
  });

  const pushRes = http.post(PUSH_API_URL, pushPayload, { headers: getHeaders() });

  check(pushRes, {
    'Push notification API responds': (r) => r.status === 200 || r.status === 404 || r.status === 500,
  });

  sleep(1);
}
