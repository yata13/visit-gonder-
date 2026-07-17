import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import 'onboarding_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  INTRO — clean, simple first-open pages: a rounded image, a
//  short title and description, dots, and a button. Shown once.
// ═══════════════════════════════════════════════════════════════
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});
  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroSlide {
  final String image, titleEn, titleAm, bodyEn, bodyAm;
  const _IntroSlide(this.image, this.titleEn, this.titleAm,
      this.bodyEn, this.bodyAm);
}

const _slides = [
  _IntroSlide(
    AppConstants.introImage1,
    'Discover Gondar', 'ጎንደርን ያግኙ',
    'Royal castles, ancient churches and living history — the Camelot of Africa, in your pocket.',
    'ንጉሣዊ ቤተ መንግሥቶች፣ ጥንታዊ አብያተ ክርስቲያናት እና ሕያው ታሪክ — በኪስዎ ውስጥ።'),
  _IntroSlide(
    AppConstants.introImage2,
    'Stay & explore', 'ይቆዩ እና ይጎብኙ',
    'Book hotels, find licensed guides and taxis, and let the Trip Planner build your perfect days.',
    'ሆቴሎችን ይያዙ፣ መመሪያዎችን ያግኙ፣ እና የጉዞ እቅድ ቀኖችዎን ይገንባ።'),
  _IntroSlide(
    AppConstants.introImage3,
    'Relax & enjoy', 'ይዝናኑ',
    'Follow Timket live, get instant city news and safety alerts, and travel with total peace of mind.',
    'ጥምቀትን በቀጥታ ይከታተሉ፣ የቀጥታ ዜናና የደህንነት ማንቂያ ያግኙ።'),
];

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final last = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // Skip
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(
                onPressed: _finish,
                child: Text(am ? 'ዝለል' : 'Skip',
                    style: const TextStyle(color: AppColors.textMuted,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ),

          // Slides
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    const Spacer(flex: 1),
                    // ── Image with soft colored blob behind ──
                    Expanded(
                      flex: 10,
                      child: Stack(alignment: Alignment.center, children: [
                        // blob
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppColors.gold.withAlpha(40),
                              AppColors.gold.withAlpha(0),
                            ]),
                          ),
                        ),
                        // rounded image
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: [BoxShadow(
                                  color: AppColors.charcoal.withAlpha(28),
                                  blurRadius: 28, offset: const Offset(0, 14))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: appImage(s.image),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const Spacer(flex: 1),
                    // ── Title + body ──
                    Text(am ? s.titleAm : s.titleEn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal, letterSpacing: -0.5)),
                    const SizedBox(height: 12),
                    Text(am ? s.bodyAm : s.bodyEn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14.5,
                            color: AppColors.textSecondary, height: 1.6)),
                    const Spacer(flex: 2),
                  ]),
                );
              },
            ),
          ),

          // Dots
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.gold : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ))),
          const SizedBox(height: 22),

          // Button
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                    last
                        ? (am ? 'ይጀምሩ' : 'Get Started')
                        : (am ? 'ቀጣይ' : 'Next'),
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
