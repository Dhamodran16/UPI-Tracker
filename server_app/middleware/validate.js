const { body, validationResult } = require('express-validator');

// Helper - send first validation error
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({ error: errors.array()[0].msg });
  }
  next();
};

const registerRules = [
  body('name').trim().notEmpty().withMessage('Name is required.'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required.'),
  body('phone').trim().notEmpty().withMessage('Mobile number is required.')
    .isLength({ min: 10 }).withMessage('Mobile number must be at least 10 digits.'),
];

const loginRules = [
  body('identifier').trim().notEmpty().withMessage('Email or Mobile number is required.'),
];

const verifyRules = [
  body('identifier').trim().notEmpty().withMessage('Email or Mobile number is required.'),
  body('otp').trim().isLength({ min: 6, max: 6 }).withMessage('OTP must be a 6-digit number.'),
];

const profileRules = [
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty.'),
  body('email').optional().isEmail().normalizeEmail().withMessage('Valid email is required.'),
  body('phone').optional().trim().notEmpty().withMessage('Mobile number cannot be empty.')
    .isLength({ min: 10 }).withMessage('Mobile number must be at least 10 digits.'),
];

module.exports = { validate, registerRules, loginRules, verifyRules, profileRules };
