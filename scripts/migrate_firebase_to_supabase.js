const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Configuration Constants
const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', 'assets', 'service_account.json');
const MIGRATION_LOG_PATH = path.join(__dirname, '..', 'migration.log');
const REPORT_PATH = path.join(__dirname, '..', 'migration_report.json');

// Supabase Configuration (Will read from environment or fall back to defaults)
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-supabase-project.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-supabase-service-role-key';

let logStream;

function log(message) {
    const timestamp = new Date().toISOString();
    const formatted = `[${timestamp}] ${message}`;
    console.log(formatted);
    if (!logStream) {
        logStream = fs.createWriteStream(MIGRATION_LOG_PATH, { flags: 'a' });
    }
    logStream.write(formatted + '\n');
}

// Convert Firestore String ID to UUID if needed
function toUUID(str) {
    if (!str) return '00000000-0000-0000-0000-000000000000';
    // If already valid UUID format (8-4-4-4-12)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (uuidRegex.test(str)) return str;

    // Generate deterministic UUID v4 hex from string
    let hash = 0;
    const crypto = require('crypto');
    const md5Hex = crypto.createHash('md5').update(str).digest('hex');
    return `${md5Hex.substring(0, 8)}-${md5Hex.substring(8, 12)}-4${md5Hex.substring(13, 16)}-a${md5Hex.substring(17, 20)}-${md5Hex.substring(20, 32)}`;
}

// Download file helper
function downloadFile(url, destPath) {
    return new Promise((resolve, reject) => {
        const client = url.startsWith('https') ? https : http;
        const file = fs.createWriteStream(destPath);
        client.get(url, (response) => {
            if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
                return downloadFile(response.headers.location, destPath).then(resolve).catch(reject);
            }
            if (response.statusCode !== 200) {
                return reject(new Error(`Failed to download ${url}: status ${response.statusCode}`));
            }
            response.pipe(file);
            file.on('finish', () => {
                file.close(() => resolve(destPath));
            });
        }).on('error', (err) => {
            fs.unlink(destPath, () => {});
            reject(err);
        });
    });
}

