import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final _api = ApiService();

  List<Expense>   expenses       = [];
  MonthlySummary? summary;
  bool            loading        = false;
  String?         error;
  int             selectedMonth  = DateTime.now().month;
  int             selectedYear   = DateTime.now().year;
  String          filterCategory = 'All';
  String          sortBy         = 'date';

  // ── Global tab index (fixes #5 - "See all" navigation) ──────────────────────
  int currentTab = 0;
  void setTab(int t) { currentTab = t; notifyListeners(); }

  // ── Theme mode ─────────────────────────────────────────────────────────────
  ThemeMode themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  // ── Notification Alerts ───────────────────────────────────────────────────
  bool enableNotifications = true;

  void setEnableNotifications(bool val) async {
    enableNotifications = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_notifications', val);
    notifyListeners();
  }

  // ── Current user profile ───────────────────────────────────────────────────
  Map<String, dynamic>? currentUser;

  Future<String?> updateUserProfile(String name, String phone) async {
    try {
      final res = await _api.updateProfile(name: name, phone: phone);
      currentUser = res['user'] as Map<String, dynamic>?;
      if (currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user', jsonEncode(currentUser));
      }
      notifyListeners();
      return null;
    } on Exception catch (e) {
      return _friendlyError(e);
    }
  }

  // ── Persisted budgets (#13) ──────────────────────────────────────────────────
  Map<String, double> budgets = {
    'Food & Dining': 3000.0,
    'Transport':     1500.0,
    'Grocery':       2500.0,
    'Bills':         2000.0,
    'Health':        1000.0,
    'Shopping':      2000.0,
  };

  // ── Persisted savings goals (#14) ──────────────────────────────────────────
  List<SavingsGoal> goals = [];

  ExpenseProvider() { _loadPersistedData(); }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load budgets
    final budgetJson = prefs.getString('budgets');
    if (budgetJson != null) {
      final decoded = jsonDecode(budgetJson) as Map<String, dynamic>;
      budgets = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    // Load goals
    final goalsJson = prefs.getString('savings_goals');
    if (goalsJson != null) {
      final list = jsonDecode(goalsJson) as List;
      goals = list.map((g) => SavingsGoal.fromJson(g as Map<String, dynamic>)).toList();
    } else {
      goals = [SavingsGoal(name: 'Emergency fund', target: 50000, saved: 0)];
      await _saveGoals();
    }

    // Load theme mode
    final themeStr = prefs.getString('theme_mode');
    if (themeStr != null) {
      themeMode = ThemeMode.values.firstWhere((e) => e.name == themeStr, orElse: () => ThemeMode.system);
    }

    // Load notification alert preference
    enableNotifications = prefs.getBool('enable_notifications') ?? true;

    // Load cached user profile
    final userJson = prefs.getString('cached_user');
    if (userJson != null) {
      currentUser = jsonDecode(userJson) as Map<String, dynamic>?;
    }

    notifyListeners();
  }

  Future<void> setBudget(String category, double amount) async {
    budgets[category] = amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('budgets', jsonEncode(budgets));
    notifyListeners();
  }

  Future<void> addGoal(String name, double target) async {
    goals.add(SavingsGoal(name: name, target: target, saved: 0));
    await _saveGoals();
    notifyListeners();
  }

  Future<void> updateGoalSaved(int index, double amount) async {
    final current = goals[index].saved;
    goals[index] = goals[index].copyWith(saved: (current + amount).clamp(0, goals[index].target));
    await _saveGoals();
    notifyListeners();
  }

  Future<void> removeGoal(int index) async {
    goals.removeAt(index);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savings_goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  // ── Computed ────────────────────────────────────────────────────────────────
  // NOTE: search is now local state in TransactionsScreen (#10 fix)
  List<Expense> get filtered {
    var list = expenses.where((e) =>
      e.date.month == selectedMonth && e.date.year == selectedYear
    ).toList();
    if (filterCategory != 'All') list = list.where((e) => e.category == filterCategory).toList();
    switch (sortBy) {
      case 'amount': list.sort((a, b) => b.amount.compareTo(a.amount)); break;
      case 'payee':  list.sort((a, b) => a.name.compareTo(b.name));     break;
      default:       list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  // All expenses for the selected month (unfiltered by category) for home screen
  List<Expense> get monthExpenses => expenses.where((e) =>
    e.date.month == selectedMonth && e.date.year == selectedYear
  ).toList();

  double get monthTotal => monthExpenses.fold(0, (s, e) => s + e.amount);
  double get todayTotal {
    final now = DateTime.now();
    return expenses.where((e) =>
      e.date.day == now.day && e.date.month == now.month && e.date.year == now.year
    ).fold(0, (s, e) => s + e.amount);
  }

  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    for (final e in monthExpenses) map[e.category] = (map[e.category] ?? 0) + e.amount;
    return map..removeWhere((_, v) => v == 0);
  }

  Map<String, double> get appTotals {
    final map = <String, double>{};
    for (final e in monthExpenses) map[e.upiApp] = (map[e.upiApp] ?? 0) + e.amount;
    return map;
  }

  Map<String, double> get merchantTotals {
    final map = <String, double>{};
    for (final e in monthExpenses) map[e.name] = (map[e.name] ?? 0) + e.amount;
    final sorted = Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return Map.fromEntries(sorted.entries.take(5));
  }

  List<double> get weekdayTotals {
    // dart weekday: 1=Mon..7=Sun  =>  map to 0=Sun..6=Sat
    final totals = List<double>.filled(7, 0);
    for (final e in monthExpenses) {
      final wd = e.date.weekday % 7; // Sun→0, Mon→1 … Sat→6
      totals[wd] += e.amount;
    }
    return totals;
  }

  // #9 fix — correct peak day using index-aware reduce
  int get peakDayIndex {
    final t = weekdayTotals;
    if (t.every((v) => v == 0)) return -1;
    int best = 0;
    for (int i = 1; i < t.length; i++) { if (t[i] > t[best]) best = i; }
    return best;
  }

  Expense? get maxExpense => monthExpenses.isEmpty ? null
      : monthExpenses.reduce((a, b) => a.amount > b.amount ? a : b);

  int get uniqueApps => monthExpenses.map((e) => e.upiApp).toSet().length;
  String get topApp {
    if (appTotals.isEmpty) return '—';
    return appTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  void setMonth(int month, int year) { selectedMonth = month; selectedYear = year; load(); }
  void setFilter(String cat) { filterCategory = cat; notifyListeners(); }
  void setSort(String s)     { sortBy = s;           notifyListeners(); }

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      expenses = await _api.getExpenses(month: selectedMonth, year: selectedYear, limit: 500);
      try {
        final profile = await _api.getMe();
        currentUser = profile['user'] as Map<String, dynamic>?;
        if (currentUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user', jsonEncode(currentUser));
        }
      } catch (_) {}
    } catch (e) {
      error = _friendlyError(e as Exception);
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<String?> addExpense(Expense e) async {
    try {
      final saved = await _api.createExpense(e);
      expenses.insert(0, saved);
      notifyListeners();
      return null;
    } on Exception catch (e) {
      final msg = _friendlyError(e);
      error = msg; notifyListeners();
      return msg;
    }
  }

  Future<String?> updateExpense(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _api.updateExpense(id, data);
      final idx = expenses.indexWhere((e) => e.id == id);
      if (idx >= 0) expenses[idx] = updated;
      notifyListeners();
      return null;
    } on Exception catch (e) {
      final msg = _friendlyError(e);
      error = msg; notifyListeners();
      return msg;
    }
  }

  Future<String?> deleteExpense(String id) async {
    final idx = expenses.indexWhere((e) => e.id == id);
    final removed = idx >= 0 ? expenses[idx] : null;
    if (idx >= 0) { expenses.removeAt(idx); notifyListeners(); }
    try {
      await _api.deleteExpense(id);
      return null;
    } on Exception catch (e) {
      if (idx >= 0 && removed != null) expenses.insert(idx, removed);
      final msg = _friendlyError(e);
      error = msg; notifyListeners();
      return msg;
    }
  }

  String _friendlyError(Exception e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection refused')) return 'Cannot reach server. Check your network.';
    if (s.contains('401')) return 'Session expired. Please log in again.';
    if (s.contains('422')) return 'Invalid data. Please check your input.';
    if (s.contains('500')) return 'Server error. Please try again later.';
    return s.replaceFirst('Exception: ', '');
  }

  void initNotificationListener() {
    NotificationService.onExpense = (data) {
      final e = Expense(
        name:     data['payee']    as String? ?? 'Unknown',
        amount:   (data['amount'] as num).toDouble(),
        category: data['category'] as String? ?? 'Other',
        upiApp:   data['upiApp']   as String? ?? 'GPay',
        upiRef:   data['upiRef']   as String?,
        date:     DateTime.now(),
      );
      addExpense(e);
    };
  }
}
