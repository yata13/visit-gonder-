// ═══════════════════════════════════════════════════════════════
//  VISIT GONDAR — TOURIST APP (Android / iOS)
//  Entry point. Boots Supabase, starts realtime alert popups,
//  then decides the first screen: intro → login → main app.
//  Run with:  flutter run
// ═══════════════════════════════════════════════════════════════
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
import 'screens/onboarding/intro_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/emergency/emergency_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/stay/stay_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
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
      // Smooth page transitions globally
      builder: (context, child) => child!,
      home: const _LaunchDecider(),
    );
  }
}

// ── Decides the first screen: intro → login → app ─────────────
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
    // Already signed in → straight to the app.
    if (Supabase.instance.client.auth.currentSession != null) {
      _set(const MainNavigation());
      return;
    }
    // First time ever → show the 3-page intro, else go to login/sign-up.
    bool introSeen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      introSeen = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
    } catch (_) {}
    _set(introSeen ? const OnboardingScreen() : const IntroScreen());
  }

  void _set(Widget w) {
    if (mounted) setState(() => _next = w);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _next ??
          const Scaffold(
            backgroundColor: AppColors.charcoal,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
    );
  }
}

// ── Main Navigation ───────────────────────────────────────────
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});
  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),     // Sites + Events combined
    EmergencyScreen(),   // SOS
    MapScreen(),
    StayScreen(),        // Hotels + Taxi + more services
  ];

  List<_NavItem> _navItems(String lang) => [
    _NavItem(Icons.home_outlined, Icons.home, tr(lang, 'nav_home')),
    _NavItem(Icons.account_balance_outlined, Icons.account_balance,
        tr(lang, 'nav_sites')),
    _NavItem(Icons.sos_outlined, Icons.sos, tr(lang, 'nav_sos'),
        emphasis: true),
    _NavItem(Icons.map_outlined, Icons.map, tr(lang, 'nav_map')),
    _NavItem(Icons.hotel_outlined, Icons.hotel, tr(lang, 'nav_stay')),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  void _onTabTap(int i) {
    if (i == _currentIndex) return;
    _fadeCtrl.forward(from: 0);
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _AnimatedNavBar(
        currentIndex: _currentIndex,
        items: _navItems(lang),
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Animated Bottom Nav Bar ───────────────────────────────────
class _AnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _AnimatedNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: _NavBarItem(item: item, selected: selected),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  const _NavBarItem({required this.item, required this.selected});
  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    if (widget.selected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final sos = widget.item.emphasis;

    // SOS gets a constant red treatment so it's always obvious.
    final iconColor = sos
        ? AppColors.error
        : (selected ? AppColors.goldDark : AppColors.textMuted);
    final labelColor = sos
        ? AppColors.error
        : (selected ? AppColors.goldDark : AppColors.textMuted);

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(
        scale: _scaleAnim,
        child: sos
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(selected ? 38 : 22),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.item.activeIcon,
                    color: AppColors.error, size: 20),
              )
            : Icon(
                selected ? widget.item.activeIcon : widget.item.icon,
                color: iconColor,
                size: 22,
              ),
      ),
      const SizedBox(height: 3),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: 10,
          fontWeight: (selected || sos) ? FontWeight.w700 : FontWeight.w400,
          color: labelColor,
        ),
        child: Text(widget.item.label),
      ),
      // Active dot
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: selected ? 16 : 0,
        height: 3,
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          color: sos ? AppColors.error : AppColors.goldDark,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ]);
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  final bool emphasis; // SOS — always shown in red
  const _NavItem(this.icon, this.activeIcon, this.label,
      {this.emphasis = false});
}