async function runMigration() {
    log('====================================================');
    log('STARTING FIREBASE & CLOUDINARY TO SUPABASE MIGRATION');
    log('====================================================');

    const stats = {
        users: { count: 0, failed: 0 },
        passengers: { count: 0, failed: 0 },
        drivers: { count: 0, failed: 0 },
        vehicles: { count: 0, failed: 0 },
        rideRequests: { count: 0, failed: 0 },
        rideOffers: { count: 0, failed: 0 },
        chatMessages: { count: 0, failed: 0 },
        ratings: { count: 0, failed: 0 },
        notifications: { count: 0, failed: 0 },
        transactions: { count: 0, failed: 0 },
        supportChats: { count: 0, failed: 0 },
        imagesMigrated: 0,
        filesMigrated: 0,
        errorsFixed: []
    };

    // 1. Initialize Firebase
    if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
        log(`CRITICAL ERROR: Service account file not found at ${SERVICE_ACCOUNT_PATH}`);
        process.exit(1);
    }
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            storageBucket: serviceAccount.project_id + '.appspot.com'
        });
    }
    const db = admin.firestore();
    log('Firebase Admin SDK initialized successfully.');

    // 2. Initialize Supabase Client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false, persistSession: false }
    });
    log('Supabase Client initialized.');

    // 3. Temporary directory for asset downloads
    const tempDir = path.join(__dirname, 'temp_downloads');
    if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

    // Helper function to migrate image/file URL to Supabase Storage
    async function migrateMediaUrl(url, bucketName, targetFileName) {
        if (!url || typeof url !== 'string' || !url.startsWith('http')) return url;
        if (url.includes('supabase.co')) return url; // Already in Supabase Storage

        try {
            log(`Downloading external asset: ${url}`);
            const tempFile = path.join(tempDir, `file_${Date.now()}_${Math.floor(Math.random()*1000)}`);
            await downloadFile(url, tempFile);
            
            const fileBuffer = fs.readFileSync(tempFile);
            const ext = path.extname(url.split('?')[0]) || '.jpg';
            const storagePath = `${targetFileName}${ext}`;

            const { data, error } = await supabase.storage.from(bucketName).upload(storagePath, fileBuffer, {
                contentType: 'image/jpeg',
                upsert: true
            });

            fs.unlinkSync(tempFile);

            if (error) {
                log(`Error uploading file to bucket ${bucketName}: ${error.message}`);
                return url; // Fallback
            }

            const { data: publicUrlData } = supabase.storage.from(bucketName).getPublicUrl(storagePath);
            stats.imagesMigrated++;
            log(`Migrated image to Supabase Storage: ${publicUrlData.publicUrl}`);
            return publicUrlData.publicUrl;
        } catch (e) {
            log(`Failed to migrate media asset ${url}: ${e.message}`);
            return url;
        }
    }

    // ----------------------------------------------------
    // STEP A: MIGRATE AUTH USERS & USERS COLLECTION
    // ----------------------------------------------------
    log('Phase A: Migrating Users & Auth data...');
    try {
        const usersSnap = await db.collection('Users').get();
        for (const doc of usersSnap.docs) {
            const data = doc.data();
            const originalUid = doc.id;
            const uuid = toUUID(originalUid);
            let avatarUrl = data.avatarUrl || '';

            if (avatarUrl) {
                avatarUrl = await migrateMediaUrl(avatarUrl, 'avatars', `avatar_${uuid}`);
            }

            const userRecord = {
                id: uuid,
                name: data.name || '',
                phone_number: data.phoneNumber || data.phone || '',
                email: data.email || '',
                role: data.role || 'rider',
                rating: Number(data.rating || 5.0),
                wallet_balance: Number(data.walletBalance || 250.00),
                avatar_url: avatarUrl,
                fcm_token: data.fcmToken || '',
                created_at: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt).toISOString() : new Date().toISOString()
            };

            const { error } = await supabase.from('users').upsert(userRecord);
            if (error) {
                log(`Error upserting user ${originalUid}: ${error.message}`);
                stats.users.failed++;
            } else {
                stats.users.count++;

                // Migrate subcollection Users/{uid}/Notifications
                const notifsSnap = await db.collection('Users').doc(originalUid).collection('Notifications').get();
                for (const notifDoc of notifsSnap.docs) {
                    const nData = notifDoc.data();
                    const notifId = toUUID(notifDoc.id);
                    await supabase.from('notifications').upsert({
                        id: notifId,
                        user_id: uuid,
                        title: nData.title || '',
                        body: nData.body || '',
                        type: nData.type || 'info',
                        is_read: Boolean(nData.isRead),
                        data: nData.data || {},
                        created_at: nData.createdAt ? new Date(nData.createdAt.toDate ? nData.createdAt.toDate() : nData.createdAt).toISOString() : new Date().toISOString()
                    });
                    stats.notifications.count++;
                }

                // Migrate subcollection Users/{uid}/Transactions
                const txSnap = await db.collection('Users').doc(originalUid).collection('Transactions').get();
                for (const txDoc of txSnap.docs) {
                    const tData = txDoc.data();
                    const txId = toUUID(txDoc.id);
                    await supabase.from('transactions').upsert({
                        id: txId,
                        user_id: uuid,
                        title: tData.title || '',
                        amount: Number(tData.amount || 0),
                        type: tData.type || 'credit',
                        balance_after: Number(tData.balanceAfter || 0),
                        created_at: tData.timestamp ? new Date(tData.timestamp.toDate ? tData.timestamp.toDate() : tData.timestamp).toISOString() : new Date().toISOString()
                    });
                    stats.transactions.count++;
                }
            }
        }
    } catch (err) {
        log(`Error in Phase A (Users): ${err.message}`);
    }

    // ----------------------------------------------------
    // STEP B: MIGRATE PASSENGERS COLLECTION
    // ----------------------------------------------------
    log('Phase B: Migrating Passengers collection...');
    try {
        const passSnap = await db.collection('Passengers').get();
        for (const doc of passSnap.docs) {
            const data = doc.data();
            const uuid = toUUID(doc.id);
            const { error } = await supabase.from('passengers').upsert({
                id: uuid,
                name: data.name || '',
                email: data.email || '',
                phone: data.phone || data.phoneNumber || '',
                avatar_url: data.avatarUrl || '',
                fcm_token: data.fcmToken || '',
                total_trips: Number(data.totalTrips || 0),
                rating: Number(data.rating || 5.0)
            });
            if (error) stats.passengers.failed++;
            else stats.passengers.count++;
        }
    } catch (err) {
        log(`Error in Phase B (Passengers): ${err.message}`);
    }

    // ----------------------------------------------------
    // STEP C: MIGRATE VEHICLES COLLECTION
    // ----------------------------------------------------
    log('Phase C: Migrating Vehicles collection...');
    try {
        const vehSnap = await db.collection('Vehicles').get();
        for (const doc of vehSnap.docs) {
            const data = doc.data();
            const uuid = toUUID(doc.id);
            const driverUuid = toUUID(data.driverId);
            const { error } = await supabase.from('vehicles').upsert({
                id: uuid,
                driver_id: driverUuid,
                model: data.model || '',
                number_plate: data.numberPlate || '',
                color: data.color || '',
                type: data.type || 'car',
                year: Number(data.year || 2020),
                status: data.status || 'active',
                license_url: data.licenseUrl || '',
                insurance_url: data.insuranceUrl || ''
            });
            if (error) stats.vehicles.failed++;
            else stats.vehicles.count++;
        }
    } catch (err) {
        log(`Error in Phase C (Vehicles): ${err.message}`);
    }

    // ----------------------------------------------------
    // STEP D: MIGRATE DRIVERS COLLECTION
    // ----------------------------------------------------
    log('Phase D: Migrating Drivers collection...');
    try {
        const drivSnap = await db.collection('Drivers').get();
        for (const doc of drivSnap.docs) {
            const data = doc.data();
            const uuid = toUUID(doc.id);
            let nationalIdUrl = data.nationalIdUrl || '';
            let licenseUrl = data.licenseUrl || '';
            let vehicleFrontUrl = data.vehicleFrontUrl || '';
            let vehicleBackUrl = data.vehicleBackUrl || '';
            let vehicleLicenseUrl = data.vehicleLicenseUrl || '';

            if (nationalIdUrl) nationalIdUrl = await migrateMediaUrl(nationalIdUrl, 'national_ids', `nid_${uuid}`);
            if (licenseUrl) licenseUrl = await migrateMediaUrl(licenseUrl, 'licenses', `lic_${uuid}`);
            if (vehicleFrontUrl) vehicleFrontUrl = await migrateMediaUrl(vehicleFrontUrl, 'captains', `vf_${uuid}`);
            if (vehicleBackUrl) vehicleBackUrl = await migrateMediaUrl(vehicleBackUrl, 'captains', `vb_${uuid}`);
            if (vehicleLicenseUrl) vehicleLicenseUrl = await migrateMediaUrl(vehicleLicenseUrl, 'licenses', `vlic_${uuid}`);

            const { error } = await supabase.from('drivers').upsert({
                id: uuid,
                is_online: Boolean(data.isOnline),
                is_available: Boolean(data.isAvailable !== false),
                verification_status: data.verificationStatus || 'unregistered',
                vehicle_id: data.vehicleId ? toUUID(data.vehicleId) : null,
                current_latitude: data.currentLatitude ? Number(data.currentLatitude) : null,
                current_longitude: data.currentLongitude ? Number(data.currentLongitude) : null,
                national_id_url: nationalIdUrl,
                license_url: licenseUrl,
                vehicle_front_url: vehicleFrontUrl,
                vehicle_back_url: vehicleBackUrl,
                vehicle_license_url: vehicleLicenseUrl,
                avatar_url: data.avatarUrl || '',
                fcm_token: data.fcmToken || '',
                rating: Number(data.rating || 5.0),
                total_earnings: Number(data.totalEarnings || 0.0),
                total_trips: Number(data.totalTrips || 0)
            });
            if (error) stats.drivers.failed++;
            else stats.drivers.count++;
        }
    } catch (err) {
        log(`Error in Phase D (Drivers): ${err.message}`);
    }

    // ----------------------------------------------------
    // STEP E: MIGRATE RIDE REQUESTS & CHAT MESSAGES
    // ----------------------------------------------------
    log('Phase E: Migrating RideRequests & Chat Messages...');
    try {
        const reqSnap = await db.collection('RideRequests').get();
        for (const doc of reqSnap.docs) {
            const data = doc.data();
            const reqId = toUUID(doc.id);
            let pickupPhotoUrl = data.pickupPhotoUrl || '';
            let deliveryPhotoUrl = data.deliveryPhotoUrl || '';

            if (pickupPhotoUrl) pickupPhotoUrl = await migrateMediaUrl(pickupPhotoUrl, 'deliveries', `pickup_${reqId}`);
            if (deliveryPhotoUrl) deliveryPhotoUrl = await migrateMediaUrl(deliveryPhotoUrl, 'deliveries', `delivery_${reqId}`);

            const { error } = await supabase.from('ride_requests').upsert({
                id: reqId,
                passenger_id: toUUID(data.passengerId),
                driver_id: data.driverId ? toUUID(data.driverId) : null,
                pickup_latitude: Number(data.pickupLatitude || 0),
                pickup_longitude: Number(data.pickupLongitude || 0),
                pickup_address: data.pickupAddress || '',
                destination_latitude: Number(data.destinationLatitude || 0),
                destination_longitude: Number(data.destinationLongitude || 0),
                destination_address: data.destinationAddress || '',
                vehicle_type: data.vehicleType || 'car',
                offered_fare: Number(data.offeredFare || 0),
                distance: Number(data.distance || 0),
                status: data.status || 'Pending',
                payment_method: data.paymentMethod || 'cash',
                service_type: data.serviceType || 'ride',
                package_description: data.packageDescription || null,
                delivery_notes: data.deliveryNotes || null,
                passenger_count: Number(data.passengerCount || 1),
                is_delivery_location_confirmed: Boolean(data.isDeliveryLocationConfirmed !== false),
                recipient_phone: data.recipientPhone || null,
                recipient_region: data.recipientRegion || null,
                recipient_street: data.recipientStreet || null,
                recipient_building: data.recipientBuilding || null,
                recipient_floor: data.recipientFloor || null,
                recipient_landmark: data.recipientLandmark || null,
                recipient_token: data.recipientToken || null,
                pickup_photo_url: pickupPhotoUrl,
                delivery_photo_url: deliveryPhotoUrl,
                cancel_reason: data.cancelReason || null,
                cancellation_reason: data.cancellationReason || null,
                cancelled_by: data.cancelledBy || null,
                created_at: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt).toISOString() : new Date().toISOString()
            });

            if (error) {
                stats.rideRequests.failed++;
                log(`Failed ride_request ${reqId}: ${error.message}`);
            } else {
                stats.rideRequests.count++;

                // Migrate Chat Messages for this ride
                const msgSnap = await db.collection('RideRequests').doc(doc.id).collection('Messages').get();
                for (const mDoc of msgSnap.docs) {
                    const mData = mDoc.data();
                    const msgId = toUUID(mDoc.id);
                    let audioUrl = mData.audioUrl || '';
                    let imageUrl = mData.imageUrl || '';
                    if (audioUrl) audioUrl = await migrateMediaUrl(audioUrl, 'chat', `audio_${msgId}`);
                    if (imageUrl) imageUrl = await migrateMediaUrl(imageUrl, 'chat', `img_${msgId}`);

                    await supabase.from('chat_messages').upsert({
                        id: msgId,
                        request_id: reqId,
                        sender_id: toUUID(mData.senderId),
                        sender_name: mData.senderName || '',
                        text: mData.text || '',
                        is_driver: Boolean(mData.isDriver),
                        type: mData.type || 'text',
                        audio_url: audioUrl,
                        image_url: imageUrl,
                        created_at: mData.timestamp ? new Date(mData.timestamp.toDate ? mData.timestamp.toDate() : mData.timestamp).toISOString() : new Date().toISOString()
                    });
                    stats.chatMessages.count++;
                }
            }
        }
    } catch (err) {
        log(`Error in Phase E (RideRequests): ${err.message}`);
    }

    // ----------------------------------------------------
    // STEP F: MIGRATE RIDE OFFERS & RATINGS
    // ----------------------------------------------------
    log('Phase F: Migrating Ride Offers & Ratings...');
    try {
        const offerSnap = await db.collection('RideOffers').get();
        for (const doc of offerSnap.docs) {
            const data = doc.data();
            await supabase.from('ride_offers').upsert({
                id: toUUID(doc.id),
                request_id: toUUID(data.requestId),
                driver_id: toUUID(data.driverId),
                passenger_id: toUUID(data.passengerId),
                driver_name: data.driverName || 'سائق',
                driver_avatar: data.driverAvatar || '',
                driver_rating: Number(data.driverRating || 5.0),
                vehicle_type: data.vehicleType || 'car',
                vehicle_name: data.vehicleName || '',
                license_plate: data.licensePlate || '',
                price: Number(data.price || 0),
                eta_minutes: Number(data.etaMinutes || 5),
                status: data.status || 'pending',
                created_at: data.timestamp ? new Date(data.timestamp.toDate ? data.timestamp.toDate() : data.timestamp).toISOString() : new Date().toISOString()
            });
            stats.rideOffers.count++;
        }

        const ratingSnap = await db.collection('Ratings').get();
        for (const doc of ratingSnap.docs) {
            const data = doc.data();
            await supabase.from('ratings').upsert({
                id: doc.id,
                request_id: toUUID(data.requestId),
                sender_id: toUUID(data.senderId),
                receiver_id: toUUID(data.receiverId),
                receiver_role: data.receiverRole || 'rider',
                rating: Number(data.rating || 5.0),
                comment: data.comment || '',
                created_at: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt).toISOString() : new Date().toISOString()
            });
            stats.ratings.count++;
        }
    } catch (err) {
        log(`Error in Phase F (Offers & Ratings): ${err.message}`);
    }

    // Cleanup temp directory
    if (fs.existsSync(tempDir)) {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }

    // Output final report
    log('====================================================');
    log('MIGRATION SUMMARY AND VERIFICATION REPORT');
    log('====================================================');
    log(`Users Migrated: ${stats.users.count} (Failed: ${stats.users.failed})`);
    log(`Passengers Migrated: ${stats.passengers.count} (Failed: ${stats.passengers.failed})`);
    log(`Drivers Migrated: ${stats.drivers.count} (Failed: ${stats.drivers.failed})`);
    log(`Vehicles Migrated: ${stats.vehicles.count} (Failed: ${stats.vehicles.failed})`);
    log(`Ride Requests Migrated: ${stats.rideRequests.count} (Failed: ${stats.rideRequests.failed})`);
    log(`Ride Offers Migrated: ${stats.rideOffers.count}`);
    log(`Chat Messages Migrated: ${stats.chatMessages.count}`);
    log(`Ratings Migrated: ${stats.ratings.count}`);
    log(`Notifications Migrated: ${stats.notifications.count}`);
    log(`Transactions Migrated: ${stats.transactions.count}`);
    log(`Media Assets Uploaded to Supabase Storage: ${stats.imagesMigrated}`);

    fs.writeFileSync(REPORT_PATH, JSON.stringify(stats, null, 2));
    log(`Report saved to ${REPORT_PATH}`);
}

runMigration().catch(err => {
    log(`UNHANDLED FATAL ERROR IN MIGRATION SCRIPT: ${err.stack || err}`);
    process.exit(1);
});
