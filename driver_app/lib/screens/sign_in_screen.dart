import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/driver_api.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  Sign in / create a driver account (email + password, the same
//  Supabase accounts as the tourist app).
// ═══════════════════════════════════════════════════════════════
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false, _busy = false, _hide = true;
  String? _error, _info;

  @override
  void dispose() {
    _name.dispose();
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
    final auth = Supabase.instance.client.auth;
    final email = _email.text.trim();
    try {
      if (_create) {
        final res = await auth.signUp(
          email: email,
          password: _password.text,
          data: {'full_name': _name.text.trim()},
        );
        if (res.session == null && mounted) {
          // The project asks new accounts to confirm their email first.
          setState(() {
            _create = false;
            _info = 'We sent a link to $email. Open it, then sign in here.';
          });
        }
      } else {
        await auth.signInWithPassword(email: email, password: _password.text);
      }
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
                  const SizedBox(height: 28),
                  FadeIn(
                    delay: 200,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login_rounded)),
                        ButtonSegment(value: true, label: Text('New driver'), icon: Icon(Icons.person_add_alt_1_rounded)),
                      ],
                      selected: {_create},
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: VG.brown,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onSelectionChanged: (s) => setState(() {
                        _create = s.first;
                        _error = null;
                        _info = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _create
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (v) => _create && (v ?? '').trim().length < 2
                                  ? 'Type your full name'
                                  : null,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
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
                  if (!_create)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                    )
                  else
                    const SizedBox(height: 14),
                  if (_error != null) _Note(text: _error!, color: VG.danger, icon: Icons.error_outline_rounded),
                  if (_info != null) _Note(text: _info!, color: VG.online, icon: Icons.mark_email_read_outlined),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(_create ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Already use the Visit Gondar app? Sign in with the same account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VG.muted, fontSize: 13.5),
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
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}
