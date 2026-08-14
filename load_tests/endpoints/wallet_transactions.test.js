// load_tests/endpoints/wallet_transactions.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';
import { getRandomFare } from '../helpers/data_generator.js';

export const options = {
  scenarios: {
    wallet_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const user = ensureUserExists(null, 'rider');
  const userId = user.id;
  const amount = getRandomFare();

  // 1. Fetch User Wallet Balance
  const balanceUrl = `${SUPABASE_URL}/rest/v1/users?id=eq.${userId}&select=id,wallet_balance,role`;
  const balanceRes = http.get(balanceUrl, { headers: getHeaders() });

  check(balanceRes, {
    'Query wallet balance status 200': (r) => r.status === 200,
  });

  sleep(0.3);

  // 2. Insert Transaction Log
  const txUrl = `${SUPABASE_URL}/rest/v1/transactions`;
  const txPayload = JSON.stringify({
    user_id: userId,
    title: 'عمولة رحلة - inRide',
    amount: amount,
    type: 'debit',
    balance_after: 200.0,
    created_at: new Date().toISOString(),
  });

  const txRes = http.post(txUrl, txPayload, { headers: getHeaders(null, 'return=representation') });

  check(txRes, {
    'Insert transaction status 201': (r) => r.status === 201,
  });

  sleep(0.3);

  // 3. Query Transaction History
  const historyUrl = `${SUPABASE_URL}/rest/v1/transactions?user_id=eq.${userId}&order=created_at.desc&limit=20`;
  const historyRes = http.get(historyUrl, { headers: getHeaders() });

  check(historyRes, {
    'Query transaction history status 200': (r) => r.status === 200,
  });

  sleep(1);
}
