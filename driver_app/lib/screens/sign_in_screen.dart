import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/driver_api.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  Sign in only — no "create account" here. For security, driver
//  accounts are made by the Visit Gondar office in person (they
//  check your ID and vehicle documents), who then give you the
//  email and password to sign in with.
// ═══════════════════════════════════════════════════════════════
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Signed in: the AuthGate moves on by itself.
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?".');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() => _info = 'Password reset link sent to $email.');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const FadeIn(child: Center(child: BrandBadge(icon: Icons.electric_rickshaw_rounded))),
                  const SizedBox(height: 22),
                  const FadeIn(
                    delay: 80,
                    child: Text('Visit Gondar Driver',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: VG.ink)),
                  ),
                  const SizedBox(height: 8),
                  const FadeIn(
                    delay: 140,
                    child: Text(
                      'Drive visitors around Gondar.\nRide requests come straight to your phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15.5, height: 1.4, color: VG.muted),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().contains('@') ? null : 'Type a valid email',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                  ),
                  if (_error != null) _Note(text: _error!, color: VG.danger, icon: Icons.error_outline_rounded),
                  if (_info != null) _Note(text: _info!, color: VG.online, icon: Icons.mark_email_read_outlined),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 22),
                  const _Note(
                    text: 'New driver? Visit the Visit Gondar office with your ID and vehicle '
                        'documents. The office sets up your account and gives you an email '
                        'and password to sign in with here.',
                    color: VG.muted,
                    icon: Icons.storefront_outlined,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _Note({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}
