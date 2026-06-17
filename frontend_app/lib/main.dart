import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file bundled as a Flutter asset
  await dotenv.load(fileName: '.env');

  // API_BASE_URL is mandatory — no hardcoded fallback.
  // If missing, fail loudly so the developer fixes .env immediately.
  final apiBaseUrl = dotenv.env['API_BASE_URL'];
  if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
    throw Exception(
      '\n\n[Config] API_BASE_URL is not set in frontend_app/.env\n'
      'Add the line:  API_BASE_URL=http://10.0.2.2:3000  (emulator)\n'
      '              API_BASE_URL=https://api.example.com (production)\n',
    );
  }

  // Persist into SharedPreferences so the Kotlin NotificationListenerService
  // can read the URL at runtime without any hardcoded values.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('api_base_url', apiBaseUrl);

  await NotificationService.init();
  runApp(const UpiTrackerApp());
}

class UpiTrackerApp extends StatelessWidget {
  const UpiTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider()..initNotificationListener(),
      child: MaterialApp(
        title: 'UPI Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _Splash(),
        routes: {
          '/home':  (_) => const MainShell(),
          '/login': (_) => const LoginScreen(),
        },
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final ok = await ApiService().isLoggedIn();
    if (mounted) {
      if (ok) {
        context.read<ExpenseProvider>().load();
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.primary),
      SizedBox(height: 16),
      CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
    ])),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _screens = [
    HomeScreen(),
    TransactionsScreen(),
    AddExpenseScreen(),
    BudgetScreen(),
    InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    return Scaffold(
      body: IndexedStack(index: p.currentTab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: p.currentTab,
          onTap: (i) => context.read<ExpenseProvider>().setTab(i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined),         activeIcon: Icon(Icons.home),         label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined),      activeIcon: Icon(Icons.list_alt),     label: 'Txns'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline),     activeIcon: Icon(Icons.add_circle),   label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.wallet_outlined),        activeIcon: Icon(Icons.wallet),       label: 'Budget'),
            BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline),      activeIcon: Icon(Icons.lightbulb),    label: 'Insights'),
          ],
        ),
      ),
    );
  }
}
