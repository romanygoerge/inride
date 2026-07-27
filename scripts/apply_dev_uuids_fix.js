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

async function fixDevUuidsInDb() {
    console.log('--- Adding missing columns and inserting valid dev UUIDs ---');
    const sqlContent = `
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS credit_limit NUMERIC(10,2) DEFAULT -100.00;

        INSERT INTO public.users (id, name, phone_number, email, role, wallet_balance, credit_limit)
        VALUES 
            ('00000000-0000-4000-a000-000000000001', 'كابتن تجريبي', '+201000000001', 'dev_driver@inride.app', 'driver', 500.00, -500.00),
            ('00000000-0000-4000-a000-000000000002', 'عميل تجريبي', '+201000000002', 'dev_rider@inride.app', 'rider', 500.00, -500.00),
            ('00000000-0000-4000-a000-000000000000', 'مستخدم تجريبي', '+201000000000', 'dev_mock@inride.app', 'rider', 500.00, -500.00)
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            role = EXCLUDED.role;

        INSERT INTO public.drivers (id, is_online, is_available, verification_status)
        VALUES 
            ('00000000-0000-4000-a000-000000000001', true, true, 'verified')
        ON CONFLICT (id) DO UPDATE SET
            is_online = true,
            is_available = true,
            verification_status = 'verified';

        INSERT INTO public.passengers (id, name, phone, address, gender)
        VALUES 
            ('00000000-0000-4000-a000-000000000002', 'عميل تجريبي', '+201000000002', 'القاهرة', 'ذكر')
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name;
    `;

    const res = await apiRequest(`/projects/${PROJECT_REF}/database/query`, 'POST', {
        query: sqlContent
    });

    console.log('SQL Execution Status:', res.status);
    console.log('SQL Execution Result:', JSON.stringify(res.body, null, 2));
}

fixDevUuidsInDb().catch(console.error);
