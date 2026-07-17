import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _auth     = AuthService();

  bool _loading       = false;
  bool _showPassword  = false;
  String? _error;

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.visitgondar.app://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null && mounted) {
          Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (_) => false,
          );
        }
      });
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Try email instead.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.signIn(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _backButton(context),
                const SizedBox(height: 32),

                const Text('Welcome\nback 👋',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                        color: AppColors.charcoal, height: 1.2,
                        letterSpacing: -0.6)),
                const SizedBox(height: 8),
                const Text('Sign in to your Visit Gondar account',
                    style: TextStyle(fontSize: 15,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 36),

                if (_error != null) ...[
                  _errorBanner(_error!),
                  const SizedBox(height: 20),
                ],

                _label('Email address'),
                const SizedBox(height: 8),
                _field(
                  controller: _email,
                  hint: 'you@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _label('Password'),
                const SizedBox(height: 8),
                _field(
                  controller: _password,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted, size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Forgot password?',
                        style: TextStyle(color: AppColors.goldDark,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('Sign in',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 22),

                Row(children: [
                  Expanded(child: Container(height: 1,
                      color: AppColors.surfaceVariant)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or continue with',
                        style: TextStyle(color: AppColors.textMuted,
                            fontSize: 13)),
                  ),
                  Expanded(child: Container(height: 1,
                      color: AppColors.surfaceVariant)),
                ]),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 54,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.charcoal,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.surfaceVariant),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Image.network('https://www.google.com/favicon.ico',
                          width: 20, height: 20,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.login, size: 20,
                              color: AppColors.textMuted)),
                      const SizedBox(width: 12),
                      const Text('Continue with Google',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal)),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: AppColors.textSecondary,
                            fontSize: 14),
                        children: [
                          TextSpan(text: 'Sign up',
                              style: TextStyle(color: AppColors.goldDark,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary,
          fontWeight: FontWeight.w700, fontSize: 13));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.charcoal, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

// ── Shared light-theme helpers for auth screens ──────────────
Widget _backButton(BuildContext context) => GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.surfaceVariant),
    ),
    child: const Icon(Icons.arrow_back,
        color: AppColors.charcoal, size: 20),
  ),
);

Widget _errorBanner(String msg) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: AppColors.errorLight,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.error.withAlpha(60)),
  ),
  child: Row(children: [
    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
    const SizedBox(width: 10),
    Expanded(child: Text(msg,
        style: const TextStyle(color: AppColors.error, fontSize: 13))),
  ]),
);
