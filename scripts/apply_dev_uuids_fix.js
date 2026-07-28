const https = require('https');

const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || '';
const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || 'fylruevfksmqnkykqkin';

function apiRequest(pathStr, method = 'GET', body = null) {
    return new Promise((resolve, reject) => {
        if (!ACCESS_TOKEN) return reject(new Error('SUPABASE_ACCESS_TOKEN environment variable required.'));
        const options = {
            hostname: 'api.supabase.com',
            port: 443,
            path: '/v1' + pathStr,
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

console.log('Script initialized for environment variable execution.');
