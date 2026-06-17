const Expense = require('../models/Expense');

// POST /api/expenses
const createExpense = async (req, res) => {
  try {
    const { amount, payee, category, upiApp, upiRef, note, date } = req.body;

    if (!amount || isNaN(amount) || Number(amount) <= 0)
      return res.status(422).json({ error: 'amount must be a positive number.' });
    if (!payee || !String(payee).trim())
      return res.status(422).json({ error: 'payee is required.' });

    const expense = await Expense.create({
      userId: req.user._id,
      amount: Number(amount),
      payee:  String(payee).trim(),
      category, upiApp, upiRef, note,
      date: date || new Date(),
    });

    res.status(201).json(expense);
  } catch (err) {
    if (err.code === 11000) {
      return res.status(200).json({ duplicate: true, message: 'Transaction already logged.' });
    }
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses?page=1&limit=20&month=6&year=2026&category=Food
const getExpenses = async (req, res) => {
  try {
    const page     = Math.max(1, parseInt(req.query.page,  10) || 1);
    const limit    = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const month    = parseInt(req.query.month, 10) || null;
    const year     = parseInt(req.query.year,  10) || null;
    const category = req.query.category || null;

    const filter = { userId: req.user._id };

    if (month && year && month >= 1 && month <= 12) {
      filter.date = {
        $gte: new Date(year, month - 1, 1),
        $lt:  new Date(year, month, 1),
      };
    }
    if (category) filter.category = category;

    const total    = await Expense.countDocuments(filter);
    const expenses = await Expense.find(filter)
      .sort({ date: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    res.json({
      expenses,
      pagination: { total, page, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/summary?month=6&year=2026
const getMonthlySummary = async (req, res) => {
  try {
    const month = Math.min(12, Math.max(1, parseInt(req.query.month, 10) || new Date().getMonth() + 1));
    const year  = parseInt(req.query.year, 10) || new Date().getFullYear();

    const start = new Date(year, month - 1, 1);
    const end   = new Date(year, month, 1);

    const [categoryBreakdown, dailyTrend, totals] = await Promise.all([
      Expense.aggregate([
        { $match: { userId: req.user._id, date: { $gte: start, $lt: end } } },
        { $group: { _id: '$category', total: { $sum: '$amount' }, count: { $sum: 1 } } },
        { $sort: { total: -1 } },
      ]),
      Expense.aggregate([
        { $match: { userId: req.user._id, date: { $gte: start, $lt: end } } },
        { $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
          total: { $sum: '$amount' },
          count: { $sum: 1 },
        }},
        { $sort: { _id: 1 } },
      ]),
      Expense.aggregate([
        { $match: { userId: req.user._id, date: { $gte: start, $lt: end } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
    ]);

    res.json({
      month, year,
      total: totals[0]?.total || 0,
      count: totals[0]?.count || 0,
      categoryBreakdown,
      dailyTrend,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/export?month=6&year=2026&format=json|csv
const exportExpenses = async (req, res) => {
  try {
    const format = (req.query.format || 'json').toLowerCase();
    const month  = parseInt(req.query.month, 10) || null;
    const year   = parseInt(req.query.year,  10) || null;

    const filter = { userId: req.user._id };

    if (month && year && month >= 1 && month <= 12) {
      filter.date = {
        $gte: new Date(year, month - 1, 1),
        $lt:  new Date(year, month, 1),
      };
    }

    const expenses = await Expense.find(filter).sort({ date: -1 }).lean();

    if (format === 'csv') {
      const CSV_HEADERS = 'Date,Payee,Amount,Category,UPIApp,Note,UPIRef';

      const escapeCSV = (val) => {
        if (val === undefined || val === null) return '';
        const str = String(val);
        // Wrap in quotes if the value contains commas, quotes, or newlines
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
          return `"${str.replace(/"/g, '""')}"`;
        }
        return str;
      };

      const rows = expenses.map((e) => [
        escapeCSV(e.date ? new Date(e.date).toISOString().split('T')[0] : ''),
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
    res.json(expenses);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/expenses/stats/yearly?year=2026
const getYearlyStats = async (req, res) => {
  try {
    const year = parseInt(req.query.year, 10) || new Date().getFullYear();

    const start = new Date(year, 0, 1);   // Jan 1
    const end   = new Date(year + 1, 0, 1); // Jan 1 next year

    const rows = await Expense.aggregate([
      { $match: { userId: req.user._id, date: { $gte: start, $lt: end } } },
      {
        $group: {
          _id:   { $month: '$date' }, // 1–12
          total: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    // Build a full 12-month array, filling 0s for months with no data
    const monthMap = {};
    for (const row of rows) {
      monthMap[row._id] = { total: row.total, count: row.count };
    }

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
    const expense = await Expense.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });
    if (!expense) return res.status(404).json({ error: 'Expense not found.' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// PATCH /api/expenses/:id  — only whitelisted fields allowed
const ALLOWED_UPDATE_FIELDS = ['amount', 'payee', 'category', 'upiApp', 'note', 'date'];

const updateExpense = async (req, res) => {
  try {
    const update = {};
    for (const field of ALLOWED_UPDATE_FIELDS) {
      if (req.body[field] !== undefined) update[field] = req.body[field];
    }
    if (Object.keys(update).length === 0)
      return res.status(422).json({ error: 'No valid fields provided for update.' });

    const expense = await Expense.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { $set: update },
      { new: true, runValidators: true }
    );
    if (!expense) return res.status(404).json({ error: 'Expense not found.' });
    res.json(expense);
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
};
