// scripts/apply_perf_optimizations.js
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
const https = require('https');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || 'fylruevfksmqnkykqkin';

const sqlPath = path.join(__dirname, '..', 'supabase_perf_optimizations.sql');
const sqlContent = fs.readFileSync(sqlPath, 'utf8');

async function applyOptimizations() {
  console.log('[Perf Optimizer] Reading supabase_perf_optimizations.sql...');

  if (ACCESS_TOKEN) {
    console.log('[Perf Optimizer] Applying via Supabase Management API...');
    const options = {
      hostname: 'api.supabase.com',
      port: 443,
      path: `/v1/projects/${PROJECT_REF}/database/query`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`[Perf Optimizer] Management API Response Status: ${res.statusCode}`);
        console.log(`[Perf Optimizer] Response:`, data);
      });
    });

    req.write(JSON.stringify({ query: sqlContent }));
    req.end();
  } else {
    console.log('[Perf Optimizer] ACCESS_TOKEN not set. Attempting via Supabase client RPC...');
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    try {
      const res = await supabase.rpc('exec_sql', { query: sqlContent });
      console.log('[Perf Optimizer] RPC exec_sql result:', res);
    } catch (e) {
      console.log('[Perf Optimizer] RPC exec_sql note:', e.message);
    }
  }
}

applyOptimizations();
