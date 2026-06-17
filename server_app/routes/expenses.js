const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  createExpense,
  getExpenses,
  getMonthlySummary,
  exportExpenses,
  getYearlyStats,
  deleteExpense,
  updateExpense,
} = require('../controllers/expenseController');

router.use(protect); // All expense routes require auth

router.route('/')
  .post(createExpense)
  .get(getExpenses);

router.get('/summary',      getMonthlySummary);
router.get('/export',       exportExpenses);     // BEFORE /:id
router.get('/stats/yearly', getYearlyStats);     // BEFORE /:id

router.route('/:id')
  .patch(updateExpense)
  .delete(deleteExpense);

module.exports = router;
