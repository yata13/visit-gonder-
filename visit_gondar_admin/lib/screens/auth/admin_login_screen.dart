import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_supabase.dart';
import '../dashboard/admin_shell.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _loading      = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AdminSupabase.signIn(
          _email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminShell()));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Login failed. Check your credentials.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(children: [
        // ── LEFT PANEL — brand ──────────────────────────
        Expanded(
          child: Container(
            color: AdminColors.bronze,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AdminColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.location_city,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('Visit Gondar',
                    style: TextStyle(fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Admin Dashboard',
                    style: TextStyle(fontSize: 16,
                        color: Colors.white54,
                        letterSpacing: 2)),
                const SizedBox(height: 60),

                // Stats preview
                _statRow(Icons.hotel, '7 Hotels'),
                const SizedBox(height: 12),
                _statRow(Icons.person_pin, '4 Licensed Guides'),
                const SizedBox(height: 12),
                _statRow(Icons.account_balance, '5 Historic Sites'),
                const SizedBox(height: 12),
                _statRow(Icons.celebration, 'Timket 2027 Ready'),
              ],
            ),
          ),
        ),

        // ── RIGHT PANEL — login form ─────────────────────
        Container(
          width: 480,
          color: AdminColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back',
                    style: TextStyle(fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Sign in to manage Visit Gondar',
                    style: TextStyle(fontSize: 14,
                        color: AdminColors.textMuted)),
                const SizedBox(height: 40),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminColors.error.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AdminColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(
                              color: AdminColors.error,
                              fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Email
                const Text('Email',
                    style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AdminColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'admin@visitgondar.com',
                    prefixIcon: Icon(Icons.email_outlined,
                        size: 18, color: AdminColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your email' : null,
                ),
                const SizedBox(height: 20),

                // Password
                const Text('Password',
                    style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AdminColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline,
                        size: 18, color: AdminColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18, color: AdminColors.textMuted,
                      ),
                      onPressed: () => setState(
                          () => _showPassword = !_showPassword),
                    ),
                  ),
                  onFieldSubmitted: (_) => _login(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your password' : null,
                ),
                const SizedBox(height: 32),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : const Text('Sign in to dashboard',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),

                // Security note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined,
                        size: 16, color: AdminColors.gold),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a secure admin area. Access is restricted to authorized personnel only.',
                        style: TextStyle(fontSize: 12,
                            color: AdminColors.textSecondary,
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statRow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AdminColors.gold, size: 18),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(
          color: Colors.white70, fontSize: 14)),
    ],
  );
}
