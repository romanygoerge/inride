// load_tests/endpoints/rpc_accept_ride.test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';
import { getRandomLocation, getRandomFare } from '../helpers/data_generator.js';

export const options = {
  scenarios: {
    rpc_test: BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  const passenger = ensureUserExists(null, 'rider');
  const driver = ensureUserExists(null, 'driver');

  const passengerId = passenger.id;
  const driverId = driver.id;

  const loc = getRandomLocation();
  const fare = getRandomFare();

  // Step 1: Create a Ride Request
  const createUrl = `${SUPABASE_URL}/rest/v1/ride_requests`;
  const reqPayload = JSON.stringify({
    passenger_id: passengerId,
    pickup_latitude: loc.latitude,
    pickup_longitude: loc.longitude,
    destination_latitude: loc.latitude + 0.05,
    destination_longitude: loc.longitude + 0.05,
    offered_fare: fare,
    status: 'Pending',
    vehicle_type: 'car',
  });

  const createRes = http.post(createUrl, reqPayload, {
    headers: getHeaders(null, 'return=representation'),
  });

  let requestId = null;
  if (createRes.status === 201) {
    try {
      const arr = JSON.parse(createRes.body);
      requestId = arr[0].id;
    } catch (e) {}
  }

  sleep(0.3);

  if (requestId) {
    // Step 2: Driver Accepts Ride Request via RPC `accept_ride_request`
    const acceptRpcUrl = `${SUPABASE_URL}/rest/v1/rpc/accept_ride_request`;
    const acceptPayload = JSON.stringify({
      p_request_id: requestId,
      p_driver_id: driverId,
      p_offered_fare: fare + 10.0,
    });

    const acceptRes = http.post(acceptRpcUrl, acceptPayload, { headers: getHeaders() });
    check(acceptRes, {
      'RPC accept_ride_request status 200': (r) => r.status === 200,
      'RPC accept_ride_request response contains success': (r) => {
        if (r.status === 200) {
          try {
            const body = JSON.parse(r.body);
            return body.success === true || body.code === 'RIDE_ALREADY_TAKEN';
          } catch (e) {
            return false;
          }
        }
        return false;
      },
    });
  }

  sleep(1);
}
