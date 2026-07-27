const https = require('https');

const ACCESS_TOKEN = 'sbp_689d4622bab4702fe8f755da4dd9877a2331c7c7';
const PROJECT_REF = 'fylruevfksmqnkykqkin';

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

async function checkDb() {
    console.log('--- Querying Supabase Database state ---');
    const sqlContent = `
        SELECT 'ride_requests' as t, count(*) as c FROM public.ride_requests
        UNION ALL
        SELECT 'ride_offers' as t, count(*) as c FROM public.ride_offers
        UNION ALL
        SELECT 'drivers' as t, count(*) as c FROM public.drivers
        UNION ALL
        SELECT 'users' as t, count(*) as c FROM public.users;

        SELECT id, passenger_id, driver_id, status, vehicle_type, service_type, created_at 
        FROM public.ride_requests 
        ORDER BY created_at DESC 
        LIMIT 10;
    `;

    const res = await apiRequest(`/projects/${PROJECT_REF}/database/query`, 'POST', {
        query: sqlContent
    });

    console.log('SQL Execution Result:', JSON.stringify(res.body, null, 2));
}

checkDb().catch(console.error);
