import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  WELCOME — clean light landing: choose language, then create an
//  account or sign in. One consistent look with the rest of the app.
// ═══════════════════════════════════════════════════════════════
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 12),

            // ── Hero image ──
            Expanded(
              child: Center(
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.gold.withAlpha(40),
                        AppColors.gold.withAlpha(0),
                      ]),
                    ),
                  ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [BoxShadow(
                            color: AppColors.charcoal.withAlpha(30),
                            blurRadius: 30, offset: const Offset(0, 16))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: appImage(AppConstants.onboardingCover),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            // ── Title ──
            Text(am ? 'እንኳን ወደ\nጎንደር መጡ' : 'Welcome to\nGondar',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34,
                    fontWeight: FontWeight.w900, height: 1.15,
                    color: AppColors.charcoal, letterSpacing: -0.8)),
            const SizedBox(height: 10),
            Text(am ? 'የአፍሪካዋ ካሜሎት የኪስ መመሪያዎ'
                    : 'Your pocket guide to the Camelot of Africa',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15,
                    color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 22),

            // ── Language pill ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _langButton('English', 'en'),
                _langButton('አማርኛ', 'am'),
              ]),
            ),
            const SizedBox(height: 18),

            // ── Create account ──
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(am ? 'መለያ ይፍጠሩ' : 'Create account',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sign in ──
            SizedBox(
              width: double.infinity, height: 54,
              child: OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  side: const BorderSide(
                      color: AppColors.surfaceVariant, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(am ? 'ይግቡ' : 'Sign in',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),

            Text(am
                    ? 'ስሪት 1.4 · ብርቱካንማ መልክ'
                    : 'Version 1.4 · Burnt Orange',
                style: const TextStyle(fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
          ]),
        ),
      ),
    );
  }

  Widget _langButton(String label, String code) {
    final bool isSelected = ref.watch(languageProvider) == code;
    return GestureDetector(
      onTap: () {
        if (!isSelected) ref.read(languageProvider.notifier).toggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textMuted)),
      ),
    );
  }
}
