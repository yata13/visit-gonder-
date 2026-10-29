import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_constants.dart';
import '../../core/nav.dart';
import '../../core/utils/ethiopian_date.dart';
import '../../main.dart' show MainNavigation;
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/passport_provider.dart';
import '../../providers/weather_provider.dart';
import '../../providers/tier_provider.dart';
import '../../services/weather_service.dart';
import '../../widgets/shimmer_image.dart';
import '../../widgets/ui.dart';
import '../../widgets/weather_card.dart';
import '../timket/timket_screen.dart';
import '../timket/timket_live.dart';
import '../hotels/hotels_screen.dart';
import '../guides/guides_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../posts/post_detail_screen.dart';
import '../posts/feed_screen.dart';
import '../planner/trip_planner_screen.dart';
import '../../widgets/motion.dart';
import '../../widgets/timket_art.dart';
import '../../services/realtime_alerts.dart';
import '../ride/ride_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  HOME (tab 1) — design "Home A · Timket hero".
//  Header → greeting + headline → search → Timket countdown →
//  four tiles → Passport progress → places near you → city news.
//  Typing in search swaps the sections for live results.
// ═══════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _timer;
  StreamSubscription<String>? _live;
  int _unreadCount = 0;
  static const _lastSeenKey = 'notif_last_seen';

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _timketDemo = false; // long-press the Timket card to toggle

  DateTime get _timket {
    final now = DateTime.now();
    final thisYear = DateTime(now.year, 1, 19);
    // After this year's festival is over, count to next year's.
    return now.isAfter(thisYear.add(const Duration(days: 2)))
        ? DateTime(now.year + 1, 1, 19)
        : thisYear;
  }

  int get _daysLeft {
    final diff = _timket.difference(DateTime.now());
    return diff.isNegative ? 0 : (diff.inHours / 24).ceil();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadUnreadCount();
    // The bell dot updates the moment a notification is sent.
    _live = RealtimeAlerts.changes
        .where((t) => t == 'notifications')
        .listen((_) => _loadUnreadCount());
  }

  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = DateTime.tryParse(prefs.getString(_lastSeenKey) ?? '');
      final data = await Supabase.instance.client
          .from('notifications')
          .select('created_at')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      setState(() => _unreadCount = lastSeen == null
          ? list.length
          : list
              .where((n) =>
                  DateTime.tryParse(n['created_at'] ?? '')
                      ?.isAfter(lastSeen) ??
                  false)
              .length);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    setState(() => _unreadCount = 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastSeenKey, DateTime.now().toUtc().toIso8601String());
    if (mounted) pushScreen(context, const NotificationsScreen());
  }

  @override
  void dispose() {
    _timer.cancel();
    _live?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _firstName() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final meta = user?.userMetadata;
      final name = (meta?['full_name'] ?? meta?['name'] ?? '') as String;
      if (name.trim().isNotEmpty) return name.trim().split(RegExp(r'\s+')).first;
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    final searching = _query.trim().isNotEmpty;
    final name = _firstName();
    final weather = ref.watch(weatherProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(weatherProvider);
              ref.invalidate(userTierProvider); // e.g. just made Premium
              ref.invalidate(passportCheckpointsProvider);
              ref.invalidate(myCheckinsProvider);
              await _loadUnreadCount();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
              children: Reveal.stagger([
                // ── Top bar ─────────────────────────────────
                Row(children: [
                  const AppMark(size: 32),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(AppConstants.appName,
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2)),
                  ),
                  GlassCircleButton(
                    label: am ? 'EN' : 'አማ',
                    semanticLabel:
                        am ? 'ወደ እንግሊዝኛ ቀይር' : 'Switch to Amharic',
                    onTap: () => ref.read(languageProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 8),
                  GlassCircleButton(
                    icon: Icons.notifications_none_rounded,
                    semanticLabel: am ? 'ማሳወቂያዎች' : 'Notifications',
                    dot: _unreadCount > 0,
                    onTap: _openNotifications,
                  ),
                ]),
                const SizedBox(height: 18),

                // ── Greeting + weather ──────────────────────
                Row(children: [
                  Expanded(
                    child: Text(
                        name.isEmpty
                            ? (am ? 'ሰላም' : 'Selam')
                            : (am ? 'ሰላም፣ $name' : 'Selam, $name'),
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ),
                  if (weather != null)
                    Container(
                      height: 30,
                      padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
                      decoration: AppDecor.glass(radius: 15),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(WeatherService.icon(weather.currentCode),
                            size: 16, color: AppColors.ink),
                        const SizedBox(width: 5),
                        Text(
                            '${weather.currentTemp.round()}° '
                            '${WeatherService.label(weather.currentCode, am)}',
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 32, height: 1.15,
                        fontWeight: FontWeight.w400, letterSpacing: -0.6,
                        color: AppColors.ink),
                    children: am
                        ? const [
                            TextSpan(text: 'ጎንደርን',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ' ያስሱ — የ'),
                            TextSpan(text: 'ቤተ መንግሥታት',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ' ከተማ'),
                          ]
                        : const [
                            TextSpan(text: 'Discover '),
                            TextSpan(text: 'Gondar',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ', city of '),
                            TextSpan(text: 'castles',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Search ──────────────────────────────────
                Container(
                  height: 52,
                  decoration: AppDecor.glass(radius: 26),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: am
                          ? 'ቤተ መንግሥት፣ ሆቴል፣ አስጎብኚ ይፈልጉ'
                          : 'Search castles, hotels, guides',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.muted),
                      suffixIcon: searching
                          ? IconButton(
                              tooltip: am ? 'አጽዳ' : 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.curve,
                  switchOutCurve: Curves.easeIn,
                  child: searching
                      ? _SearchResults(
                          key: const ValueKey('results'),
                          query: _query,
                          lang: lang,
                          hotels: ref.watch(hotelsProvider).valueOrNull ?? const [],
                          sites: ref.watch(sitesProvider).valueOrNull ?? const [],
                          guides: ref.watch(guidesProvider).valueOrNull ?? const [],
                        )
                      : _homeSections(lang),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeSections(String lang) {
    final am = isAm(lang);
    final now = DateTime.now();
    final live = _timketDemo || isTimketLive(now);
    final hotels = ref.watch(hotelsProvider).valueOrNull;
    final guides = ref.watch(guidesProvider).valueOrNull;

    return Column(
      key: const ValueKey('home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: Reveal.stagger(start: const Duration(milliseconds: 220), [
        // ── Timket: countdown hero, or LIVE dashboard ─────────
        GestureDetector(
          onLongPress: () => setState(() => _timketDemo = !_timketDemo),
          child: live
              ? TimketLiveDashboard(
                  lang: lang,
                  demo: _timketDemo && !isTimketLive(now),
                  onOpenMap: () => pushScreen(context, const MapScreen()),
                  onOpenSchedule: () =>
                      pushScreen(context, const TimketScreen()),
                )
              : _TimketHero(
                  days: _daysLeft,
                  date: _timket,
                  am: am,
                  onTap: () => pushScreen(context, const TimketScreen()),
                ),
        ),
        const SizedBox(height: 14),

        // ── Four tiles ───────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            for (final (i, tile) in [
            _Tile(
              dark: true,
              icon: Icons.hotel_outlined,
              title: am ? 'ሆቴሎች' : 'Hotels',
              sub: hotels == null
                  ? ' '
                  : (am ? '${hotels.length} የተረጋገጡ'
                      : '${hotels.length} verified'),
              onTap: () => pushScreen(context, const HotelsScreen()),
            ),
            _Tile(
              icon: Icons.tour_outlined,
              title: am ? 'አስጎብኚዎች' : 'Guides',
              sub: guides == null
                  ? ' '
                  : (am ? '${guides.length} አስጎብኚዎች'
                      : '${guides.length} guides'),
              onTap: () => pushScreen(context, const GuidesScreen()),
            ),
            _Tile(
              icon: Icons.electric_rickshaw_outlined,
              title: am ? 'ጉዞ' : 'Ride',
              sub: am ? 'ባጃጅ እና ታክሲ' : 'Bajaj & taxi',
              onTap: () => pushScreen(context, const RideScreen()),
            ),
            _Tile(
              dark: true,
              icon: Icons.shield_outlined,
              title: am ? 'የደህንነት ካርታ' : 'Safety map',
              sub: am ? 'የቀጥታ ካርታ' : 'Live map',
              onTap: () => pushScreen(context, const MapScreen()),
            ),
            ].indexed)
              Reveal(
                delay: Duration(milliseconds: 300 + i * 60),
                offset: Offset.zero,
                scale: 0.9,
                child: tile,
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Passport progress ────────────────────────────────
        _PassportCard(am: am, lang: lang),
        const SizedBox(height: 24),

        // ── Upcoming events (Meskel, Timket and the rest) ────
        _UpcomingEvents(am: am, lang: lang),

        // ── Places near you ──────────────────────────────────
        SectionHeader(
          title: am ? 'በአቅራቢያዎ ያሉ ቦታዎች' : 'Places near you',
          action: am ? 'ሁሉንም ይመልከቱ' : 'See all',
          onAction: () => MainNavigation.goTo(context, 1),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 196,
          child: ref.watch(sitesProvider).when(
                loading: () => ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: List.generate(3, (_) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: ShimmerImage(url: '', width: 200, height: 196,
                            borderRadius:
                                BorderRadius.all(Radius.circular(26))),
                      )),
                ),
                error: (_, _) => EmptyNote(
                    icon: Icons.cloud_off_rounded,
                    title: am ? 'ቦታዎች አልተጫኑም' : 'Could not load places'),
                data: (sites) => sites.isEmpty
                    ? EmptyNote(icon: Icons.castle_outlined,
                        title: tr(lang, 'no_sites'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        physics: const BouncingScrollPhysics(),
                        itemCount: sites.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => Reveal(
                          delay: Motion.stagger(i, stepMs: 70, max: 4),
                          offset: const Offset(40, 0),
                          child: _PlaceCard(
                            site: sites[i],
                            lang: lang,
                            onTap: () => openSite(context, sites[i], lang),
                          ),
                        ),
                      ),
              ),
        ),
        const SizedBox(height: 20),

        // ── Weather (today + 7 days) ─────────────────────────
        const WeatherCard(),
        const SizedBox(height: 12),

        // ── Plan my trip ─────────────────────────────────────
        PressScale(
          onTap: () => pushScreen(context, const TripPlannerScreen()),
          child: GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.ink, shape: BoxShape.circle),
                child: const Icon(Icons.route_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(am ? 'ጉዞዎን ያቅዱ' : 'Plan my trip',
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text(am ? 'በ3 ጥያቄ ሙሉ እቅድ' : 'A full plan in 3 questions',
                      style: const TextStyle(fontSize: 13,
                          color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ]),
          ),
        ),
        const SizedBox(height: 22),

        // ── City news ────────────────────────────────────────
        _CityNews(lang: lang),
      ]),
    );
  }
}

// ── Timket hero (night card) ──────────────────────────────────
class _TimketHero extends StatelessWidget {
  final int days;
  final DateTime date;
  final bool am;
  final VoidCallback onTap;
  const _TimketHero({
    required this.days,
    required this.date,
    required this.am,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (first, second) = dualDate(date, am);
    return Semantics(
      button: true,
      label: am ? 'የጥምቀት መመሪያ — $days ቀናት ቀርተዋል'
          : 'Timket guide — $days days to go',
      child: PressScale(
        onTap: onTap,
        child: Container(
          height: 196,
          padding: const EdgeInsets.all(18),
          clipBehavior: Clip.antiAlias,
          decoration: AppDecor.night(),
          child: Stack(clipBehavior: Clip.none, children: [
            // Gold painting: castle skyline, Timket umbrellas, crosses.
            const Positioned(
                left: -18, top: -18, right: -18, bottom: -18,
                child: TimketArt()),
            // Soft light in the top-right corner.
            Positioned(
              right: -60,
              top: -80,
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Kicker(am ? 'ጥምቀት በጎንደር' : 'Timket in Gondar',
                          color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.north_east_rounded,
                          color: AppColors.ink),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text('$days',
                          style: const TextStyle(fontSize: 64, height: 0.95,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2.5, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(am ? 'ቀናት ቀርተዋል' : 'days to go',
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE6E6E6))),
                    ]),
                    const Spacer(),
                    Text('$first\n$second',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14, height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE6E6E6))),
                  ],
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 2×2 tile ───────────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: '$title, $sub',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
          decoration: dark
              ? BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  boxShadow: const [BoxShadow(color: Color(0x2E000000),
                      blurRadius: 24, offset: Offset(0, 10))],
                )
              : AppDecor.glass(radius: AppRadius.tile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: fg)),
                Text(sub,
                    maxLines: 1,
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dark ? AppColors.onDarkMuted
                            : AppColors.muted)),
              ]),
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.10),
                  ),
                  child: Icon(icon, size: 20, color: fg),
                ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.north_east_rounded, size: 18, color: fg),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Passport progress card ─────────────────────────────────────
class _PassportCard extends ConsumerWidget {
  final bool am;
  final String lang;
  const _PassportCard({required this.am, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(passportProgressProvider);
    final total = p.total == 0 ? 12 : p.total;
    final dots = total.clamp(1, 24);
    final next = p.next;

    return GlassPanel(
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Kicker(am ? 'የጎንደር ፓስፖርት' : 'Gondar Passport'),
              const SizedBox(height: 2),
              Text(am ? 'ከ$total ማህተሞች ${p.stamps}ቱ'
                      : '${p.stamps} of $total stamps',
                  style: const TextStyle(fontSize: 19,
                      fontWeight: FontWeight.w800)),
              if (next != null)
                Text(
                    '${am ? 'ቀጣይ፦ ' : 'Next: '}${localName(next, lang)}',
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => MainNavigation.goTo(context, 2),
            style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                textStyle: AppFonts.button(14, FontWeight.w800)),
            child: Text(am ? 'ክፈት' : 'Open'),
          ),
        ]),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            children: List.generate(dots, (i) => Expanded(
                  child: Container(
                    height: 12,
                    margin: EdgeInsets.only(right: i == dots - 1 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < p.stamps
                          ? AppColors.ink
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )),
          ),
        ),
      ]),
    );
  }
}

