// ═══════════════════════════════════════════════════════════════
//  VISIT GONDAR — TOURIST APP (Android / iOS)
//  Entry point. Boots Supabase, starts realtime alert popups,
//  then decides the first screen: splash → welcome → sign-in → app.
//  Run with:  flutter run
// ═══════════════════════════════════════════════════════════════
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/realtime_alerts.dart';
import 'providers/language_provider.dart';
import 'widgets/ui.dart';
import 'screens/onboarding/intro_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/passport/passport_screen.dart';
import 'screens/ai/ask_gondar_screen.dart';
import 'screens/me/me_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  // Never block the app on startup problems — screens have their own
  // loading/error states and recover once the connection is back.
  try {
    await SupabaseService.initialize();
    RealtimeAlerts.start(); // live popups on every screen
  } catch (_) {}
  runApp(const ProviderScope(child: VisitGondarApp()));
}

class VisitGondarApp extends StatelessWidget {
  const VisitGondarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visit Gondar',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.theme,
      home: const _LaunchDecider(),
    );
  }
}

// ── Decides the first screen: welcome → sign-in → app ─────────
class _LaunchDecider extends StatefulWidget {
  const _LaunchDecider();
  @override
  State<_LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<_LaunchDecider> {
  Widget? _next;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // Let the splash breathe for a moment.
    final wait = Future.delayed(const Duration(milliseconds: 900));
    Widget next;
    if (_signedIn()) {
      next = const MainNavigation();
    } else {
      // First time ever → language + 3 welcome slides, else sign-in.
      bool introSeen = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        introSeen = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
      } catch (_) {}
      next = introSeen ? const OnboardingScreen() : const IntroScreen();
    }
    await wait;
    if (mounted) setState(() => _next = next);
  }

  bool _signedIn() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false; // Supabase failed to boot (offline / no .env)
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _next ?? const SplashScreen(),
    );
  }
}

/// Splash — white, app mark, "Visit Gondar · ጎንደር", thin loader.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AppMark(size: 112),
              const SizedBox(height: 18),
              const Text(AppConstants.appName,
                  style: TextStyle(fontSize: 34, height: 1.1,
                      fontWeight: FontWeight.w800, letterSpacing: -0.6,
                      color: AppColors.black)),
              const SizedBox(height: 8),
              const Text('ጎንደር · Gondar',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w600, color: AppColors.muted)),
            ]),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 72,
          child: Center(
            child: SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  color: AppColors.black,
                  backgroundColor: AppColors.stone,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Main Navigation: Home · Explore · Passport · Ask AI · Me ──
class MainNavigation extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  /// Lets any screen switch tabs (e.g. Home → "Open" Passport).
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainNavigationState>()?.select(index);

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late int _index = widget.initialIndex;
  final _visited = <int>{};

  static const _askTab = 3;

  void select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  Widget _screen(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const ExploreScreen(),
        2 => const PassportScreen(),
        3 => const AskGondarScreen(),
        _ => const MeScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    _visited.add(_index);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final tabs = [
      _Tab(Icons.home_outlined, Icons.home_rounded, am ? 'መነሻ' : 'Home'),
      _Tab(Icons.explore_outlined, Icons.explore, am ? 'ያስሱ' : 'Explore'),
      _Tab(Icons.badge_outlined, Icons.badge,
          am ? 'ፓስፖርት' : 'Passport'),
      _Tab(Icons.auto_awesome_outlined, Icons.auto_awesome,
          am ? 'AI ይጠይቁ' : 'Ask AI'),
      _Tab(Icons.person_outline_rounded, Icons.person_rounded,
          am ? 'እኔ' : 'Me'),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.ground,
      body: Stack(children: [
        // Keep visited tabs alive so scroll position and chats survive.
        IndexedStack(
          index: _index,
          children: List.generate(5, (i) =>
              _visited.contains(i) ? _screen(i) : const SizedBox.shrink()),
        ),
        // SOS — always one tap away. Lifted on Ask AI so it clears
        // the message box.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          right: 16,
          bottom: bottomInset + 80 + (_index == _askTab ? 68 : 0),
          child: SosButton(
              semanticLabel: am ? 'SOS — አሁን እርዳታ ያግኙ'
                  : 'SOS — get help now'),
        ),
      ]),
      bottomNavigationBar: _GlassTabBar(
        tabs: tabs,
        index: _index,
        onTap: select,
        label: am ? 'ዋና ምናሌ' : 'Main menu',
      ),
    );
  }
}

class _Tab {
  final IconData icon, activeIcon;
  final String label;
  const _Tab(this.icon, this.activeIcon, this.label);
}

/// Dark frosted pill with five tabs; the active tab is a white pill.
class _GlassTabBar extends StatelessWidget {
  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onTap;
  final String label;
  const _GlassTabBar({
    required this.tabs,
    required this.index,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xD11C1C1C), // 82%
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final on = i == index;
                    final t = tabs[i];
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: on,
                        label: t.label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: on ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: on
                                  ? const [BoxShadow(
                                      color: Color(0x40000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 6))]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(on ? t.activeIcon : t.icon,
                                    size: 20,
                                    color: on
                                        ? AppColors.black
                                        : Colors.white
                                            .withValues(alpha: 0.72)),
                                const SizedBox(height: 1),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(t.label,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.15,
                                        fontWeight: on
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: on
                                            ? AppColors.black
                                            : Colors.white
                                                .withValues(alpha: 0.72),
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
