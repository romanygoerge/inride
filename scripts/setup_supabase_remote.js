const https = require('https');
const fs = require('fs');
const path = require('path');

const ACCESS_TOKEN = 'sbp_689d4622bab4702fe8f755da4dd9877a2331c7c7';
const PROJECT_REF = 'fylruevfksmqnkykqkin';
const SUPABASE_URL = `https://${PROJECT_REF}.supabase.co`;
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDc1Njc0NiwiZXhwIjoyMTAwMzMyNzQ2fQ.WygklhW-UcFDVzhaqXBY2Yz4548stBFuwnmep8y_OXg';

function apiRequest(path, method = 'GET', body = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.supabase.com',
            port: 443,
            path: '/v1' + path,
            method: method,
            headers: {
                'Authorization': `Bearer ${ACCESS_TOKEN}`,
                'Content-Type': 'application/json'
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    resolve({ status: res.statusCode, body: parsed });
                } catch (e) {
                    resolve({ status: res.statusCode, body: data });
                }
            });
        });

        req.on('error', (err) => reject(err));
        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function runSqlSchema() {
    console.log('--- Applying SQL Schema to inRide Database ---');
    const sqlPath = path.join(__dirname, '..', 'supabase_schema.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    // Execute via Supabase Management Query API
    const res = await apiRequest(`/projects/${PROJECT_REF}/database/query`, 'POST', {
        query: sqlContent
    });

    console.log('SQL Execution Status:', res.status);
    console.log('SQL Execution Result:', JSON.stringify(res.body, null, 2));
}

runSqlSchema().catch(console.error);
