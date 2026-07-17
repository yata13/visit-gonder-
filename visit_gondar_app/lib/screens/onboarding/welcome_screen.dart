import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  WELCOME — shown right after first sign-up. Full background
//  image, "Welcome to Gondar", and what the app gives you.
// ═══════════════════════════════════════════════════════════════
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  static const _bg =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Fasil_Ghebbi%2C_Gondar.jpg/1200px-Fasil_Ghebbi%2C_Gondar.jpg';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _fade(int i, Widget child) {
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval((i * 0.12).clamp(0.0, 0.6),
          ((i * 0.12) + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);

    final perks = [
      (Icons.fort, am ? 'ቤተ መንግሥቶችንና አብያተ ክርስቲያናትን ያግኙ'
          : 'Discover castles & historic churches'),
      (Icons.hotel, am ? 'ሆቴሎችን በቀጥታ ይያዙ'
          : 'Book real Gondar hotels in seconds'),
      (Icons.person_pin, am ? 'ፈቃድ ያላቸው የአካባቢ መመሪያዎች'
          : 'Licensed local guides you can trust'),
      (Icons.celebration, am ? 'የጥምቀት የቀጥታ መርሃ ግብር'
          : 'Live Timket festival mode'),
      (Icons.notifications_active, am ? 'የቀጥታ ዜናና የደህንነት ማንቂያዎች'
          : 'Instant city news & safety alerts'),
    ];

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(fit: StackFit.expand, children: [
        // Full-bleed background image
        Image.network(_bg, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.charcoal)),
        // Dark gradient for readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x661C1410), Color(0xF21C1410)],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                _fade(0, Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.gold.withAlpha(110)),
                  ),
                  child: Text(
                      am ? '🎉 በተሳካ ሁኔታ ተመዝግበዋል'
                         : '🎉 Account created',
                      style: const TextStyle(color: AppColors.gold,
                          fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                )),
                const SizedBox(height: 18),
                _fade(1, Text(
                  am ? 'እንኳን ወደ\nጎንደር በደህና መጡ' : 'Welcome to\nGondar',
                  style: const TextStyle(
                    fontSize: 40, height: 1.12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFBF7F0),
                    letterSpacing: -1.0,
                  ),
                )),
                const SizedBox(height: 10),
                _fade(2, Text(
                  am ? 'በመተግበሪያው የሚያገኙት ይህ ነው'
                     : 'Here is what you get with this app',
                  style: const TextStyle(fontSize: 14.5,
                      color: Color(0xFFB3A899), height: 1.5),
                )),
                const SizedBox(height: 24),

                ...perks.asMap().entries.map((e) => _fade(3 + e.key,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withAlpha(30),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: AppColors.gold.withAlpha(70)),
                        ),
                        child: Icon(e.value.$1,
                            color: AppColors.gold, size: 18),
                      ),
                      const SizedBox(width: 13),
                      Expanded(child: Text(e.value.$2,
                          style: const TextStyle(
                              color: Color(0xFFEFE6D8),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4))),
                    ]),
                  ),
                )),

                const Spacer(),
                _fade(8, SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const MainNavigation())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                        am ? 'ጉብኝቱን ይጀምሩ' : 'Start exploring',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                )),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
