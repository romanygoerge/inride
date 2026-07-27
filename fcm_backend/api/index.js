const admin = require("firebase-admin");

// Initialize Firebase Admin with Service Account from Environment Variable
if (!admin.apps.length) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  } catch (error) {
    console.error("Failed to initialize Firebase Admin:", error);
  }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Expecting a secret key header for basic security
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.APP_SECRET_KEY}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { to, notification, data } = req.body;

  if (!to) {
    return res.status(400).json({ error: "Missing 'to' field (FCM token)" });
  }

  // Build the V1 Message payload
  const message = {
    token: to,
    notification: {
      title: notification?.title || "Notification",
      body: notification?.body || "",
    },
    data: data || {},
    android: {
      priority: 'high',
      notification: {
        sound: notification?.sound || 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: notification?.sound || 'default'
        }
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    res.status(200).json({ success: true, response });
  } catch (error) {
    console.error("Error sending message:", error);
    res.status(500).json({ error: error.message });
  }
}
