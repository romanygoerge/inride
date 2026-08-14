// load_tests/endpoints/ride_requests.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';
import { getRandomLocation, getRandomFare, getRandomVehicleType } from '../helpers/data_generator.js';

export const options = {
  scenarios: {
    ride_requests_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const passenger = ensureUserExists(null, 'rider');
  const pickup = getRandomLocation();
  const dest = getRandomLocation();
  const fare = getRandomFare();
  const vehicleType = getRandomVehicleType();

  // 1. Create Ride Request
  const createUrl = `${SUPABASE_URL}/rest/v1/ride_requests`;
  const payload = JSON.stringify({
    passenger_id: passenger.id,
    pickup_latitude: pickup.latitude,
    pickup_longitude: pickup.longitude,
    pickup_address: 'Tahrir Square, Cairo',
    destination_latitude: dest.latitude,
    destination_longitude: dest.longitude,
    destination_address: 'Maadi, Cairo',
    vehicle_type: vehicleType,
    offered_fare: fare,
    distance: 12.5,
    status: 'Pending',
    payment_method: 'cash',
    service_type: 'ride',
  });

  const createRes = http.post(createUrl, payload, {
    headers: getHeaders(null, 'return=representation'),
  });

  let requestId = null;

  check(createRes, {
    'Create ride request status 201': (r) => r.status === 201,
    'Returned created ride payload': (r) => {
      if (r.status === 201) {
        try {
          const arr = JSON.parse(r.body);
          requestId = arr[0].id;
          return !!requestId;
        } catch (e) {
          return false;
        }
      }
      return false;
    },
  });

  sleep(0.5);

  // 2. Query Pending Ride Requests (Captains browsing)
  const listUrl = `${SUPABASE_URL}/rest/v1/ride_requests?status=eq.Pending&select=*&order=created_at.desc&limit=20`;
  const listRes = http.get(listUrl, { headers: getHeaders() });

  check(listRes, {
    'Query pending requests status 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // 3. Inspect Specific Ride Request
  if (requestId) {
    const getSingleUrl = `${SUPABASE_URL}/rest/v1/ride_requests?id=eq.${requestId}&select=*`;
    const singleRes = http.get(getSingleUrl, { headers: getHeaders() });

    check(singleRes, {
      'Get single ride request status 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
