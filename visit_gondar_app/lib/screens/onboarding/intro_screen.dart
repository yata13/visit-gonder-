import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../widgets/ui.dart';
import 'onboarding_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  FIRST OPEN — design "Start · Language" then "Start · Welcome"
//  (three slides you swipe sideways). Shown once, then remembered.
// ═══════════════════════════════════════════════════════════════
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});
  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  bool _languageChosen = false;

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _languageChosen
                ? _Slides(key: const ValueKey('slides'), onDone: _finish)
                : _LanguageStep(
                    key: const ValueKey('lang'),
                    onContinue: () => setState(() => _languageChosen = true),
                  ),
          ),
          // SOS is on every screen — even before sign-in.
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 92,
            child: const SosButton(),
          ),
        ]),
      ),
    );
  }
}

// ── Step 1: choose language ────────────────────────────────────
class _LanguageStep extends ConsumerWidget {
  final VoidCallback onContinue;
  const _LanguageStep({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);

    Widget option(String code, String title, String sub) {
      final on = lang == code;
      return Semantics(
        selected: on,
        button: true,
        child: PressScale(
          onTap: () {
            if (!on) ref.read(languageProvider.notifier).toggle();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: on ? AppColors.ink : const Color(0xFFB3B3B3),
                  width: on ? 2.5 : 1),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontSize: 22, height: 1.4,
                          fontWeight: FontWeight.w800)),
                  Text(sub,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: on ? AppColors.ink : const Color(0xFF8C8C8C),
                      width: on ? 8 : 2),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          const Align(
              alignment: Alignment.centerLeft, child: AppMark(size: 56)),
          const SizedBox(height: 28),
          const Text('Choose your language',
              style: TextStyle(fontSize: 30, height: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('ቋንቋ ይምረጡ',
              style: TextStyle(fontSize: 26, height: 1.35,
                  fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 28),
          option('en', 'English', 'እንግሊዝኛ'),
          const SizedBox(height: 12),
          option('am', 'አማርኛ', 'Amharic'),
          const SizedBox(height: 28),
          const Text('You can change this later in Me.\n'
              'በኋላ በ«እኔ» ገጽ መቀየር ይችላሉ።',
              style: TextStyle(fontSize: 14, height: 1.5,
                  color: AppColors.muted)),
          const Spacer(),
          FilledButton(
            onPressed: onContinue,
            child: Text(am ? 'ቀጥል' : 'Continue'),
          ),
        ]),
      ),
    );
  }
}

// ── Step 2: three slides ───────────────────────────────────────
class _Slide {
  final String titleEn, titleAm, bodyEn, bodyAm;
  final List<String> getsEn, getsAm;
  const _Slide(this.titleEn, this.titleAm, this.bodyEn, this.bodyAm,
      this.getsEn, this.getsAm);
}

const _slides = [
  _Slide(
    'Explore the city', 'ከተማዋን ያስሱ',
    'Castles, churches, hotels, guides and bajaj — all in one place.',
    'ቤተ መንግሥታት፣ አብያተ ክርስቲያናት፣ ሆቴሎች፣ አስጎብኚዎች እና ባጃጅ — በአንድ ቦታ።',
    ['Map of castles, churches and sites', 'Verified hotels and guides',
        'Call a bajaj driver'],
    ['የቤተ መንግሥታት እና የቦታዎች ካርታ', 'የተረጋገጡ ሆቴሎች እና አስጎብኚዎች',
        'ለባጃጅ አሽከርካሪ ይደውሉ'],
  ),
  _Slide(
    'Collect Passport stamps', 'የፓስፖርት ማህተሞችን ይሰብስቡ',
    'Visit each site, unlock its story and earn badges.',
    'እያንዳንዱን ቦታ ይጎብኙ፣ ታሪኩን ይክፈቱ፣ ባጆች ያግኙ።',
    ['A stamp at every site you visit', 'Stories to read',
        'Badges, points and Timket Quest'],
    ['በሚጎበኙት ቦታ ሁሉ ማህተም', 'የሚነበቡ ታሪኮች',
        'ባጆች፣ ነጥቦች እና የጥምቀት ተልዕኮ'],
  ),
  _Slide(
    'Stay safe with SOS', 'በSOS ደህንነትዎን ይጠብቁ',
    'One red button on every screen. Tap it to reach the Safety Desk.',
    'በእያንዳንዱ ገጽ ላይ አንድ ቀይ ቁልፍ። የደህንነት ዴስክን ለመጥራት ይጫኑት።',
    ['SOS on every screen', 'Safety map and tips',
        'Ask AI in English or Amharic'],
    ['SOS በእያንዳንዱ ገጽ', 'የደህንነት ካርታ እና ምክሮች',
        'AIን በአማርኛ ወይም በእንግሊዝኛ ይጠይቁ'],
  ),
];

class _Slides extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _Slides({super.key, required this.onDone});
  @override
  ConsumerState<_Slides> createState() => _SlidesState();
}

class _SlidesState extends ConsumerState<_Slides> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _art(int i) {
    Widget well(Widget child) => Container(
          width: 220,
          height: 220,
          decoration: const BoxDecoration(
              color: AppColors.stone, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: child,
        );
    switch (i) {
      case 0:
        return well(Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(36),
            ),
            child: const AppMark(size: 96),
          ),
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.black,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.stone, width: 5),
              ),
              child: const Icon(Icons.place_outlined,
                  color: Colors.white, size: 26),
            ),
          ),
        ]));
      case 1:
        return well(Transform.rotate(
          angle: -0.17,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 4),
            ),
            child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(Icons.church_outlined, size: 58, color: AppColors.black),
              SizedBox(height: 4),
              Text('GONDAR · ጎንደር',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 1.3)),
            ]),
          ),
        ));
      default:
        return well(Container(
          width: 136,
          height: 136,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.sos,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.dangerTint,
                spreadRadius: 12)],
          ),
          child: const Text('SOS',
              style: TextStyle(color: Colors.white, fontSize: 40,
                  fontWeight: FontWeight.w800, letterSpacing: 2.4)),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final last = _page == _slides.length - 1;

    return SafeArea(
      child: Column(children: [
        SizedBox(
          height: 60,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GlassCircleButton(
                label: am ? 'ዝለል' : 'Skip',
                semanticLabel: am ? 'ዝለል' : 'Skip',
                onTap: widget.onDone,
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final s = _slides[i];
              final gets = am ? s.getsAm : s.getsEn;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(children: [
                  _art(i),
                  const SizedBox(height: 20),
                  Text(am ? s.titleAm : s.titleEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, height: 1.2,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(am ? s.bodyAm : s.bodyEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, height: 1.5,
                          color: AppColors.ink700)),
                  const SizedBox(height: 20),
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Kicker(am ? 'የሚያገኙት' : 'What you get',
                          color: AppColors.muted),
                      for (final g in gets) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: AppColors.ink,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(g,
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                ]),
              );
            },
          ),
        ),
        // Dots
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.ink
                        : const Color(0xFFB3B3B3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: SizedBox(
            width: double.infinity,
            child: last
                ? FilledButton(
                    onPressed: widget.onDone,
                    child: Text(am ? 'እንጀምር' : 'Get started'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _ctrl.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(am ? 'ቀጣይ' : 'Next'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 52)),
                  ),
          ),
        ),
      ]),
    );
  }
}
