const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

// مسارات المفتاح السري
const renderSecretPath = '/etc/secrets/serviceAccountKey.json';
const localSecretPath = path.join(__dirname, 'serviceAccountKey.json');

let keyPath = null;
if (fs.existsSync(renderSecretPath)) {
    keyPath = renderSecretPath;
} else if (fs.existsSync(localSecretPath)) {
    keyPath = localSecretPath;
}

try {
    if (keyPath) {
        const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));

        // استخدام credential مباشرة بطريقة آمنة
        const credential = admin.credential ?
            admin.credential.cert(serviceAccount) :
            admin.default.credential.cert(serviceAccount);

        admin.initializeApp({ credential });
        console.log(`✅ Firebase Admin SDK Initialized Successfully from: ${keyPath}`);
    } else {
        console.warn('⚠️ No Service Account key file found at:', keyPath);
    }
} catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error.message);
}

// فحص صحة السيرفر (Health Check)
app.get('/', (req, res) => {
    res.status(200).send('Guardian Eye Backend is Running 🚀');
});

// مسار الـ M5 Child Redemption
app.post('/api/redeem-child', async(req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Unauthorized: Missing Token' });
        }

        const idToken = authHeader.split('Bearer ')[1];

        // التحقق من هوية الطفل عبر Firebase
        const decodedToken = await admin.auth().verifyIdToken(idToken);
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
    console.log(`Server listening on port ${PORT}`);
});