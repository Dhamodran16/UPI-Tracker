const { getDb } = require('../config/db');
const admin = require('firebase-admin');

// POST /api/expenses
const createExpense = async (req, res) => {
  try {
    const { amount, payee, category, upiApp, upiRef, note, date } = req.body;
    const db = getDb();

    if (!amount || isNaN(amount) || Number(amount) <= 0)
      return res.status(422).json({ error: 'amount must be a positive number.' });
    if (!payee || !String(payee).trim())
      return res.status(422).json({ error: 'payee is required.' });

    const trimmedRef = upiRef ? String(upiRef).trim() : null;

    // Prevent duplicate UPI transactions per user
    if (trimmedRef) {
      const dupSnapshot = await db.collection('expenses')
        .where('userId', '==', req.user.id)
        .where('upiRef', '==', trimmedRef)
        .limit(1)
        .get();
      if (!dupSnapshot.empty) {
        return res.status(200).json({ duplicate: true, message: 'Transaction already logged.' });
      }
    }

    const expenseDate = date ? new Date(date) : new Date();

    const docRef = await db.collection('expenses').add({
      userId: req.user.id,
      amount: Number(amount),
      payee: String(payee).trim(),
      category: category || 'Other',
      upiApp: upiApp || 'Other',
      upiRef: trimmedRef,
      note: note ? String(note).trim() : null,
      date: admin.firestore.Timestamp.fromDate(expenseDate),
      createdAt: new Date().toISOString()
    });

    const expense = {
      _id: docRef.id,
      userId: req.user.id,
      amount: Number(amount),
      payee: String(payee).trim(),
      category: category || 'Other',
      upiApp: upiApp || 'Other',
      upiRef: trimmedRef,
      note: note ? String(note).trim() : null,
      date: expenseDate.toISOString(),
    };

    res.status(201).json(expense);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses
const getExpenses = async (req, res) => {
  try {
    const page     = Math.max(1, parseInt(req.query.page,  10) || 1);
    const limit    = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const month    = parseInt(req.query.month, 10) || null;
    const year     = parseInt(req.query.year,  10) || null;
    const category = req.query.category || null;

    const db = getDb();
    const snapshot = await db.collection('expenses')
      .where('userId', '==', req.user.id)
      .get();

    let expenses = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const expDate = data.date ? data.date.toDate() : new Date();
      expenses.push({
        _id: doc.id,
        ...data,
        date: expDate
      });
    });

    // In-memory filter and sort to avoid composite indexes in Firestore
    if (month && year && month >= 1 && month <= 12) {
      expenses = expenses.filter(e => e.date.getMonth() + 1 === month && e.date.getFullYear() === year);
    }
    if (category) {
      expenses = expenses.filter(e => e.category === category);
    }

    expenses.sort((a, b) => b.date - a.date);

    const total = expenses.length;
    const paginated = expenses.slice((page - 1) * limit, page * limit);

    // Format date field back to ISO string for the client
    const formatted = paginated.map(e => ({
      ...e,
      date: e.date.toISOString()
    }));

    res.json({
      expenses: formatted,
      pagination: { total, page, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/summary
const getMonthlySummary = async (req, res) => {
  try {
    const month = Math.min(12, Math.max(1, parseInt(req.query.month, 10) || new Date().getMonth() + 1));
    const year  = parseInt(req.query.year, 10) || new Date().getFullYear();

    const db = getDb();
    const snapshot = await db.collection('expenses')
      .where('userId', '==', req.user.id)
      .get();

    let expenses = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const expDate = data.date ? data.date.toDate() : new Date();
      expenses.push({
        _id: doc.id,
        ...data,
        date: expDate
      });
    });

    // Filter in memory by month & year
    const filtered = expenses.filter(e => e.date.getMonth() + 1 === month && e.date.getFullYear() === year);

    // Calculate Category Breakdown
    const catMap = {};
    filtered.forEach(e => {
      if (!catMap[e.category]) {
        catMap[e.category] = { total: 0, count: 0 };
      }
      catMap[e.category].total += e.amount;
      catMap[e.category].count += 1;
    });

    const categoryBreakdown = Object.entries(catMap).map(([category, data]) => ({
      _id: category,
      total: data.total,
      count: data.count
    })).sort((a, b) => b.total - a.total);

    // Calculate Daily Trend
    const dailyMap = {};
    filtered.forEach(e => {
      const dateStr = e.date.toISOString().split('T')[0]; // YYYY-MM-DD
      if (!dailyMap[dateStr]) {
        dailyMap[dateStr] = { total: 0, count: 0 };
      }
      dailyMap[dateStr].total += e.amount;
      dailyMap[dateStr].count += 1;
    });

    const dailyTrend = Object.entries(dailyMap).map(([dateStr, data]) => ({
      _id: dateStr,
      total: data.total,
      count: data.count
    })).sort((a, b) => a._id.localeCompare(b._id));

    // Calculate totals
    const total = filtered.reduce((sum, e) => sum + e.amount, 0);
    const count = filtered.length;

    res.json({
      month, year,
      total,
      count,
      categoryBreakdown,
      dailyTrend,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/export
const exportExpenses = async (req, res) => {
  try {
    const format = (req.query.format || 'json').toLowerCase();
    const month  = parseInt(req.query.month, 10) || null;
    const year   = parseInt(req.query.year,  10) || null;

    const db = getDb();
    const snapshot = await db.collection('expenses')
      .where('userId', '==', req.user.id)
      .get();

    let expenses = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const expDate = data.date ? data.date.toDate() : new Date();
      expenses.push({
        _id: doc.id,
        ...data,
        date: expDate
      });
    });

    // In-memory filter and sort
    if (month && year && month >= 1 && month <= 12) {
      expenses = expenses.filter(e => e.date.getMonth() + 1 === month && e.date.getFullYear() === year);
    }
    expenses.sort((a, b) => b.date - a.date);

    if (format === 'csv') {
      const CSV_HEADERS = 'Date,Payee,Amount,Category,UPIApp,Note,UPIRef';

      const escapeCSV = (val) => {
        if (val === undefined || val === null) return '';
        const str = String(val);
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
          return `"${str.replace(/"/g, '""')}"`;
        }
        return str;
      };

      const rows = expenses.map((e) => [
        escapeCSV(e.date ? e.date.toISOString().split('T')[0] : ''),
        escapeCSV(e.payee),
        escapeCSV(e.amount),
        escapeCSV(e.category),
        escapeCSV(e.upiApp),
        escapeCSV(e.note),
        escapeCSV(e.upiRef),
      ].join(','));

      const csv = [CSV_HEADERS, ...rows].join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=expenses.csv');
      return res.send(csv);
    }

    // Default: JSON
    const formatted = expenses.map(e => ({
      ...e,
      date: e.date.toISOString()
    }));
    res.json(formatted);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/stats/yearly
const getYearlyStats = async (req, res) => {
  try {
    const year = parseInt(req.query.year, 10) || new Date().getFullYear();

    const db = getDb();
    const snapshot = await db.collection('expenses')
      .where('userId', '==', req.user.id)
      .get();

    let expenses = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const expDate = data.date ? data.date.toDate() : new Date();
      expenses.push({
        _id: doc.id,
        ...data,
        date: expDate
      });
    });

    // Filter by year in memory
    const filtered = expenses.filter(e => e.date.getFullYear() === year);

    const monthMap = {};
    filtered.forEach(e => {
      const m = e.date.getMonth() + 1; // 1-12
      if (!monthMap[m]) {
        monthMap[m] = { total: 0, count: 0 };
      }
      monthMap[m].total += e.amount;
      monthMap[m].count += 1;
    });

    const months = Array.from({ length: 12 }, (_, i) => {
      const m = i + 1;
      return {
        month: m,
        total: monthMap[m]?.total || 0,
        count: monthMap[m]?.count || 0,
      };
    });

    res.json({ year, months });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// DELETE /api/expenses/:id
const deleteExpense = async (req, res) => {
  try {
    const db = getDb();
    const docRef = db.collection('expenses').doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data().userId !== req.user.id) {
      return res.status(404).json({ error: 'Expense not found.' });
    }

    await docRef.delete();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/expenses/:id
const ALLOWED_UPDATE_FIELDS = ['amount', 'payee', 'category', 'upiApp', 'note', 'date', 'upiRef'];

const updateExpense = async (req, res) => {
  try {
    const db = getDb();
    const docRef = db.collection('expenses').doc(req.params.id);
    const doc = await docRef.get();

    if (!doc.exists || doc.data().userId !== req.user.id) {
      return res.status(404).json({ error: 'Expense not found.' });
    }

    if (req.body.amount !== undefined) {
      const amt = Number(req.body.amount);
      if (isNaN(amt) || amt <= 0) {
        return res.status(422).json({ error: 'amount must be a positive number.' });
      }
    }

    if (req.body.payee !== undefined) {
      const payeeStr = String(req.body.payee).trim();
      if (!payeeStr) {
        return res.status(422).json({ error: 'payee is required.' });
      }
    }

    if (req.body.upiRef !== undefined && req.body.upiRef !== null) {
      const trimmedRef = String(req.body.upiRef).trim();
      if (trimmedRef) {
        const dupSnapshot = await db.collection('expenses')
          .where('userId', '==', req.user.id)
          .where('upiRef', '==', trimmedRef)
          .limit(2)
          .get();
        const otherDup = dupSnapshot.docs.find(d => d.id !== req.params.id);
        if (otherDup) {
          return res.status(400).json({ error: 'Transaction with this UPI reference already exists.' });
        }
      }
    }

    const update = {};
    for (const field of ALLOWED_UPDATE_FIELDS) {
      if (req.body[field] !== undefined) {
        if (field === 'date') {
          update[field] = admin.firestore.Timestamp.fromDate(new Date(req.body[field]));
        } else {
          update[field] = req.body[field];
        }
      }
    }

    if (Object.keys(update).length === 0)
      return res.status(422).json({ error: 'No valid fields provided for update.' });

    await docRef.update(update);

    const updatedDoc = await docRef.get();
    const data = updatedDoc.data();
    const expDate = data.date ? data.date.toDate() : new Date();

    res.json({
      _id: updatedDoc.id,
      ...data,
      date: expDate.toISOString()
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/months
const getTrackedMonths = async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db.collection('expenses')
      .where('userId', '==', req.user.id)
      .get();

    const monthsMap = {};
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.date) {
        const date = data.date.toDate();
        const key = `${date.getFullYear()}-${date.getMonth() + 1}`;
        monthsMap[key] = { month: date.getMonth() + 1, year: date.getFullYear() };
      }
    });

    // Always include the current month/year
    const now = new Date();
    const currentKey = `${now.getFullYear()}-${now.getMonth() + 1}`;
    monthsMap[currentKey] = { month: now.getMonth() + 1, year: now.getFullYear() };

    const result = Object.values(monthsMap).sort((a, b) => {
      if (a.year !== b.year) return b.year - a.year;
      return b.month - a.month;
    });

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = {
  createExpense,
  getExpenses,
  getMonthlySummary,
  exportExpenses,
  getYearlyStats,
  deleteExpense,
  updateExpense,
  getTrackedMonths,
};
