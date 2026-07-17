import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _auth  = AuthService();
  bool _loading = false;
  bool _sent    = false;
  String? _error;

  Future<void> _send() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.resetPassword(_email.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = 'Could not send reset email. Try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox(
        width: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                GestureDetector(
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
                ),
                const SizedBox(height: 40),

                if (!_sent) ...[
                  const Text('Forgot\npassword? 🔑',
                      style: TextStyle(fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal, height: 1.2)),
                  const SizedBox(height: 8),
                  const Text(
                      'Enter your email and we\'ll send you a reset link.',
                      style: TextStyle(fontSize: 15,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 40),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text('Email address',
                      style: TextStyle(color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppColors.textMuted, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.gold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.goldDeep,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.goldDeep))
                          : const Text('Send reset link',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  // Success state
                  const Spacer(),
                  Center(
                    child: Column(children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            color: AppColors.gold, size: 44),
                      ),
                      const SizedBox(height: 24),
                      const Text('Check your email!',
                          style: TextStyle(fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal)),
                      const SizedBox(height: 12),
                      Text(
                          'We sent a reset link to\n${_email.text.trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15,
                              color: AppColors.textSecondary, height: 1.5)),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.goldDeep,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Back to Sign in',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                      ),
                    ]),
                  ),
                  const Spacer(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
