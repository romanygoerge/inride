const fs = require('fs');
const path = require('path');
const https = require('https');

const rootApp = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const adminApp = fs.readFileSync(path.join(__dirname, '..', 'admin-dashboard', 'app.js'), 'utf8');

console.log('=== TEST 1: Parity between root app.js and admin-dashboard/app.js ===');
console.log('Root size:', rootApp.length, '| Admin-dashboard size:', adminApp.length);
if (rootApp !== adminApp) {
  console.error('FAIL: Root and admin-dashboard app.js do not match!');
  process.exit(1);
} else {
  console.log('PASS: Files are 100% identical.');
}

console.log('\n=== TEST 2: Verification of zero dummy records in initial state ===');
const forbiddenMocks = ['TRP01', 'TRP02', 'DRV01', 'DRV02', 'PAS01', 'PAS02', 'PAS03', 'synth_drv_', 'synth_psg_'];
let failedMocks = 0;
forbiddenMocks.forEach(m => {
  if (rootApp.includes(`"${m}"`) || rootApp.includes(`'${m}'`) || rootApp.includes(m)) {
    console.error(`FAIL: Found forbidden mock record marker: ${m}`);
    failedMocks++;
  } else {
    console.log(`PASS: No trace of mock marker '${m}'`);
  }
});

if (failedMocks > 0) {
  console.error(`FAIL: ${failedMocks} mock data markers found in codebase.`);
  process.exit(1);
}

console.log('\n=== TEST 3: Verification of Generation Token & Race Condition Guards ===');
if (!rootApp.includes('thisGeneration !== globalSyncState.generation')) {
  console.error('FAIL: Generation token guard not found in app.js');
  process.exit(1);
} else {
  console.log('PASS: Generation token race condition guard present.');
}

console.log('\n=== TEST 4: Verification of Consistency Checker and Realtime Cleanup ===');
if (!rootApp.includes('window.runDataConsistencyCheck') || !rootApp.includes('cleanupAllRealtimeChannels')) {
  console.error('FAIL: Consistency check or realtime cleanup functions missing');
  process.exit(1);
} else {
  console.log('PASS: runDataConsistencyCheck and cleanupAllRealtimeChannels present.');
}

console.log('\n=== TEST 5: Live Supabase Data Integration Verification ===');
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_URL = 'https://fylruevfksmqnkykqkin.supabase.co';

async function fetchTable(table) {
  return new Promise((resolve, reject) => {
    const url = `${SUPABASE_URL}/rest/v1/${table}?select=*`;
    const req = https.get(url, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`
      }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
  });
}

(async () => {
  try {
    const [users, drivers, rides, ratings] = await Promise.all([
      fetchTable('users'),
      fetchTable('drivers'),
      fetchTable('ride_requests'),
      fetchTable('ratings')
    ]);

    console.log(`Live DB counts -> Users: ${users.length}, Drivers: ${drivers.length}, Rides: ${rides.length}, Ratings: ${ratings.length}`);
    console.log('Sample Driver IDs:', drivers.slice(0, 3).map(d => d.id));
    console.log('Sample Ride IDs:', rides.slice(0, 3).map(r => r.id));

    console.log('\n=== ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ===\n');
  } catch (err) {
    console.error('Supabase fetch error during test:', err);
    process.exit(1);
  }
})();
