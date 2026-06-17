import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _email  = TextEditingController();
  final _pass   = TextEditingController();

  // Register form
  final _regFormKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _rEmail  = TextEditingController();
  final _rPass   = TextEditingController();
  final _rPassC  = TextEditingController();  // #19 confirm password
  final _phone   = TextEditingController();  // #16 phone field

  bool _loading  = false;
  bool _obscure  = true;
  bool _rObscure = true;

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();  _pass.dispose();
    _name.dispose();   _rEmail.dispose();
    _rPass.dispose();  _rPassC.dispose(); _phone.dispose();
    super.dispose();
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) return 'Connection timed out. Check your network.';
      if (e.type == DioExceptionType.connectionError) return 'Cannot reach server. Check your network.';
      return 'Server error (${e.response?.statusCode ?? "no response"})';
    }
    return e.toString();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService().login(_email.text.trim(), _pass.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_parseError(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService().register(
        _name.text.trim(),
        _rEmail.text.trim(),
        _rPass.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),  // #16
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_parseError(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 32),
            const Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text('UPI Tracker', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Track every rupee automatically', style: TextStyle(fontSize: 14, color: Color(0xFF888780))),
            const SizedBox(height: 32),

            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: const Color(0xFF888780),
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
            ),
            const SizedBox(height: 24),

            Expanded(child: TabBarView(controller: _tabs, children: [

              // ── Login tab ─────────────────────────────────
              SingleChildScrollView(child: Form(key: _loginFormKey, child: Column(children: [
                TextFormField(
                  controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass, obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Login'),
                ),
              ]))),

              // ── Register tab ─────────────────────────────
              SingleChildScrollView(child: Form(key: _regFormKey, child: Column(children: [
                TextFormField(
                  controller: _name, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rEmail, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                // #16 — phone field
                TextFormField(
                  controller: _phone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rPass, obscureText: _rObscure,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 chars)',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_rObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _rObscure = !_rObscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 14),
                // #19 — confirm password
                TextFormField(
                  controller: _rPassC, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outlined)),
                  validator: (v) => v != _rPass.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create account'),
                ),
              ]))),
            ])),
          ]),
        ),
      ),
    );
  }
}
