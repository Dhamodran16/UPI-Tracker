import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';
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
  final _emailOrPhone = TextEditingController();

  // Register form
  final _regFormKey = GlobalKey<FormState>();
  final _name       = TextEditingController();
  final _rEmail     = TextEditingController();
  final _phone      = TextEditingController();

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
          e.type == DioExceptionType.receiveTimeout) return 'Connection timed out. Check your network.';
      if (e.type == DioExceptionType.connectionError) return 'Cannot reach server. Check your network.';
      return 'Server error (${e.response?.statusCode ?? "no response"})';
    }
    return e.toString();
  }

  Future<void> _showOtpDialog(String identifier) async {
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
              title: const Text('Enter OTP'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'We have sent a 6-digit OTP to $identifier',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otpCtrl,
                      style: const TextStyle(fontSize: 16),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: const Icon(Icons.lock_open_outlined),
                        errorText: verError,
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length != 6) ? 'Enter a 6-digit OTP' : null,
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
                            await ApiService().verifyOtp(identifier, otpCtrl.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx); // close dialog
                              Navigator.pushReplacementNamed(context, '/home');
                            }
                          } catch (e) {
                            setState(() {
                              verLoading = false;
                              verError = _parseError(e);
                            });
                          }
                        },
                  child: verLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Future<void> _showFirebaseOtpDialog(String verificationId, String phone) async {
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
                        labelText: 'Verification Code',
                        prefixIcon: const Icon(Icons.lock_open_outlined),
                        errorText: verError,
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length != 6) ? 'Enter a 6-digit OTP' : null,
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
                            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                            final idToken = await userCredential.user?.getIdToken();
                            if (idToken != null) {
                              final res = await ApiService().verifyFirebaseToken(idToken);
                              if (res['newUser'] == true) {
                                Navigator.pop(ctx);
                                await _showNewUserRegistrationDialog(idToken);
                              } else {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx); // close dialog
                                  Navigator.pushReplacementNamed(context, '/home');
                                }
                              }
                            } else {
                              throw Exception('Could not retrieve Firebase ID Token.');
                            }
                          } catch (e) {
                            setState(() {
                              verLoading = false;
                              verError = _parseError(e);
                            });
                          }
                        },
                  child: verLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Future<void> _showNewUserRegistrationDialog(String idToken) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final regFormKey = GlobalKey<FormState>();
    bool regLoading = false;
    String? regError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Complete Profile'),
              content: Form(
                key: regFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please provide your name and email to finish setting up your account.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 16),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      style: const TextStyle(fontSize: 16),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
                    ),
                    if (regError != null) ...[
                      const SizedBox(height: 8),
                      Text(regError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: regLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: regLoading
                      ? null
                      : () async {
                          if (!regFormKey.currentState!.validate()) return;
                          setState(() {
                            regLoading = true;
                            regError = null;
                          });
                          try {
                            await ApiService().verifyFirebaseToken(
                              idToken,
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              Navigator.pushReplacementNamed(context, '/home');
                            }
                          } catch (e) {
                            setState(() {
                              regLoading = false;
                              regError = _parseError(e);
                            });
                          }
                        },
                  child: regLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _loginWithFirebasePhone(String phone) async {
    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      formattedPhone = '+91$phone';
    }

    final auth = FirebaseAuth.instance;
    await auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential = await auth.signInWithCredential(credential);
        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null) {
          final res = await ApiService().verifyFirebaseToken(idToken);
          if (res['newUser'] == true) {
            await _showNewUserRegistrationDialog(idToken);
          } else {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Verification failed')));
      },
      codeSent: (String verificationId, int? resendToken) async {
        await _showFirebaseOtpDialog(verificationId, formattedPhone);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final identifier = _emailOrPhone.text.trim();
    final isEmail = identifier.contains('@');

    if (!isEmail) {
      try {
        await _loginWithFirebasePhone(identifier);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_parseError(e))));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    try {
      final res = await ApiService().login(identifier);
      if (mounted) {
        await _showOtpDialog(identifier);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_parseError(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _name.text.trim();
    final email = _rEmail.text.trim();
    final phone = _phone.text.trim();
    try {
      await ApiService().register(name, email, phone);
      if (mounted) {
        await _showOtpDialog(email);
      }
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
            const Text('UPI Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Track every rupee automatically', style: TextStyle(fontSize: 16, color: Color(0xFF888780))),
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
                  controller: _emailOrPhone,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email or Mobile Number',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email or Mobile number is required';
                    final val = v.trim();
                    if (val.contains('@')) {
                      if (!val.contains('.') || val.length < 5) return 'Enter a valid email';
                    } else {
                      if (val.length < 10 || !RegExp(r'^\+?[0-9]+$').hasMatch(val)) {
                        return 'Enter a valid mobile number (at least 10 digits)';
                      }
                    }
                    return null;
                  },
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
                  controller: _name,
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rEmail,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile number is mandatory';
                    final val = v.trim();
                    if (val.length < 10 || !RegExp(r'^\+?[0-9]+$').hasMatch(val)) {
                      return 'Enter a valid mobile number (at least 10 digits)';
                    }
                    return null;
                  },
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
