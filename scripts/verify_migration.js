const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const path = require('path');
const fs = require('fs');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', 'assets', 'service_account.json');
const SUPABASE_URL = 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDc1Njc0NiwiZXhwIjoyMTAwMzMyNzQ2fQ.WygklhW-UcFDVzhaqXBY2Yz4548stBFuwnmep8y_OXg';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

if (fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }
}

async function getFirestoreCount(collectionName) {
    if (!admin.apps.length) return 'N/A (No Service Account)';
    try {
        const snapshot = await admin.firestore().collection(collectionName).get();
        return snapshot.size;
    } catch (e) {
        return `Error: ${e.message}`;
    }
}

async function getSupabaseCount(tableName) {
    try {
        const { count, error } = await supabase.from(tableName).select('*', { count: 'exact', head: true });
        if (error) return `Error: ${error.message}`;
        return count;
    } catch (e) {
        return `Error: ${e.message}`;
    }
}

async function runVerification() {
    console.log('====================================================');
    console.log('FIREBASE VS SUPABASE DATA MIGRATION VERIFICATION');
    console.log('====================================================');

    const collections = [
        { firestore: 'users', supabase: 'users' },
        { firestore: 'passengers', supabase: 'passengers' },
        { firestore: 'drivers', supabase: 'drivers' },
        { firestore: 'vehicles', supabase: 'vehicles' },
        { firestore: 'rideRequests', supabase: 'ride_requests' },
        { firestore: 'rideOffers', supabase: 'ride_offers' },
        { firestore: 'chatMessages', supabase: 'chat_messages' },
        { firestore: 'ratings', supabase: 'ratings' },
        { firestore: 'notifications', supabase: 'notifications' },
        { firestore: 'transactions', supabase: 'transactions' },
        { firestore: 'supportChats', supabase: 'support_chats' }
    ];

    const results = [];

    for (const item of collections) {
        const fsCount = await getFirestoreCount(item.firestore);
        const sbCount = await getSupabaseCount(item.supabase);
        results.push({
            Collection: item.firestore,
            Table: item.supabase,
            FirestoreCount: fsCount,
            SupabaseCount: sbCount,
            Status: (fsCount === sbCount) ? '100% MATCH' : (sbCount > 0 ? 'MIGRATED' : 'EMPTY / NOT PRESENT')
        });
    }

    console.table(results);
}

runVerification().catch(console.error);
