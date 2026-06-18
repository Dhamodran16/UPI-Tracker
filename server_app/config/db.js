const admin = require('firebase-admin');
const { getApps } = require('firebase-admin/app');

const connectDB = () => {
  if (getApps().length === 0) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;

    if (projectId && clientEmail && privateKey) {
      if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
        privateKey = privateKey.substring(1, privateKey.length - 1);
      }
      admin.initializeApp({
        credential: admin.cert({
          projectId,
          clientEmail,
          privateKey: privateKey.replace(/\\n/g, '\n'),
        }),
      });
      console.log('Firebase Admin initialized successfully using credentials.');
    } else {
      // Fallback
      try {
        admin.initializeApp({
          credential: admin.applicationDefault(),
        });
        console.log('Firebase Admin initialized successfully using applicationDefault.');
      } catch (err) {
        console.warn('Firebase applicationDefault credentials not found. Booting in mock/emulator mode...');
        admin.initializeApp({
          projectId: projectId || 'upi-tracker-mock',
        });
      }
    }
  }
  return admin.firestore();
};

const getDb = () => {
  if (getApps().length === 0) {
    return connectDB();
  }
  return admin.firestore();
};

module.exports = { connectDB, getDb };
