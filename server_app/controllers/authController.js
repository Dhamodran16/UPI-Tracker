const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { getDb } = require('../config/db');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

// Transporter for nodemailer (Email OTP)
let transporter = null;
if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

const sendEmailOTP = async (email, otp) => {
  if (!transporter) {
    throw new Error('SMTP Mail server configuration is missing in environment variables.');
  }
  await transporter.sendMail({
    from: process.env.SMTP_FROM_EMAIL || '"UPI Tracker" <noreply@example.com>',
    to: email.toLowerCase().trim(),
    subject: 'Your OTP Verification Code',
    text: `Your OTP code is: ${otp}. It will expire in 10 minutes.`,
    html: `<p>Your OTP code is: <strong>${otp}</strong>.</p><p>It will expire in 10 minutes.</p>`,
  });
  console.log(`[OTP] Email successfully sent to ${email} via SMTP`);
};

const syncUserToFirebaseAuth = async (userId, name, email, phone) => {
  try {
    // Normalize phone number to E.164 (requires + and country code, e.g. +91)
    let formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = `+91${formattedPhone}`;
    }

    // Attempt to retrieve user by UID
    let authUser;
    try {
      authUser = await admin.auth().getUser(userId);
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        // Create user with matching firestore userId as UID
        authUser = await admin.auth().createUser({
          uid: userId,
          email: email.toLowerCase().trim(),
          phoneNumber: formattedPhone,
          displayName: name.trim(),
          emailVerified: true
        });
      } else {
        throw err;
      }
    }

    if (authUser) {
      // Keep Firebase Auth in sync with Firestore
      await admin.auth().updateUser(userId, {
        email: email.toLowerCase().trim(),
        phoneNumber: formattedPhone,
        displayName: name.trim()
      });
    }
  } catch (error) {
    console.error(`[Firebase Auth Sync Warning]: ${error.message}`);
  }
};

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { name, email, phone } = req.body;
    const db = getDb();

    // Check if email already exists
    const emailSnapshot = await db.collection('users').where('email', '==', email.toLowerCase().trim()).limit(1).get();
    if (!emailSnapshot.empty) return res.status(400).json({ error: 'Email already registered.' });

    // Check if phone already exists
    const phoneSnapshot = await db.collection('users').where('phone', '==', phone.trim()).limit(1).get();
    if (!phoneSnapshot.empty) return res.status(400).json({ error: 'Mobile number already registered.' });

    // Generate a 6-digit OTP for Email verification
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpires = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    const docRef = await db.collection('users').add({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      otp,
      otpExpires,
      isVerified: false,
      createdAt: new Date().toISOString()
    });

    // Send email OTP
    await sendEmailOTP(email.toLowerCase().trim(), otp);

    res.status(201).json({
      message: 'OTP sent to email successfully',
      identifier: email.toLowerCase().trim()
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { identifier } = req.body;
    const db = getDb();
    const isEmail = identifier.includes('@');
    const searchVal = identifier.trim();

    let query = db.collection('users');
    if (isEmail) {
      query = query.where('email', '==', searchVal.toLowerCase());
    } else {
      query = query.where('phone', '==', searchVal);
    }

    const snapshot = await query.limit(1).get();
    if (snapshot.empty) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const userDoc = snapshot.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;

    if (!isEmail) {
      // For phone number, tell the client to sign in via Firebase Auth client SDK
      return res.json({
        useFirebase: true,
        message: 'Please verify phone number using Firebase client-side SDK.'
      });
    }

    // Generate a 6-digit OTP for Email
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpires = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    await db.collection('users').doc(userId).update({
      otp,
      otpExpires
    });

    // Send real OTP dynamically based on email
    await sendEmailOTP(userData.email, otp);

    res.json({
      message: 'OTP sent successfully',
      identifier: identifier
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/verify-otp
const verifyOtp = async (req, res) => {
  try {
    const { identifier, otp } = req.body;
    const db = getDb();
    const isEmail = identifier.includes('@');
    const searchVal = identifier.trim();

    let query = db.collection('users');
    if (isEmail) {
      query = query.where('email', '==', searchVal.toLowerCase());
    } else {
      query = query.where('phone', '==', searchVal);
    }

    const snapshot = await query.limit(1).get();
    if (snapshot.empty) {
      return res.status(400).json({ error: 'Invalid OTP or expired.' });
    }

    const userDoc = snapshot.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;

    if (!userData.otp || userData.otp !== otp || !userData.otpExpires || new Date(userData.otpExpires) < new Date()) {
      return res.status(400).json({ error: 'Invalid OTP or expired.' });
    }

    // Mark verified and clear OTP
    await db.collection('users').doc(userId).update({
      isVerified: true,
      otp: admin.firestore.FieldValue.delete(),
      otpExpires: admin.firestore.FieldValue.delete()
    });

    // Sync verified user to Firebase Auth and generate custom token
    let firebaseCustomToken = null;
    try {
      await syncUserToFirebaseAuth(userId, userData.name, userData.email, userData.phone);
      firebaseCustomToken = await admin.auth().createCustomToken(userId);
    } catch (e) {
      console.error(`[Firebase Auth customToken warning]: ${e.message}`);
    }

    const token = generateToken(userId);

    res.json({
      token,
      firebaseCustomToken,
      user: { id: userId, name: userData.name, email: userData.email, phone: userData.phone },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/verify-firebase-token
const verifyFirebaseToken = async (req, res) => {
  try {
    const { idToken, name, email } = req.body;
    if (!idToken) return res.status(422).json({ error: 'Firebase ID Token is required.' });

    const db = getDb();
    
    // Verify the Firebase ID Token
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      return res.status(401).json({ error: `Invalid Firebase Token: ${e.message}` });
    }

    // Extract phone number from Firebase Auth token
    const phoneNumber = decodedToken.phone_number;
    if (!phoneNumber) {
      return res.status(422).json({ error: 'Token does not contain a verified phone number.' });
    }

    // Clean phone number: remove any country codes or normalize for Firestore querying
    let rawPhone = phoneNumber;
    if (phoneNumber.startsWith('+91') && phoneNumber.length === 13) {
      rawPhone = phoneNumber.substring(3);
    }

    // Query Firestore for user by phone number
    let userSnapshot = await db.collection('users').where('phone', '==', rawPhone).limit(1).get();
    if (userSnapshot.empty) {
      userSnapshot = await db.collection('users').where('phone', '==', phoneNumber).limit(1).get();
    }

    // User exists, log them in
    if (!userSnapshot.empty) {
      const userDoc = userSnapshot.docs[0];
      const userData = userDoc.data();
      const token = generateToken(userDoc.id);
      return res.json({
        token,
        user: { id: userDoc.id, name: userData.name, email: userData.email, phone: userData.phone }
      });
    }

    // User does not exist (Registration flow via Firebase Phone Auth)
    if (!name || !email) {
      // Ask client for name and email to complete registration
      return res.status(200).json({
        newUser: true,
        phone: rawPhone,
        message: 'Account not found. Please provide name and email to complete registration.'
      });
    }

    // Check unique email
    const emailSnapshot = await db.collection('users').where('email', '==', email.toLowerCase().trim()).limit(1).get();
    if (!emailSnapshot.empty) {
      return res.status(400).json({ error: 'Email already registered.' });
    }

    // Create the new user in Firestore
    const docRef = await db.collection('users').add({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      phone: rawPhone,
      isVerified: true,
      createdAt: new Date().toISOString()
    });

    const token = generateToken(docRef.id);
    
    // Sync back to Firebase Auth to set displayName/email
    try {
      await admin.auth().updateUser(decodedToken.uid, {
        displayName: name.trim(),
        email: email.toLowerCase().trim()
      });
    } catch (err) {
      console.error('[Firebase Auth Register Sync Error]:', err.message);
    }

    res.status(201).json({
      token,
      user: { id: docRef.id, name: name.trim(), email: email.toLowerCase().trim(), phone: rawPhone }
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/auth/me
const getMe = async (req, res) => {
  res.json({ user: req.user });
};

// PATCH /api/auth/profile - update name, email, and phone
const updateProfile = async (req, res) => {
  try {
    const { name, email, phone } = req.body;
    const db = getDb();
    const userId = req.user.id;

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return res.status(404).json({ error: 'User not found.' });

    const update = {};

    if (name !== undefined) {
      const trimmedName = name.trim();
      if (!trimmedName) return res.status(422).json({ error: 'Name cannot be empty.' });
      update.name = trimmedName;
    }

    if (email !== undefined) {
      const normalizedEmail = email.toLowerCase().trim();
      if (!normalizedEmail) return res.status(422).json({ error: 'Email cannot be empty.' });
      
      // Check uniqueness
      const emailSnapshot = await db.collection('users').where('email', '==', normalizedEmail).get();
      const otherEmailUser = emailSnapshot.docs.find(d => d.id !== userId);
      if (otherEmailUser) return res.status(400).json({ error: 'Email already in use.' });
      update.email = normalizedEmail;
    }

    if (phone !== undefined) {
      const trimmedPhone = phone.trim();
      if (!trimmedPhone) return res.status(422).json({ error: 'Mobile number cannot be empty.' });
      if (trimmedPhone.length < 10) return res.status(422).json({ error: 'Mobile number must be at least 10 digits.' });

      // Check uniqueness
      const phoneSnapshot = await db.collection('users').where('phone', '==', trimmedPhone).get();
      const otherPhoneUser = phoneSnapshot.docs.find(d => d.id !== userId);
      if (otherPhoneUser) return res.status(400).json({ error: 'Mobile number already in use.' });
      update.phone = trimmedPhone;
    }

    if (Object.keys(update).length > 0) {
      await db.collection('users').doc(userId).update(update);
    }

    const updatedDoc = await db.collection('users').doc(userId).get();
    const updatedData = updatedDoc.data();

    // Sync updated info to Firebase Auth
    await syncUserToFirebaseAuth(userId, updatedData.name, updatedData.email, updatedData.phone);

    res.json({
      user: { id: userId, name: updatedData.name, email: updatedData.email, phone: updatedData.phone },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { register, login, verifyOtp, verifyFirebaseToken, getMe, updateProfile };
