const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// مسار مفتاح Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin SDK Initialized Successfully');
} catch (error) {
    console.warn('⚠️ Firebase Admin SDK key not found locally (will use Render Secret File in production):', error.message);
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
            return res.status(401).json({ error: 'Unauthorized: Missing Token' });
        }

        const idToken = authHeader.split('Bearer ')[1];
        // التحقق من هوية الطفل عبر Firebase Auth
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const childUid = decodedToken.uid;

        const { provisioningCode, deviceId } = req.body;

        console.log(`Processing redemption for Child UID: ${childUid}, Device: ${deviceId}, Code: ${provisioningCode}`);

        // استجابة مبدئية ناجحة لإتمام دورة التحقق
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
    console.log(`Server listening on port ${PORT}`);
});