# inRide k6 Load Testing Suite

This directory contains the automated performance and load testing framework built for **inRide** platform using **Grafana k6**.

## Project Directory Structure

```
load_tests/
├── bin/                       # Local k6 binary executable
├── config/
│   ├── env.js                 # Environment URLs, Supabase credentials & HTTP headers
│   ├── thresholds.js          # SLA performance quality gates (P90, P95, P99, error rate)
│   └── scenarios.js           # Multi-stage progressive load profiles (10 to 10,000 VUs)
├── helpers/
│   ├── data_generator.js      # Dynamic random test data (GPS coords, phones, UUIDs, fares)
│   └── auth_helper.js         # Dynamic VU authentication & token caching
├── endpoints/                 # Individual endpoint load tests
│   ├── auth.test.js           # Signup, Login, Profile retrieval
│   ├── ride_requests.test.js  # Create, list, search ride requests
│   ├── driver_location.test.js# High-frequency GPS location pings & driver availability
│   ├── rpc_accept_ride.test.js# Atomic ride acceptance RPC & driver offers
│   ├── wallet_transactions.test.js # Financial transactions & balance checks
│   └── chat_notifications.test.js  # In-app chat, notifications & push API
├── scenarios/
│   └── e2e_full_ride_flow.js  # Complete End-to-End user journey
└── run_tests.js               # Node.js automated test runner
```

## How to Run Tests

### 1. Run Baseline Smoke Test for an Endpoint
```bash
node load_tests/run_tests.js load_tests/endpoints/auth.test.js
node load_tests/run_tests.js load_tests/endpoints/ride_requests.test.js
node load_tests/run_tests.js load_tests/endpoints/driver_location.test.js
node load_tests/run_tests.js load_tests/endpoints/rpc_accept_ride.test.js
node load_tests/run_tests.js load_tests/endpoints/wallet_transactions.test.js
node load_tests/run_tests.js load_tests/endpoints/chat_notifications.test.js
```

### 2. Run End-to-End Realistic User Journey
```bash
node load_tests/run_tests.js load_tests/scenarios/e2e_full_ride_flow.js
```

### 3. Run Full Ramp-Up Stress Test (up to 10,000 VUs)
```bash
$env:FULL_RAMP="true"; node load_tests/run_tests.js load_tests/scenarios/e2e_full_ride_flow.js
```

## Key Metrics Evaluated
- **Response Time**: `http_req_duration` (Average, Min, Max, Med, P90, P95, P99)
- **Error Rate**: `http_req_failed` (< 1.0%)
- **Requests Per Second**: `http_reqs` (Throughput)
- **Concurrency**: Virtual Users (`VUs`)
