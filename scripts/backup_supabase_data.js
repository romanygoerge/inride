const fs = require('fs');
const path = require('path');
const https = require('https');

const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const SUPABASE_URL = 'https://fylruevfksmqnkykqkin.supabase.co';

const tables = [
  'users',
  'passengers',
  'vehicles',
  'drivers',
  'ride_requests',
  'ride_offers',
  'chat_messages',
  'typing_indicators',
  'ratings',
  'notifications',
  'transactions',
  'support_chats',
  'support_messages',
  'app_settings',
  'user_devices',
  'payment_methods',
  'financial_settlements',
  'chat_rooms',
  'messages',
  'message_reads',
  'attachments',
  'support_tickets',
  'wallet_recharge_requests',
  'admins'
];

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
          resolve([]);
        }
      });
    });
    req.on('error', err => {
      console.warn(`Warning on table ${table}:`, err.message);
      resolve([]);
    });
  });
}

(async () => {
  console.log('Starting full pre-reset database backup...');
  const backupDir = path.join(__dirname, '..', 'backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const backupData = {
    timestamp: new Date().toISOString(),
    projectId: 'fylruevfksmqnkykqkin',
    tables: {}
  };

  for (const t of tables) {
    process.stdout.write(`Backing up ${t}... `);
    const rows = await fetchTable(t);
    backupData.tables[t] = rows;
    console.log(`[${Array.isArray(rows) ? rows.length : 0} rows]`);
  }

  const backupFile = path.join(backupDir, 'pre_production_reset_backup.json');
  fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2), 'utf8');
  console.log(`\nBackup successfully written to: ${backupFile}`);
  console.log(`Backup file size: ${(fs.statSync(backupFile).size / 1024 / 1024).toFixed(2)} MB`);
})();
