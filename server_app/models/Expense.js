const mongoose = require('mongoose');

const CATEGORIES = [
  'Food & Dining', 'Transport', 'Grocery', 'Bills',
  'Health', 'Shopping', 'Transfer', 'Other'
];

const UPI_APPS = ['GPay', 'PhonePe', 'Paytm', 'BHIM', 'AmazonPay', 'Other'];

const ExpenseSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  amount: {
    type: Number,
    required: true,
    min: 0,
  },
  payee: {
    type: String,
    required: true,
    trim: true,
  },
  category: {
    type: String,
    enum: CATEGORIES,
    default: 'Other',
  },
  upiApp: {
    type: String,
    enum: UPI_APPS,
    default: 'Other',
  },
  upiRef: {
    type: String,
    trim: true,
  },
  note: {
    type: String,
    trim: true,
    maxlength: 200,
  },
  date: {
    type: Date,
    default: Date.now,
    index: true,
  },
}, { timestamps: true });

// Prevent duplicate UPI transactions per user
ExpenseSchema.index({ userId: 1, upiRef: 1 }, { unique: true, sparse: true });

// Index for fast monthly queries
ExpenseSchema.index({ userId: 1, date: -1 });

module.exports = mongoose.model('Expense', ExpenseSchema);
