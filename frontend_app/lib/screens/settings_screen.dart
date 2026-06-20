import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/expense_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController();
  late final _emailCtrl = TextEditingController();
  late final _phoneCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _listenerPermission = false;
  bool _fieldsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initFields();
    _checkPermission();
  }

  void _initFields() {
    final user = context.read<ExpenseProvider>().currentUser;
    if (user != null) {
      _nameCtrl.text = user['name']?.toString() ?? '';
      _emailCtrl.text = user['email']?.toString() ?? '';
      _phoneCtrl.text = user['phone']?.toString() ?? '';
      _fieldsInitialized = true;
    }
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService.isPermissionGranted();
    setState(() => _listenerPermission = granted);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);

    final err = await context.read<ExpenseProvider>().updateUserProfile(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _savingProfile = false);
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully ✔')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _exportData(String format) {
    final p = context.read<ExpenseProvider>();
    final url = ApiService().exportCsvUrl(
      month: p.selectedMonth,
      year: p.selectedYear,
    );
    final finalUrl = format == 'json' ? url.replaceAll('format=csv', 'format=json') : url;

    Clipboard.setData(ClipboardData(text: finalUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export URL ($format) copied to clipboard!')),
    );
  }

  Future<void> _showDiagnosticsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString('debug_logs') ?? '[]';
    List<dynamic> logs = [];
    try {
      logs = jsonDecode(logsJson) as List<dynamic>;
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Service Diagnostics'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs captured yet.\nMake sure notification access is enabled and transactions occur.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (c, i) {
                      final log = logs[logs.length - 1 - i]; // Show newest first
                      final ts = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
                      final timeStr =
                          "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}";
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '[$timeStr] ${log['message']}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.remove('debug_logs');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear Logs', style: TextStyle(color: AppTheme.danger)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ApiService().logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final user = p.currentUser;

    if (user != null && !_fieldsInitialized) {
      _nameCtrl.text = user['name']?.toString() ?? '';
      _emailCtrl.text = user['email']?.toString() ?? '';
      _phoneCtrl.text = user['phone']?.toString() ?? '';
      _fieldsInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── USER PROFILE SECTION ───────────────────────────────────────────
          _sectionTitle('PROFILE INFORMATION'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: user == null
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _profileFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number (Mandatory)',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Mobile number is mandatory';
                              }
                              if (v.trim().length < 10 || !RegExp(r'^\+?[0-9]+$').hasMatch(v.trim())) {
                                return 'Enter a valid 10-digit number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _savingProfile ? null : _updateProfile,
                            child: _savingProfile
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Profile Changes'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── APP PREFERENCES SECTION ────────────────────────────────────────
          _sectionTitle('APP PREFERENCES'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, color: AppTheme.primary),
                      const SizedBox(width: 14),
                      const Text('App Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      DropdownButton<ThemeMode>(
                        value: p.themeMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                        ],
                        onChanged: (v) {
                          if (v != null) p.setThemeMode(v);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppTheme.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transaction Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('Notify on auto-tracked transactions', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Switch(
                        value: p.enableNotifications,
                        onChanged: (v) => p.setEnableNotifications(v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── AUTO TRACKING STATUS ───────────────────────────────────────────
          _sectionTitle('SMS AUTO-TRACKING'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _listenerPermission ? Icons.check_circle_outline : Icons.error_outline,
                        color: _listenerPermission ? AppTheme.success : AppTheme.warning,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notification Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(
                              _listenerPermission ? 'Auto-tracking running' : 'Disabled — click to enable',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await NotificationService.openNotificationSettings();
                          Future.delayed(const Duration(seconds: 1), _checkPermission);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Settings'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.bug_report_outlined, color: AppTheme.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Diagnostic Logs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('View background tracking events & issues', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _showDiagnosticsDialog(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('View Logs'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── EXPORT DATA SECTION ────────────────────────────────────────────
          _sectionTitle('EXPORT YOUR DATA'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportData('csv'),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportData('json'),
                      icon: const Icon(Icons.code_outlined, size: 16),
                      label: const Text('Export JSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ── LOGOUT BUTTON ──────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.8),
        ),
      );
}
