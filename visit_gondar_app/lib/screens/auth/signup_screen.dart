import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../onboarding/welcome_screen.dart';

// Ethiopia first, then common visitor origins, then a broad list.
const _countries = [
  'Ethiopia', 'United States', 'United Kingdom', 'Germany', 'France',
  'Italy', 'Spain', 'Netherlands', 'Canada', 'Australia', 'China',
  'Japan', 'South Korea', 'India', 'United Arab Emirates', 'Saudi Arabia',
  'Israel', 'Kenya', 'Sudan', 'Egypt', 'South Africa', 'Nigeria',
  'Brazil', 'Sweden', 'Norway', 'Switzerland', 'Belgium', 'Austria',
  'Ireland', 'Russia', 'Turkey', 'Other',
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _name      = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();
  final _password  = TextEditingController();
  final _confirm   = TextEditingController();
  final _auth      = AuthService();

  bool _loading      = false;
  bool _showPass     = false;
  bool _showConfirm  = false;
  bool _agreed       = false;
  String? _country;
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
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please agree to the terms to continue');
      return;
    }
    if (_country == null) {
      setState(() => _error = 'Please select your country');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      await _auth.signUp(
        email:    _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
        country:  _country,
        phone:    _phone.text.trim(),
      );
      if (!mounted) return;
      // First sign-up → show the Welcome-to-Gondar screen
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
    _name.dispose(); _email.dispose(); _phone.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.charcoal, size: 20),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text('Create your\naccount ✨',
                      style: TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w700,
                        color: AppColors.charcoal, height: 1.2,
                      )),
                  const SizedBox(height: 8),
                  const Text('Join thousands exploring Gondar',
                      style: TextStyle(fontSize: 15,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 32),

                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Full name
                  _label('Full name'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _name,
                    hint: 'Your full name',
                    icon: Icons.person_outline,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter your full name';
                      if (v.trim().length < 2)
                        return 'Name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _label('Email address'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _email,
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your email';
                      if (!v.contains('@') || !v.contains('.'))
                        return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _label('Phone number'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _phone,
                    hint: '+251 9xx xxx xxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter your phone number';
                      if (v.trim().replaceAll(RegExp(r'[^0-9]'), '').length < 7)
                        return 'Enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Country
                  _label('Country'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _country,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        hint: const Row(children: [
                          Icon(Icons.public, color: AppColors.textMuted, size: 20),
                          SizedBox(width: 12),
                          Text('Select your country',
                              style: TextStyle(color: AppColors.textMuted,
                                  fontSize: 15)),
                        ]),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.textMuted),
                        style: const TextStyle(color: AppColors.charcoal,
                            fontSize: 15),
                        items: _countries.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        )).toList(),
                        onChanged: (v) => setState(() => _country = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _label('Password'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _password,
                    hint: 'Min. 8 characters',
                    icon: Icons.lock_outline,
                    obscure: !_showPass,
                    suffix: _eyeBtn(_showPass,
                        () => setState(() => _showPass = !_showPass)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 8)
                        return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  _label('Confirm password'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _confirm,
                    hint: 'Re-enter your password',
                    icon: Icons.lock_outline,
                    obscure: !_showConfirm,
                    suffix: _eyeBtn(_showConfirm,
                        () => setState(
                            () => _showConfirm = !_showConfirm)),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please confirm your password';
                      if (v != _password.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password strength indicator
                  _PasswordStrength(password: _password.text),
                  const SizedBox(height: 20),

                  // Terms checkbox
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _agreed
                                ? AppColors.gold
                                : Colors.transparent,
                            border: Border.all(
                              color: _agreed
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _agreed
                              ? const Icon(Icons.check,
                                  color: AppColors.goldDeep, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'I agree to the Terms of Service and Privacy Policy. My data is used only to improve my Visit Gondar experience.',
                            style: TextStyle(color: AppColors.textSecondary,
                                fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Sign up button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white))
                          : const Text('Create account',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Container(height: 1, color: AppColors.surfaceVariant)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ),
                    Expanded(child: Container(height: 1, color: AppColors.surfaceVariant)),
                  ]),
                  const SizedBox(height: 20),

                  // Google Sign-Up button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _googleSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.surfaceVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 20, height: 20,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.login, size: 20, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          const Text('Continue with Google',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login link
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen())),
                      child: RichText(
                        text: const TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: AppColors.textSecondary,
                              fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(color: AppColors.gold,
                                  fontWeight: FontWeight.w700),
                            ),
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
      ]),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(color: AppColors.textSecondary,
          fontWeight: FontWeight.w600, fontSize: 13));

  Widget _eyeBtn(bool visible, VoidCallback onTap) => IconButton(
    icon: Icon(
      visible ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
      color: AppColors.textMuted, size: 20,
    ),
    onPressed: onTap,
  );

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
      controller:    controller,
      obscureText:   obscure,
      keyboardType:  keyboardType,
      onChanged: (_) => setState(() {}), // rebuild for strength indicator
      style: const TextStyle(color: AppColors.charcoal, fontSize: 15),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
        filled:     true,
        fillColor:  Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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

// ── Password strength indicator ──────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8)  score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    return score;
  }

  Color get _color => [
    Colors.transparent,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    AppColors.green,
  ][_strength];

  String get _label => [
    '',
    'Weak',
    'Fair',
    'Good',
    'Strong',
  ][_strength];

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(4, (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
          decoration: BoxDecoration(
            color: i < _strength ? _color : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ))),
      const SizedBox(height: 6),
      Text('Password strength: $_label',
          style: TextStyle(fontSize: 11, color: _color,
              fontWeight: FontWeight.w600)),
    ]);
  }
}