// ── Upcoming events (Meskel, Timket and the rest) ──────────────
class _UpcomingEvents extends ConsumerWidget {
  final bool am;
  final String lang;
  const _UpcomingEvents({required this.am, required this.lang});

  static String _mon(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).valueOrNull ?? const [];
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final upcoming = events.where((e) {
      final d = DateTime.tryParse((e['date'] ?? '') as String);
      return d != null && !d.isBefore(startOfToday);
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(
        title: am ? 'ቀጣይ ዝግጅቶች' : 'Upcoming events',
        action: am ? 'ሁሉንም ይመልከቱ' : 'See all',
        onAction: () => MainNavigation.goTo(context, 1),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          itemCount: upcoming.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final e = upcoming[i];
            final isTimket = e['includes_timket'] == true;
            final name = (e['name'] ?? '') as String;
            final date = DateTime.parse(e['date'] as String);
            return Reveal(
              delay: Motion.stagger(i, stepMs: 70, max: 4),
              offset: const Offset(40, 0),
              child: PressScale(
                onTap: () => openEvent(context, e, lang),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(12),
                  decoration: isTimket
                      ? AppDecor.night(radius: 22)
                      : AppDecor.glass(radius: 22),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isTimket ? Colors.white : AppColors.ink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(
                            am ? EthDate.fromGregorian(date).monthName(true)
                                : _mon(date.month),
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isTimket ? AppColors.ink
                                    : Colors.white)),
                        Text(
                            '${am ? EthDate.fromGregorian(date).day : date.day}',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w800, height: 1.1,
                                color: isTimket ? AppColors.ink
                                    : Colors.white)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: isTimket ? Colors.white
                                  : AppColors.ink)),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

// ── Place card (horizontal list) ───────────────────────────────
class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> site;
  final String lang;
  final VoidCallback onTap;
  const _PlaceCard(
      {required this.site, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photo = sitePhoto(site);
    final meta = [(site['info'] ?? '') as String,
            (site['location'] ?? '') as String]
        .where((v) => v.isNotEmpty)
        .join(' · ');
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: AppDecor.glass(radius: 26),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 112,
            width: 200,
            child: photo.isEmpty
                ? Container(
                    color: AppColors.stone,
                    child: const Icon(Icons.castle_outlined,
                        size: 36, color: Color(0xFF8C8C8C)),
                  )
                : ShimmerImage(url: photo, height: 112, width: 200,
                    borderRadius: BorderRadius.zero),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(localName(site, lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800)),
              if (meta.isNotEmpty)
                Text(meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── City news: highlighted notice + next post ──────────────────
class _CityNews extends ConsumerWidget {
  final String lang;
  const _CityNews({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(lang);
    final posts = ref.watch(postsProvider).valueOrNull ?? const [];
    if (posts.isEmpty) return const SizedBox.shrink();

    Widget row(Map<String, dynamic> p, {required bool notice}) {
      final created = DateTime.tryParse((p['created_at'] ?? '') as String);
      final when = created == null ? '' : timeago.format(created);
      final photo = (p['photo'] ?? '') as String;
      final body = postField(p, 'body', lang);
      return PressScale(
        onTap: () =>
            pushScreen(context, PostDetailScreen(post: p, lang: lang)),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: notice
              ? BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEBEBEB), Color(0xFFEFEFEF)]),
                  borderRadius: BorderRadius.circular(24),
                )
              : AppDecor.glass(radius: 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // The post photo shows right in the card — no extra tap.
            if (photo.isNotEmpty)
              ShimmerImage(url: photo, height: 180,
                  borderRadius: BorderRadius.zero),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (photo.isEmpty) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notice ? AppColors.ink : AppColors.stone,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        notice ? Icons.campaign_outlined
                            : Icons.article_outlined,
                        size: 20,
                        color: notice ? Colors.white : AppColors.black),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (notice) Kicker(am ? 'ማስታወቂያ' : 'Notice'),
                    Text(postField(p, 'title', lang),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14,
                              height: 1.4, color: AppColors.ink700)),
                    ],
                    if (when.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(when,
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.muted)),
                    ],
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(
        title: am ? 'የከተማ ዜና' : 'City news',
        action: am ? 'ሁሉንም ይመልከቱ' : 'See all',
        onAction: () => pushScreen(context, const FeedScreen()),
      ),
      const SizedBox(height: 4),
      row(posts.first, notice: true),
      for (final p in posts.skip(1).take(2)) ...[
        const SizedBox(height: 10),
        row(p, notice: false),
      ],
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH RESULTS — hotels, sites and guides by English and
//  Amharic names, live as you type.
// ═══════════════════════════════════════════════════════════════
class _SearchResults extends StatelessWidget {
  final String query, lang;
  final List<Map<String, dynamic>> hotels, sites, guides;

  const _SearchResults({
    super.key,
    required this.query,
    required this.lang,
    required this.hotels,
    required this.sites,
    required this.guides,
  });

  bool _matches(String q, List<String?> names) =>
      names.any((n) => (n ?? '').toLowerCase().contains(q));

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final hotelHits = hotels.where((h) =>
        _matches(q, [h['name_en'] as String?, h['name_am'] as String?])).toList();
    final siteHits = sites.where((s) =>
        _matches(q, [s['name_en'] as String?, s['name_am'] as String?])).toList();
    final guideHits = guides.where((g) =>
        _matches(q, [g['name'] as String?])).toList();
    final total = hotelHits.length + siteHits.length + guideHits.length;

    if (total == 0) {
      return EmptyNote(
        key: const ValueKey('empty'),
        icon: Icons.search_off_rounded,
        title: '${tr(lang, 'no_match')} “$query”',
        body: tr(lang, 'try_other'),
      );
    }

    Widget group(String label, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 6),
              child: Kicker(label, color: AppColors.muted),
            ),
            ...rows,
          ],
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$total ${tr(lang, total == 1 ? 'result' : 'results')}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (hotelHits.isNotEmpty)
        group(tr(lang, 'hotels_label'), hotelHits.map((h) => _ResultRow(
              photo: hotelPhoto(h),
              title: localName(h, lang),
              subtitle: '\$${hotelPrice(h).toStringAsFixed(0)}'
                  '${tr(lang, 'per_night')} · ${(h['location'] ?? '') as String}',
              onTap: () => openHotel(context, h),
            )).toList()),
      if (siteHits.isNotEmpty)
        group(tr(lang, 'historic_sites'), siteHits.map((s) => _ResultRow(
              photo: sitePhoto(s),
              title: localName(s, lang),
              subtitle: (s['location'] ?? '') as String,
              onTap: () => openSite(context, s, lang),
            )).toList()),
      if (guideHits.isNotEmpty)
        group(tr(lang, 'local_guides'), guideHits.map((g) => _ResultRow(
              photo: (g['photo'] ?? '') as String,
              initials: (g['initials'] ?? 'GD') as String,
              title: (g['name'] ?? '') as String,
              subtitle: '\$${((g['price'] ?? 0) as num).toStringAsFixed(0)}'
                  '${tr(lang, 'per_day')} · ${(g['specialty'] ?? '') as String}',
              onTap: () => openGuide(context, g),
            )).toList()),
    ]);
  }
}

class _ResultRow extends StatelessWidget {
  final String photo, title, subtitle;
  final String? initials;
  final VoidCallback onTap;

  const _ResultRow({
    required this.photo,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: AppDecor.glass(radius: 20),
        child: Row(children: [
          if (photo.isNotEmpty)
            ShimmerImage(url: photo, width: 54, height: 54,
                borderRadius: BorderRadius.circular(14))
          else
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(initials ?? '·',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                      color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
