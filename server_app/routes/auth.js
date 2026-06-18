const express = require('express');
const router = express.Router();
const {
  register,
  login,
  verifyOtp,
  verifyFirebaseToken,
  getMe,
  updateProfile,
} = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const { validate, registerRules, loginRules, verifyRules, profileRules } = require('../middleware/validate');

router.post('/register',   registerRules, validate, register);
router.post('/login',      loginRules,    validate, login);
router.post('/verify-otp', verifyRules,   validate, verifyOtp);
router.post('/verify-firebase-token', verifyFirebaseToken);
router.get('/me',          protect, getMe);
router.patch('/profile',   protect, profileRules, validate, updateProfile);

module.exports = router;
