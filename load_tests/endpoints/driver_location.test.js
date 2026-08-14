// load_tests/endpoints/driver_location.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';
import { getRandomLocation } from '../helpers/data_generator.js';

export const options = {
  scenarios: {
    driver_location_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const driver = ensureUserExists(null, 'driver');
  const driverId = driver.id;
  const loc = getRandomLocation();

  // 1. Upsert Driver Online Status & Initial Location
  const upsertUrl = `${SUPABASE_URL}/rest/v1/drivers`;
  const driverPayload = JSON.stringify({
    id: driverId,
    is_online: true,
    is_available: true,
    verification_status: 'verified',
    current_latitude: loc.latitude,
    current_longitude: loc.longitude,
    updated_at: new Date().toISOString(),
  });

  const upsertRes = http.post(upsertUrl, driverPayload, {
    headers: getHeaders(null, 'resolution=merge-duplicates,return=representation'),
  });

  check(upsertRes, {
    'Upsert driver record status 200 or 201': (r) => r.status === 200 || r.status === 201,
  });

  sleep(0.3);

  // 2. High-Frequency GPS Location Update
  const newLoc = getRandomLocation();
  const updateUrl = `${SUPABASE_URL}/rest/v1/drivers?id=eq.${driverId}`;
  const updatePayload = JSON.stringify({
    current_latitude: newLoc.latitude,
    current_longitude: newLoc.longitude,
    updated_at: new Date().toISOString(),
  });

  const updateRes = http.patch(updateUrl, updatePayload, { headers: getHeaders() });

  check(updateRes, {
    'GPS update status 200 or 204': (r) => r.status === 200 || r.status === 204,
  });

  sleep(0.3);

  // 3. Query Active Drivers
  const searchUrl = `${SUPABASE_URL}/rest/v1/drivers?is_online=eq.true&is_available=eq.true&select=id,current_latitude,current_longitude,rating&limit=50`;
  const searchRes = http.get(searchUrl, { headers: getHeaders() });

  check(searchRes, {
    'Search active drivers status 200': (r) => r.status === 200,
  });

  sleep(1);
}
