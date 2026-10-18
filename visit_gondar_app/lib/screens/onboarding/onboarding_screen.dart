import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../../widgets/motion.dart';

// ═══════════════════════════════════════════════════════════════
//  WELCOME — create an account, sign in, or browse as a guest.
//  Guests can see sites, maps, listings, weather and SOS (safety
//  is always free); Book, Passport and Ask AI ask them to sign in.
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
    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (_) {}
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterApp();
      });
    }
  }

  void _enterApp() => Navigator.of(context).pushReplacement(
        SmoothPageRoute(builder: (_) => const MainNavigation()),
      );

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 12),
                Reveal(child: Row(children: [
                  const AppMark(size: 40),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(AppConstants.appName,
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                  GlassCircleButton(
                    label: am ? 'EN' : 'አማ',
                    semanticLabel:
                        am ? 'ወደ እንግሊዝኛ ቀይር' : 'Switch to Amharic',
                    onTap: () => ref.read(languageProvider.notifier).toggle(),
                  ),
                ])),
                const SizedBox(height: 20),

                // ── Cover image ──
                Reveal(
                  delay: const Duration(milliseconds: 90),
                  offset: const Offset(0, 40),
                  scale: 0.94,
                  duration: const Duration(milliseconds: 700),
                  child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.34,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                      boxShadow: const [BoxShadow(color: Color(0x33000000),
                          blurRadius: 40, offset: Offset(0, 16))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                      child: Stack(fit: StackFit.expand, children: [
                        // Slow settle-in zoom on the photo.
                        Reveal(
                          offset: Offset.zero,
                          scale: 1.12,
                          duration: const Duration(milliseconds: 1600),
                          child: appImage(AppConstants.onboardingCover),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00141414), Color(0xCC141414)],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Reveal(
                              delay: const Duration(milliseconds: 420),
                              child: Kicker(
                                  am ? 'ጎንደር · ኢትዮጵያ' : 'Gondar · Ethiopia',
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Reveal(
                              delay: const Duration(milliseconds: 500),
                              child: SwapText(am ? 'እንኳን ወደ ጎንደር መጡ'
                                    : 'Welcome to Gondar',
                                style: const TextStyle(fontSize: 30,
                                    height: 1.15, color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4)),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 18),
                Reveal(
                  delay: const Duration(milliseconds: 600),
                  child: SwapText(am ? 'የአፍሪካዋ ካሜሎት የኪስ መመሪያዎ'
                          : 'Your pocket guide to the Camelot of Africa',
                      style: const TextStyle(fontSize: 16, height: 1.5,
                          color: AppColors.ink700)),
                ),
                const Spacer(),

                ...Reveal.stagger(start: const Duration(milliseconds: 680),
                    stepMs: 80, [
                  FilledButton(
                    onPressed: () => pushScreen(context, const SignupScreen()),
                    child: SwapText(am ? 'መለያ ይፍጠሩ' : 'Create account'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                      onPressed: () => pushScreen(context, const LoginScreen()),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 52)),
                      child: SwapText(am ? 'ይግቡ' : 'Sign in'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: _enterApp,
                      style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48)),
                      child: SwapText(
                          am ? 'እንደ እንግዳ ያስሱ' : 'Browse as guest'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
