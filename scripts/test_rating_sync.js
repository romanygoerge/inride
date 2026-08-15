const fs = require('fs');
const path = require('path');
const https = require('https');

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
    const [users, drivers, ratings, rides] = await Promise.all([
      fetchTable('users'),
      fetchTable('drivers'),
      fetchTable('ratings'),
      fetchTable('ride_requests')
    ]);

    global.allSystemRatings = ratings;
    global.globalUsersMap = {};
    users.forEach(u => global.globalUsersMap[u.id] = u);

    // Test calculation on driver 4d510319-b9c4-4c26-b857-30f6275207b1
    const testDriverUid = '4d510319-b9c4-4c26-b857-30f6275207b1';
    const driverRating = ratings.filter(r => r.receiver_id === testDriverUid && r.receiver_role === 'driver');
    console.log(`Driver ${testDriverUid} has ${driverRating.length} direct driver ratings.`);

    const testRiderUid = '65a9bdb5-0f02-4766-9392-c418553dc90e';
    const riderRating = ratings.filter(r => r.receiver_id === testRiderUid && r.receiver_role === 'rider');
    console.log(`Rider ${testRiderUid} has ${riderRating.length} direct rider ratings.`);

    console.log('All tests finished successfully!');
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
