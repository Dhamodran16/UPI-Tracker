const express = require('express');
const router = express.Router();
const {
  register,
  login,
  getMe,
  updateProfile,
  changePassword,
  forgotPassword,
} = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const { validate, registerRules, loginRules } = require('../middleware/validate');

router.post('/register',        registerRules, validate, register);
router.post('/login',           loginRules,    validate, login);
router.get('/me',               protect, getMe);
router.patch('/profile',        protect, updateProfile);
router.post('/change-password', protect, changePassword);
router.post('/forgot-password', forgotPassword);

module.exports = router;
