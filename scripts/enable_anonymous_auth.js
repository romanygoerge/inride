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

async function main() {
    console.log('--- Checking & Updating Auth Config on Project ---');
    const authConfigRes = await apiRequest(`/projects/${PROJECT_REF}/config/auth`);
    console.log('Current Auth Config status:', authConfigRes.status);
    console.log('Current Auth Config:', JSON.stringify(authConfigRes.body, null, 2));

    // Enable Anonymous Sign Ins
    const updateRes = await apiRequest(`/projects/${PROJECT_REF}/config/auth`, 'PATCH', {
        EXTERNAL_ANONYMOUS_USERS_ENABLED: true
    });

    console.log('Update Auth Config status:', updateRes.status);
    console.log('Update Auth Config body:', JSON.stringify(updateRes.body, null, 2));
}

main().catch(console.error);
