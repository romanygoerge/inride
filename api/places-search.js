const https = require('https');

/**
 * inRide Secure Places Search Proxy (Serverless API)
 * Keeps Google Maps API Key strictly protected on the backend server.
 */
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const query = req.query.query || req.body?.query || '';
    const lat = req.query.lat || req.body?.lat || '30.3800';
    const lng = req.query.lng || req.body?.lng || '30.5100';
    const radius = req.query.radius || req.body?.radius || '50000';

    if (!query || String(query).trim().length === 0) {
      return res.status(200).json({ status: 'OK', results: [] });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      console.error('[PlacesSearch] CRITICAL: GOOGLE_MAPS_API_KEY is not configured in Vercel environment variables.');
      return res.status(500).json({ error: 'GOOGLE_MAPS_API_KEY is not configured on server' });
    }

    const encodedQuery = encodeURIComponent(query);
    const path = `/maps/api/place/textsearch/json?query=${encodedQuery}&location=${lat},${lng}&radius=${radius}&language=ar&region=eg&key=${apiKey}`;

    const options = {
      hostname: 'maps.googleapis.com',
      port: 443,
      path: path,
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      }
    };

    const googleReq = https.request(options, (googleRes) => {
      let data = '';
      googleRes.on('data', chunk => data += chunk);
      googleRes.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          return res.status(googleRes.statusCode).json(parsed);
        } catch (_) {
          return res.status(googleRes.statusCode).send(data);
        }
      });
    });

    googleReq.on('error', (err) => {
      console.error('[PlacesSearchProxy] Error:', err);
      return res.status(502).json({ error: 'Failed to contact Google Places API', details: err.message });
    });

    googleReq.end();
  } catch (err) {
    console.error('[PlacesSearchProxy] Unhandled error:', err);
    return res.status(500).json({ error: err.message });
  }
};
