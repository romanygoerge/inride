// load_tests/scenarios/e2e_full_ride_flow.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { SUPABASE_URL, getHeaders } from '../config/env.js';
import { DEFAULT_THRESHOLDS } from '../config/thresholds.js';
import { FULL_RAMP_SCENARIO, BASELINE_SMOKE_SCENARIO } from '../config/scenarios.js';
import { ensureUserExists } from '../helpers/auth_helper.js';
import {
  getRandomLocation,
  getRandomFare,
  getRandomVehicleType,
} from '../helpers/data_generator.js';

const isFullRamp = __ENV.FULL_RAMP === 'true';

export const options = {
  scenarios: {
    e2e_ride_scenario: isFullRamp ? FULL_RAMP_SCENARIO : BASELINE_SMOKE_SCENARIO,
  },
  thresholds: DEFAULT_THRESHOLDS,
};

export default function () {
  // Ensure valid parent rows exist in public.users
  const passenger = ensureUserExists(null, 'rider');
  const driver = ensureUserExists(null, 'driver');

  const passengerId = passenger.id;
  const driverId = driver.id;

  const pickup = getRandomLocation();
  const dest = getRandomLocation();
  const fare = getRandomFare();
  const vehicleType = getRandomVehicleType();

  // -------------------------------------------------------------
  // STEP 1: Driver goes online & updates initial location
  // -------------------------------------------------------------
  const driverInitUrl = `${SUPABASE_URL}/rest/v1/drivers`;
  const driverPayload = JSON.stringify({
    id: driverId,
    is_online: true,
    is_available: true,
    verification_status: 'verified',
    current_latitude: pickup.latitude + 0.002,
    current_longitude: pickup.longitude + 0.002,
    updated_at: new Date().toISOString(),
  });

  const driverInitRes = http.post(driverInitUrl, driverPayload, {
    headers: getHeaders(null, 'resolution=merge-duplicates'),
  });

  check(driverInitRes, {
    'E2E 1: Driver initialized status 200/201': (r) => r.status === 200 || r.status === 201,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 2: Passenger creates a Ride Request
  // -------------------------------------------------------------
  const reqUrl = `${SUPABASE_URL}/rest/v1/ride_requests`;
  const reqPayload = JSON.stringify({
    passenger_id: passengerId,
    pickup_latitude: pickup.latitude,
    pickup_longitude: pickup.longitude,
    pickup_address: 'Al Tahrir Square, Cairo',
    destination_latitude: dest.latitude,
    destination_longitude: dest.longitude,
    destination_address: 'Nasr City, Cairo',
    vehicle_type: vehicleType,
    offered_fare: fare,
    distance: 14.2,
    status: 'Pending',
    payment_method: 'cash',
    service_type: 'ride',
  });

  const reqRes = http.post(reqUrl, reqPayload, {
    headers: getHeaders(null, 'return=representation'),
  });

  let requestId = null;
  check(reqRes, {
    'E2E 2: Ride request created status 201': (r) => r.status === 201,
    'E2E 2: Ride request returned valid ID': (r) => {
      if (r.status === 201) {
        try {
          const body = JSON.parse(r.body);
          requestId = body[0].id;
          return !!requestId;
        } catch (e) {
          return false;
        }
      }
      return false;
    },
  });

  sleep(0.5);

  if (!requestId) {
    return;
  }

  // -------------------------------------------------------------
  // STEP 3: Nearby Drivers Query Pending Rides
  // -------------------------------------------------------------
  const queryRidesUrl = `${SUPABASE_URL}/rest/v1/ride_requests?status=eq.Pending&select=*&limit=10`;
  const queryRidesRes = http.get(queryRidesUrl, { headers: getHeaders() });

  check(queryRidesRes, {
    'E2E 3: Driver searched pending rides status 200': (r) => r.status === 200,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 4: Driver Submits an Offer via RPC
  // -------------------------------------------------------------
  const offerRpcUrl = `${SUPABASE_URL}/rest/v1/rpc/submit_driver_offer`;
  const offerPayload = JSON.stringify({
    p_request_id: requestId,
    p_driver_id: driverId,
    p_offered_price: fare,
    p_eta_minutes: 6,
  });

  const offerRes = http.post(offerRpcUrl, offerPayload, { headers: getHeaders() });
  check(offerRes, {
    'E2E 4: Driver offer submitted via RPC': (r) => r.status === 200,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 5: Ride Acceptance via RPC `accept_ride_request`
  // -------------------------------------------------------------
  const acceptRpcUrl = `${SUPABASE_URL}/rest/v1/rpc/accept_ride_request`;
  const acceptPayload = JSON.stringify({
    p_request_id: requestId,
    p_driver_id: driverId,
    p_offered_fare: fare,
  });

  const acceptRes = http.post(acceptRpcUrl, acceptPayload, { headers: getHeaders() });

  check(acceptRes, {
    'E2E 5: Ride accepted status 200': (r) => r.status === 200,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 6: Driver updates GPS location on route
  // -------------------------------------------------------------
  const locUpdateUrl = `${SUPABASE_URL}/rest/v1/drivers?id=eq.${driverId}`;
  const locUpdatePayload = JSON.stringify({
    current_latitude: pickup.latitude + 0.001,
    current_longitude: pickup.longitude + 0.001,
    updated_at: new Date().toISOString(),
  });

  const locUpdateRes = http.patch(locUpdateUrl, locUpdatePayload, { headers: getHeaders() });

  check(locUpdateRes, {
    'E2E 6: Driver location updated status 200/204': (r) => r.status === 200 || r.status === 204,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 7: In-App Chat exchange during active ride
  // -------------------------------------------------------------
  const chatUrl = `${SUPABASE_URL}/rest/v1/chat_messages`;
  const chatPayload = JSON.stringify({
    request_id: requestId,
    sender_id: driverId,
    sender_name: 'الكابتن أحمد',
    text: 'وصلت عند الموقع المنتظر',
    is_driver: true,
  });

  const chatRes = http.post(chatUrl, chatPayload, { headers: getHeaders() });

  check(chatRes, {
    'E2E 7: Chat message sent status 201': (r) => r.status === 201,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 8: Driver Starts & Completes the Trip
  // -------------------------------------------------------------
  const tripCompleteUrl = `${SUPABASE_URL}/rest/v1/ride_requests?id=eq.${requestId}`;
  const tripCompletePayload = JSON.stringify({
    status: 'Completed',
  });

  const tripCompleteRes = http.patch(tripCompleteUrl, tripCompletePayload, { headers: getHeaders() });

  check(tripCompleteRes, {
    'E2E 8: Trip marked as Completed status 200/204': (r) => r.status === 200 || r.status === 204,
  });

  sleep(0.3);

  // -------------------------------------------------------------
  // STEP 9: Rating & Commission Deduction Log
  // -------------------------------------------------------------
  const ratingRpcUrl = `${SUPABASE_URL}/rest/v1/rpc/submit_trip_rating`;
  const ratingPayload = JSON.stringify({
    p_request_id: requestId,
    p_sender_id: passengerId,
    p_receiver_id: driverId,
    p_receiver_role: 'driver',
    p_rating: 5.0,
    p_comment: 'رحلة ممتازة وسريعة جداً',
  });

  const ratingRes = http.post(ratingRpcUrl, ratingPayload, { headers: getHeaders() });

  check(ratingRes, {
    'E2E 9: Trip rating submitted status 200': (r) => r.status === 200,
  });

  // Commission Transaction Log
  const commissionUrl = `${SUPABASE_URL}/rest/v1/transactions`;
  const commissionPayload = JSON.stringify({
    user_id: driverId,
    title: 'خصم عمولة رحلة',
    amount: fare * 0.15,
    type: 'debit',
    balance_after: 210.0,
  });

  const commissionRes = http.post(commissionUrl, commissionPayload, { headers: getHeaders() });

  check(commissionRes, {
    'E2E 9: Commission transaction logged status 201': (r) => r.status === 201,
  });

  sleep(1);
}
