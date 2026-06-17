const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../models/User');

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ error: 'Email already registered.' });

    const user = await User.create({ name, email, password, phone });
    const token = generateToken(user._id);

    res.status(201).json({
      token,
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select('+password');
    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const token = generateToken(user._id);
    res.json({
      token,
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/auth/me
const getMe = async (req, res) => {
  res.json({ user: req.user });
};

// PATCH /api/auth/profile — update name and/or phone (whitelisted fields only)
const updateProfile = async (req, res) => {
  try {
    const ALLOWED = ['name', 'phone'];
    const update = {};

    for (const field of ALLOWED) {
      if (req.body[field] !== undefined) {
        update[field] = String(req.body[field]).trim();
      }
    }

    if (Object.keys(update).length === 0) {
      return res.status(422).json({ error: 'No valid fields provided. Allowed: name, phone.' });
    }

    if (update.name !== undefined && !update.name) {
      return res.status(422).json({ error: 'name cannot be empty.' });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: update },
      { new: true, runValidators: true }
    ).select('-password');

    if (!user) return res.status(404).json({ error: 'User not found.' });

    res.json({
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/change-password
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(422).json({ error: 'currentPassword and newPassword are required.' });
    }

    if (String(newPassword).length < 6) {
      return res.status(422).json({ error: 'newPassword must be at least 6 characters.' });
    }

    // Re-fetch user with password field (select: false by default)
    const user = await User.findById(req.user._id).select('+password');
    if (!user) return res.status(404).json({ error: 'User not found.' });

    const isMatch = await user.matchPassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ error: 'Current password is incorrect.' });
    }

    user.password = await bcrypt.hash(newPassword, 12);
    // Use direct save with markModified so the pre-save hook does NOT double-hash.
    // We bypass the hook by directly assigning the already-hashed value and
    // temporarily clearing the modified state — instead we skip the hook entirely
    // by using updateOne so we control the hash ourselves.
    await User.updateOne({ _id: user._id }, { $set: { password: user.password } });

    res.json({ message: 'Password changed successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// POST /api/auth/forgot-password
// Safe stub — always returns the same message to prevent email enumeration.
// TODO: Integrate a real email-sending service (e.g. SendGrid, Nodemailer + SMTP)
//       to generate a signed reset token, store it, and email it to the user.
const forgotPassword = async (req, res) => {
  try {
    res.json({ message: 'If that email exists, a reset link has been sent.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = { register, login, getMe, updateProfile, changePassword, forgotPassword };
