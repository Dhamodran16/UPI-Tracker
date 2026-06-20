import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _auth = FirebaseAuth.instance;

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _emailOrPhone = TextEditingController();

  // Register form
  final _regFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rEmail = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _tabs.dispose();
    _emailOrPhone.dispose();
    _name.dispose();
    _rEmail.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout)
        return 'Connection timed out. Check your network.';
      if (e.type == DioExceptionType.connectionError)
        return 'Cannot reach server. Check your network.';
      return 'Server error (${e.response?.statusCode ?? "no response"})';
    }
    return e.toString();
  }



  Future<void> _verifyFirebaseTokenOnBackend(String idToken, {String? name, String? email}) async {
    try {
      final res = await ApiService().verifyFirebaseToken(idToken, name: name, email: email);
      if (res['newUser'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Please fill out name and email to register.')),
          );
          _tabs.animateTo(1);
          if (res['phone'] != null) {
            _phone.text = res['phone'] as String;
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e))),
        );
      }
    }
  }

  Future<void> _showFirebaseOtpDialog(String verificationId, String phone, {String? name, String? email}) async {
    final otpCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool verLoading = false;
    String? verError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter SMS OTP'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter the 6-digit code sent to $phone',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otpCtrl,
                      style: const TextStyle(fontSize: 16),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'SMS Verification Code',
                        prefixIcon: const Icon(Icons.lock_open_outlined),
                        errorText: verError,
                        counterText: '',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length != 6)
                              ? 'Enter a 6-digit OTP'
                              : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: verLoading
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setState(() {
                            verLoading = true;
                            verError = null;
                          });
                          try {
                            final credential = PhoneAuthProvider.credential(
                              verificationId: verificationId,
                              smsCode: otpCtrl.text.trim(),
                            );
                            final userCredential = await _auth.signInWithCredential(credential);
                            final idToken = await userCredential.user?.getIdToken();
                            if (idToken != null) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _verifyFirebaseTokenOnBackend(idToken, name: name, email: email);
                            } else {
                              throw Exception('Failed to retrieve Firebase ID Token.');
                            }
                          } catch (e) {
                            setState(() {
                              verLoading = false;
                              verError = e is FirebaseAuthException
                                  ? e.message
                                  : e.toString();
                            });
                          }
                        },
                  child: verLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
    otpCtrl.dispose();
  }

  Future<void> _startFirebasePhoneAuth(String phone, {String? name, String? email}) async {
    setState(() => _loading = true);
    String formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$formattedPhone';
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            final idToken = await userCredential.user?.getIdToken();
            if (idToken != null) {
              await _verifyFirebaseTokenOnBackend(idToken, name: name, email: email);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auto-verification failed: ${_parseError(e)}')),
              );
            }
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Phone verification failed: ${e.message ?? e.code}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _loading = false);
            _showFirebaseOtpDialog(verificationId, formattedPhone, name: name, email: email);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _loading = false);
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase Auth Error: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final identifier = _emailOrPhone.text.trim();
    await _startFirebasePhoneAuth(identifier);
  }

  Future<void> _register() async {
    if (!_regFormKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final email = _rEmail.text.trim();
    final phone = _phone.text.trim();
    await _startFirebasePhoneAuth(phone, name: name, email: email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 40, color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('UPI Tracker',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Track every rupee automatically',
                    style:
                        TextStyle(fontSize: 16, color: Color(0xFF888780))),
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

                Expanded(
                    child: TabBarView(controller: _tabs, children: [
                  // ── Login tab ─────────────────────────────────
                  SingleChildScrollView(
                      child: Form(
                          key: _loginFormKey,
                          child: Column(children: [
                            TextFormField(
                              controller: _emailOrPhone,
                              style: const TextStyle(fontSize: 16),
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Mobile number is required';
                                final val = v.trim();
                                if (val.length < 10 ||
                                    !RegExp(r'^\+?[0-9]+$').hasMatch(val)) {
                                  return 'Enter a valid mobile number (at least 10 digits)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            // hint for phone users
                            const Text(
                              'OTP will be sent via Firebase SMS',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF888780)),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Login'),
                            ),
                          ]))),

                  // ── Register tab ─────────────────────────────
                  SingleChildScrollView(
                      child: Form(
                          key: _regFormKey,
                          child: Column(children: [
                            TextFormField(
                              controller: _name,
                              style: const TextStyle(fontSize: 16),
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outlined)),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _rEmail,
                              style: const TextStyle(fontSize: 16),
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined)),
                              validator: (v) =>
                                  (v == null ||
                                          !v.contains('@') ||
                                          !v.contains('.'))
                                      ? 'Enter a valid email'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phone,
                              style: const TextStyle(fontSize: 16),
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Mobile Number',
                                  prefixIcon: Icon(Icons.phone_outlined)),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Mobile number is mandatory';
                                final val = v.trim();
                                if (val.length < 10 ||
                                    !RegExp(r'^\+?[0-9]+$').hasMatch(val)) {
                                  return 'Enter a valid mobile number (at least 10 digits)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loading ? null : _register,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
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
