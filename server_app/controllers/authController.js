const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const { getDb } = require('../config/db');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });


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

// POST /api/auth/register (Deprecated)
const register = async (req, res) => {
  res.status(400).json({ error: 'Deprecated: Register via Firebase Phone Auth directly.' });
};

// POST /api/auth/login (Deprecated)
const login = async (req, res) => {
  res.status(400).json({ error: 'Deprecated: Login via Firebase Phone Auth directly.' });
};

// POST /api/auth/verify-otp (Deprecated)
const verifyOtp = async (req, res) => {
  res.status(400).json({ error: 'Deprecated: Verify via Firebase Phone Auth directly.' });
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

module.exports = { register, login, verifyOtp, verifyFirebaseToken, getMe, updateProfile, testEmailConnection };
