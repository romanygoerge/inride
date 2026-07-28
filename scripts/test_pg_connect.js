const { Client } = require('pg');

const connectionString = process.env.DATABASE_URL;

async function tryConnect() {
  if (!connectionString) {
    console.error('ERROR: DATABASE_URL environment variable is required.');
    process.exit(1);
  }
  const client = new Client({ connectionString, ssl: { rejectUnauthorized: false } });
  try {
    await client.connect();
    console.log('Connected to PG successfully.');
    await client.end();
  } catch (e) {
    console.error('Connection failed:', e.message);
  }
}

tryConnect();
