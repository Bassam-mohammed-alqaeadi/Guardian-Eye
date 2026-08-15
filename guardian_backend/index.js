const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

// مسارات البحث عن ملف المفتاح السري
const renderSecretPath = '/etc/secrets/serviceAccountKey.json';
const localSecretPath = path.join(__dirname, 'serviceAccountKey.json');

// اختيار المسار المتوفر تلقائياً
let keyPath = null;
if (fs.existsSync(renderSecretPath)) {
    keyPath = renderSecretPath;
} else if (fs.existsSync(localSecretPath)) {
    keyPath = localSecretPath;
}

try {
    if (keyPath) {
        const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log(`✅ Firebase Admin SDK Initialized Successfully from: ${keyPath}`);
    } else {
        console.warn('⚠️ No Firebase service account file found at local or Render secrets paths.');
    }
} catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error.message);
}

// نقطة فحص الحالة (Health Check)
app.get('/', (req, res) => {
    res.status(200).send('Guardian Eye Backend is Running 🚀');
});

// مسار الـ M5 Child Redemption
app.post('/api/redeem-child', async(req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Unauthorized: Missing or invalid Authorization header' });
        }

        const idToken = authHeader.split('Bearer ')[1];

        // التحقق من هوية الطفل عبر Firebase Auth
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const childUid = decodedToken.uid;

        const { provisioningCode, deviceId } = req.body;

        if (!provisioningCode || !deviceId) {
            return res.status(400).json({ error: 'Missing provisioningCode or deviceId in request body' });
        }

        console.log(`Processing redemption -> Child UID: ${childUid}, Device: ${deviceId}, Code: ${provisioningCode}`);

        // استجابة بنجاح العملية
        return res.status(200).json({
            success: true,
            message: 'Child device successfully provisioned',
            childUid: childUid,
            deviceId: deviceId
        });

    } catch (error) {
        console.error('Redemption error:', error);
        return res.status(500).json({ error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Guardian Backend server listening on port ${PORT}`);
});