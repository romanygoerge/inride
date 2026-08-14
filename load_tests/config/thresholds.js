// load_tests/config/thresholds.js

export const DEFAULT_THRESHOLDS = {
  // Global response time thresholds
  http_req_duration: [
    'p(90)<500',  // 90% of requests must complete below 500ms
    'p(95)<1000', // 95% of requests must complete below 1000ms
    'p(99)<2000', // 99% of requests must complete below 2000ms
  ],
  // Global error rate threshold
  http_req_failed: ['rate<0.01'], // Less than 1% request failure rate
  // Minimum throughput requirement
  http_reqs: ['count>100'],
};

export const STRICT_THRESHOLDS = {
  http_req_duration: ['p(95)<300', 'p(99)<800'],
  http_req_failed: ['rate<0.005'],
};
