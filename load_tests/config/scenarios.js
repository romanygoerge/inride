// load_tests/config/scenarios.js

/**
 * Multi-stage ramping VUs load profile
 * 10 -> 50 -> 100 -> 250 -> 500 -> 1000 -> 3000 -> 5000 -> 10000 VUs
 */
export const FULL_RAMP_SCENARIO = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '30s', target: 10 },    // Tier 1: 10 VUs
    { duration: '30s', target: 50 },    // Tier 2: 50 VUs
    { duration: '30s', target: 100 },   // Tier 3: 100 VUs
    { duration: '45s', target: 250 },   // Tier 4: 250 VUs
    { duration: '45s', target: 500 },   // Tier 5: 500 VUs
    { duration: '60s', target: 1000 },  // Tier 6: 1000 VUs
    { duration: '60s', target: 3000 },  // Tier 7: 3000 VUs
    { duration: '60s', target: 5000 },  // Tier 8: 5000 VUs
    { duration: '60s', target: 10000 }, // Tier 9: 10000 VUs (Peak)
    { duration: '30s', target: 0 },     // Ramp down safely
  ],
  gracefulRampDown: '30s',
};

/**
 * Fast smoke test profile for baseline measurement
 */
export const BASELINE_SMOKE_SCENARIO = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '10s', target: 10 },
    { duration: '20s', target: 50 },
    { duration: '20s', target: 100 },
    { duration: '10s', target: 0 },
  ],
  gracefulRampDown: '10s',
};
