const express = require('express');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

// مسارات ملف المفتاح السري
const renderSecretPath = '/etc/secrets/serviceAccountKey.json';
const localSecretPath = path.join(__dirname, 'serviceAccountKey.json');

let keyPath = null;
if (fs.existsSync(renderSecretPath)) {
    keyPath = renderSecretPath;
} else if (fs.existsSync(localSecretPath)) {
    keyPath = localSecretPath;
}

// تهيئة Firebase Admin
let authInstance = null;
try {
    if (keyPath) {
        const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        const firebaseApp = initializeApp({
            credential: cert(serviceAccount)
        });
        authInstance = getAuth(firebaseApp);
        console.log(`✅ Firebase Admin SDK Initialized Successfully from: ${keyPath}`);
    } else {
        console.warn('⚠️ No Service Account key file found at:', keyPath);
    }
} catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error.message);
}

// فحص صحة السيرفر
app.get('/', (req, res) => {
    res.status(200).send('Guardian Eye Backend is Running 🚀');
});

// مسار الـ M5 Child Redemption
app.post('/api/redeem-child', async(req, res) => {
    try {
        if (!authInstance) {
            return res.status(500).json({ error: 'Firebase Admin not initialized on server' });
        }

        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Unauthorized: Missing or invalid Authorization header' });
        }

        const idToken = authHeader.split('Bearer ')[1];

        // التحقق من هوية الطفل
        const decodedToken = await authInstance.verifyIdToken(idToken);
        const childUid = decodedToken.uid;

        const { provisioningCode, deviceId } = req.body;

        if (!provisioningCode || !deviceId) {
            return res.status(400).json({ error: 'Missing provisioningCode or deviceId' });
        }

        console.log(`[M5] Child Verified -> UID: ${childUid}, Device: ${deviceId}, Code: ${provisioningCode}`);

        return res.status(200).json({
            success: true,
            message: 'Child device successfully provisioned',
            childUid: childUid,
            deviceId: deviceId
        });

    } catch (error) {
        console.error('[M5] Redemption Error:', error.message);
        return res.status(500).json({ error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Guardian Backend server listening on port ${PORT}`);
});