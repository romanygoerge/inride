const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fylruevfksmqnkykqkin.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error('ERROR: SUPABASE_SERVICE_ROLE_KEY environment variable is missing.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function testRpc() {
  const sql = fs.readFileSync('../supabase_support_chat_system.sql', 'utf8');
  try {
    const res = await supabase.rpc('exec_sql', { query: sql });
    console.log('rpc exec_sql result:', res);
  } catch (e) {
    console.log('rpc exec_sql error:', e.message);
  }
}

testRpc();
