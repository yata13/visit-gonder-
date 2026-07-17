import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../sites/sites_screen.dart';
import '../sites/site_detail_screen.dart';
import '../timket/timket_screen.dart';
import '../timket/timket_live.dart';
import '../hotels/hotels_screen.dart';
import '../guides/guides_screen.dart';
import '../guides/guide_profile_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../posts/post_detail_screen.dart';
import '../posts/post_card.dart';
import '../posts/feed_screen.dart';
import '../planner/trip_planner_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  HOME — premium heritage design, live Supabase data, real search
//  charcoal #1c1410 · gold #d4a13c · rust #a8451f · cream #fbf7f0
// ═══════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final _timket = DateTime(2027, 1, 19);
  late Timer _timer;
  int _unreadCount = 0;
  static const _lastSeenKey = 'notif_last_seen';

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _searchFilter = 'all'; // all | hotels | sites | guides
  bool _showFilters = false;    // toggled by the filter (tune) button
  bool _timketDemo = false; // long-press the Timket card to toggle

  late AnimationController _staggerCtrl;

  Duration get _remaining {
    final diff = _timket.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen =
          DateTime.tryParse(prefs.getString(_lastSeenKey) ?? '');
      final data = await Supabase.instance.client
          .from('notifications')
          .select('created_at')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      if (!mounted) return;
      if (lastSeen == null) {
        setState(() => _unreadCount = list.length);
      } else {
        setState(() => _unreadCount = list
            .where((n) => DateTime.tryParse(n['created_at'] ?? '')
                ?.isAfter(lastSeen) ?? false)
            .length);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    setState(() => _unreadCount = 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastSeenKey, DateTime.now().toUtc().toIso8601String());
    _push(const NotificationsScreen());
  }

  @override
  void dispose() {
    _timer.cancel();
    _staggerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fade + slide entrance, staggered by section index. 250–350ms feel.
  Widget _animated(int index, Widget child) {
    final start = (index * 0.10).clamp(0.0, 0.65);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  void _push(Widget screen) => Navigator.push(context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.03, 0),
                  end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ));

  void _openSite(Map<String, dynamic> site) =>
      _push(SiteDetailScreen(site: {
        'id': site['id'],
        'name': siteName(site),
        'subtitle': (site['info'] ?? '') as String,
        'location': (site['location'] ?? '') as String,
        'image': sitePhoto(site),
        'description': (site['description'] ?? '') as String,
        'rating': '4.8',
        'tag': '',
        'audio': false,
      }));

  @override
  Widget build(BuildContext context) {
    final d = _remaining;
    final lang = ref.watch(languageProvider);
    final hotelsAsync = ref.watch(hotelsProvider);
    final sitesAsync = ref.watch(sitesProvider);
    final guidesAsync = ref.watch(guidesProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final timketPhoto = timketPhotoFrom(
        eventsAsync.value ?? const [], sitesAsync.value ?? const []);
    final searching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),

            // ── Top bar ──────────────────────────────────────
            _animated(0, Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.location_on, size: 13, color: AppColors.rust),
                    SizedBox(width: 4),
                    Text('GONDAR · ETHIOPIA',
                        style: TextStyle(fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.4)),
                  ]),
                  const SizedBox(height: 3),
                  const Text('Visit Gondar',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 19, color: AppColors.charcoal,
                          letterSpacing: -0.3)),
                ]),
                Row(children: [
                  _PressScale(
                    onTap: _openNotifications,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.surfaceVariant),
                        boxShadow: [BoxShadow(
                            color: AppColors.charcoal.withAlpha(10),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Stack(children: [
                        const Center(child: Icon(Icons.notifications_outlined,
                            size: 21, color: AppColors.charcoal)),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 7, top: 7,
                            child: Container(
                              width: 15, height: 15,
                              decoration: const BoxDecoration(
                                  color: AppColors.rust,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8.5,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PressScale(
                    onTap: () =>
                        ref.read(languageProvider.notifier).toggle(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                          isAm(lang) ? 'አማ / EN' : 'EN / አማ',
                          style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                    ),
                  ),
                ]),
              ],
            )),
            const SizedBox(height: 26),

            // ── Headline ─────────────────────────────────────
            _animated(0, RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: tr(lang, 'discover'),
                  style: const TextStyle(fontSize: 28,
                      fontWeight: FontWeight.w400,
                      height: 1.22, color: AppColors.textSecondary,
                      letterSpacing: -0.5),
                ),
                TextSpan(
                  text: tr(lang, 'camelot'),
                  style: const TextStyle(fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.15, color: AppColors.charcoal,
                      letterSpacing: -1.0),
                ),
              ]),
            )),
            const SizedBox(height: 20),

            // ── Search bar (REAL) ────────────────────────────
            _animated(1, Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: searching
                        ? AppColors.gold
                        : AppColors.surfaceVariant),
                boxShadow: [BoxShadow(
                    color: AppColors.charcoal.withAlpha(8),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14.5,
                        color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: tr(lang, 'search_hint'),
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 14.5),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (searching)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                      FocusScope.of(context).unfocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                GestureDetector(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: Container(
                    margin: EdgeInsets.only(left: searching ? 8 : 0),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _showFilters
                          ? AppColors.gold
                          : AppColors.gold.withAlpha(38),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.tune, size: 14,
                        color: _showFilters
                            ? AppColors.charcoal : AppColors.goldDark),
                  ),
                ),
              ]),
            )),

            // ── Filter chips (revealed by the filter button) ──
            if (_showFilters) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(lang, 'all', tr(lang, 'view_all'),
                        Icons.apps),
                    _filterChip(lang, 'hotels', tr(lang, 'hotels'),
                        Icons.hotel),
                    _filterChip(lang, 'sites', tr(lang, 'sites'),
                        Icons.account_balance),
                    _filterChip(lang, 'guides', tr(lang, 'guides'),
                        Icons.person_pin),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Search results OR normal home content ────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.02),
                      end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: searching
                  ? _SearchResults(
                      key: const ValueKey('results'),
                      query: _query,
                      lang: lang,
                      filter: _searchFilter,
                      hotels: hotelsAsync.value ?? const [],
                      sites: sitesAsync.value ?? const [],
                      guides: guidesAsync.value ?? const [],
                      onHotel: (h) => _push(HotelDetailPage(hotel: h)),
                      onSite: _openSite,
                      onGuide: (g) => _push(GuideProfileScreen(guide: g)),
                    )
                  : _homeContent(
                      d, lang, timketPhoto, hotelsAsync, sitesAsync),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Normal home sections ─────────────────────────────────────
  Widget _homeContent(Duration d, String lang, String timketPhoto,
      AsyncValue<List<Map<String, dynamic>>> hotelsAsync,
      AsyncValue<List<Map<String, dynamic>>> sitesAsync) {
    return Column(
      key: const ValueKey('home'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Plan My Trip banner ───────────────────────────
        _animated(2, _PressScale(
          onTap: () => _push(const TripPlannerScreen()),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gold, AppColors.goldDark]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.gold.withAlpha(70),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withAlpha(30),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.charcoal, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAm(lang) ? 'የት እንደሚጀምሩ አያውቁም?'
                        : "Don't know where to start?",
                    style: const TextStyle(color: AppColors.charcoal,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(isAm(lang) ? 'በ3 ጥያቄ ሙሉ እቅድ ይገንቡ'
                        : 'Build a full plan in 3 questions',
                    style: TextStyle(color: AppColors.charcoal.withAlpha(190),
                        fontSize: 12.5)),
              ])),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.charcoal, size: 20),
            ]),
          ),
        )),
        const SizedBox(height: 20),

        // ── Featured hero (first site, LIVE) ──────────────
        sitesAsync.maybeWhen(
          data: (sites) => sites.isEmpty
              ? const SizedBox.shrink()
              : _animated(2, _FeaturedHero(
                  site: sites.first,
                  lang: lang,
                  onTap: () => _openSite(sites.first),
                )),
          orElse: () => _animated(2, const ShimmerImage(
              url: '', height: 290,
              borderRadius: BorderRadius.all(Radius.circular(24)))),
        ),
        const SizedBox(height: 24),

        // ── Timket: countdown card, or LIVE dashboard during
        //    the festival (long-press toggles demo mode) ─────
        _animated(3, GestureDetector(
          onLongPress: () =>
              setState(() => _timketDemo = !_timketDemo),
          child: (_timketDemo || isTimketLive(DateTime.now()))
              ? TimketLiveDashboard(
                  lang: lang,
                  demo: _timketDemo && !isTimketLive(DateTime.now()),
                  onOpenMap: () => _push(const MapScreen()),
                  onOpenSchedule: () => _push(const TimketScreen()),
                )
              : _TimketCard(remaining: d, lang: lang, photo: timketPhoto),
        )),
        const SizedBox(height: 28),

        // ── Quick links ───────────────────────────────────
        _animated(4, Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickLink(Icons.account_balance_outlined,
                tr(lang, 'sites'), () => _push(const SitesScreen())),
            _QuickLink(Icons.hotel_outlined,
                tr(lang, 'hotels'), () => _push(const HotelsScreen())),
            _QuickLink(Icons.person_pin_outlined,
                tr(lang, 'guides'), () => _push(const GuidesScreen())),
            _QuickLink(Icons.map_outlined,
                tr(lang, 'map'), () => _push(const MapScreen())),
          ],
        )),
        const SizedBox(height: 30),

        // ── Must-see sites (LIVE) ─────────────────────────
        _animated(5, _sectionHeader(lang, tr(lang, 'must_see'),
            () => _push(const SitesScreen()))),
        const SizedBox(height: 14),
        _animated(5, SizedBox(
          height: 235,
          child: sitesAsync.when(
            loading: () => _shimmerRow(width: 180, height: 235),
            error: (e, _) => _errorRow('Could not load sites'),
            data: (sites) => sites.isEmpty
                ? _emptyRow(tr(lang, 'no_sites'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: sites.length,
                    itemBuilder: (_, i) => _SiteCard(
                      site: sites[i],
                      lang: lang,
                      onTap: () => _openSite(sites[i]),
                    ),
                  ),
          ),
        )),
        const SizedBox(height: 28),

        // ── Top hotels (LIVE) ─────────────────────────────
        _animated(6, _sectionHeader(lang, tr(lang, 'top_hotels'),
            () => _push(const HotelsScreen()))),
        const SizedBox(height: 14),
        _animated(6, SizedBox(
          height: 170,
          child: hotelsAsync.when(
            loading: () => _shimmerRow(width: 175, height: 170),
            error: (e, _) => _errorRow('Could not load hotels'),
            data: (hotels) => hotels.isEmpty
                ? _emptyRow(tr(lang, 'no_hotels'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: hotels.length,
                    itemBuilder: (_, i) => _HotelMiniCard(
                      hotel: hotels[i],
                      lang: lang,
                      onTap: () =>
                          _push(HotelDetailPage(hotel: hotels[i])),
                    ),
                  ),
          ),
        )),
        const SizedBox(height: 26),

        // ── Gondar Today — news feed (latest 3 + view all) ──
        Consumer(builder: (_, ref, __) {
          final postsAsync = ref.watch(postsProvider);
          return postsAsync.maybeWhen(
            data: (posts) => posts.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _animated(7, _sectionHeader(lang,
                          tr(lang, 'gondar_today'),
                          () => _push(const FeedScreen()))),
                      const SizedBox(height: 14),
                      ...posts.take(3).map((p) => _animated(7, PostCard(
                            post: p,
                            lang: lang,
                            onTap: () => _push(PostDetailScreen(
                                post: p, lang: lang)),
                          ))),
                      const SizedBox(height: 26),
                    ],
                  ),
            // Table not created yet, or loading — just hide the feed.
            orElse: () => const SizedBox.shrink(),
          );
        }),

        // ── Offline banner ────────────────────────────────
        _animated(7, Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.download_done_rounded,
                color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(
              tr(lang, 'offline_ready'),
              style: const TextStyle(fontSize: 13,
                  color: Color(0xFFEFE6D8), height: 1.4),
            )),
          ]),
        )),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _filterChip(String lang, String value, String label, IconData icon) {
    final selected = _searchFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _searchFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.charcoal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected
              ? AppColors.charcoal : AppColors.surfaceVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: selected ? AppColors.gold : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String lang, String title, VoidCallback onViewAll) =>
      Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: const TextStyle(fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
              letterSpacing: -0.4)),
      GestureDetector(
        onTap: onViewAll,
        child: Row(children: [
          Text(tr(lang, 'view_all'),
              style: const TextStyle(color: AppColors.rust,
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_forward_rounded,
              size: 14, color: AppColors.rust),
        ]),
      ),
    ],
  );

  Widget _shimmerRow({required double width, required double height}) =>
      ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: ShimmerImage(url: '', width: width, height: height),
        ),
      );

  Widget _errorRow(String msg) => Center(
    child: Text(msg, style: const TextStyle(color: AppColors.textMuted)));

  Widget _emptyRow(String msg) => Center(
    child: Text(msg, style: const TextStyle(color: AppColors.textMuted)));
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH RESULTS — filters hotels, sites and guides by English
//  and Amharic names, live as you type.
// ═══════════════════════════════════════════════════════════════
class _SearchResults extends StatelessWidget {
  final String query, lang, filter;
  final List<Map<String, dynamic>> hotels, sites, guides;
  final void Function(Map<String, dynamic>) onHotel, onSite, onGuide;

  const _SearchResults({
    super.key,
    required this.query,
    required this.lang,
    required this.filter,
    required this.hotels,
    required this.sites,
    required this.guides,
    required this.onHotel,
    required this.onSite,
    required this.onGuide,
  });

  bool _matches(String q, List<String?> names) =>
      names.any((n) => (n ?? '').toLowerCase().contains(q));

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    // Apply the category filter chosen with the filter button.
    final showHotels = filter == 'all' || filter == 'hotels';
    final showSites  = filter == 'all' || filter == 'sites';
    final showGuides = filter == 'all' || filter == 'guides';

    final hotelHits = !showHotels ? <Map<String, dynamic>>[] : hotels.where((h) =>
        _matches(q, [h['name_en'] as String?, h['name_am'] as String?])).toList();
    final siteHits = !showSites ? <Map<String, dynamic>>[] : sites.where((s) =>
        _matches(q, [s['name_en'] as String?, s['name_am'] as String?])).toList();
    final guideHits = !showGuides ? <Map<String, dynamic>>[] : guides.where((g) =>
        _matches(q, [g['name'] as String?])).toList();

    final total = hotelHits.length + siteHits.length + guideHits.length;

    if (total == 0) {
      return Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(children: [
            const Icon(Icons.search_off,
                size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('${tr(lang, 'no_match')} “$query”',
                style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(tr(lang, 'try_other'),
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ]),
        ),
      );
    }

    int i = 0;
    Widget staggered(Widget child) {
      final delay = (i++).clamp(0, 8);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 200 + delay * 40),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 14 * (1 - v)), child: c)),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$total ${tr(lang, total == 1 ? 'result' : 'results')}',
            style: const TextStyle(fontSize: 12.5,
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        if (hotelHits.isNotEmpty) ...[
          _GroupLabel(icon: Icons.hotel_outlined,
              label: tr(lang, 'hotels_label')),
          ...hotelHits.map((h) => staggered(_ResultRow(
                photo: hotelPhoto(h),
                title: localName(h, lang),
                subtitle:
                    '\$${hotelPrice(h).toStringAsFixed(0)}${tr(lang, 'per_night')} · ${(h['location'] ?? '') as String}',
                accent: AppColors.gold,
                onTap: () => onHotel(h),
              ))),
          const SizedBox(height: 14),
        ],

        if (siteHits.isNotEmpty) ...[
          _GroupLabel(icon: Icons.account_balance_outlined,
              label: tr(lang, 'historic_sites')),
          ...siteHits.map((s) => staggered(_ResultRow(
                photo: sitePhoto(s),
                title: localName(s, lang),
                subtitle: (s['location'] ?? '') as String,
                accent: AppColors.rust,
                onTap: () => onSite(s),
              ))),
          const SizedBox(height: 14),
        ],

        if (guideHits.isNotEmpty) ...[
          _GroupLabel(icon: Icons.person_pin_outlined,
              label: tr(lang, 'local_guides')),
          ...guideHits.map((g) => staggered(_ResultRow(
                photo: (g['photo'] ?? '') as String,
                initials: (g['initials'] ?? 'GD') as String,
                title: (g['name'] ?? '') as String,
                subtitle:
                    '\$${((g['price'] ?? 0) as num).toStringAsFixed(0)}${tr(lang, 'per_day')} · ${(g['specialty'] ?? '') as String}',
                accent: AppColors.charcoal,
                onTap: () => onGuide(g),
              ))),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GroupLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 14, color: AppColors.rust),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted, letterSpacing: 1.4)),
    ]),
  );
}

class _ResultRow extends StatelessWidget {
  final String photo, title, subtitle;
  final String? initials;
  final Color accent;
  final VoidCallback onTap;

  const _ResultRow({
    required this.photo,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(children: [
          if (photo.isNotEmpty)
            ShimmerImage(url: photo, width: 54, height: 54,
                borderRadius: BorderRadius.circular(12))
          else
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.rust, AppColors.rustDark]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initials ?? '·',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withAlpha(26),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: accent),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FEATURED HERO — first live site, full-width, gradient overlay
// ═══════════════════════════════════════════════════════════════
class _FeaturedHero extends StatelessWidget {
  final Map<String, dynamic> site;
  final String lang;
  final VoidCallback onTap;
  const _FeaturedHero(
      {required this.site, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = localName(site, lang);
    final photo = sitePhoto(site);
    final location = (site['location'] ?? '') as String;
    final info = (site['info'] ?? '') as String;

    return _PressScale(
      onTap: onTap,
      child: Stack(children: [
        Hero(
          tag: 'site-${site['id']}',
          child: ShimmerImage(
            url: photo,
            height: 290,
            width: double.infinity,
            borderRadius: BorderRadius.circular(24),
            darkOverlay: true,
          ),
        ),
        Positioned(
          top: 16, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 13, color: AppColors.charcoal),
              const SizedBox(width: 4),
              Text(tr(lang, 'featured'),
                  style: const TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: 1.2)),
            ]),
          ),
        ),
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 26,
                    height: 1.15, letterSpacing: -0.6,
                    shadows: [Shadow(blurRadius: 12,
                        color: Colors.black54)])),
            const SizedBox(height: 6),
            if (info.isNotEmpty)
              Text(info,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFE8DFD0),
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              if (location.isNotEmpty) ...[
                const Icon(Icons.location_on,
                    size: 13, color: AppColors.gold),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFD8CDBC),
                          fontSize: 12)),
                ),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: Colors.white.withAlpha(90)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(tr(lang, 'explore'),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.white),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Timket Card — charcoal + rust + gold ──────────────────────
class _TimketCard extends StatelessWidget {
  final Duration remaining;
  final String lang;
  final String photo; // database image — admin controls it
  const _TimketCard(
      {required this.remaining, required this.lang, this.photo = ''});

  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2117), AppColors.charcoal],
        ),
        boxShadow: [BoxShadow(
            color: AppColors.charcoal.withAlpha(70),
            blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          // Photo background (from the database) with dark overlay
          if (photo.isNotEmpty)
            Positioned.fill(
              child: ShimmerImage(
                url: photo,
                borderRadius: BorderRadius.zero,
              ),
            ),
          if (photo.isNotEmpty)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.charcoal.withAlpha(150),
                      AppColors.charcoal.withAlpha(235),
                    ],
                  ),
                ),
              ),
            ),
          // Rust glow accent
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.rust.withAlpha(90),
                  AppColors.rust.withAlpha(0),
                ]),
              ),
            ),
          ),
          // Gold glow accent
          Positioned(
            bottom: -60, left: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withAlpha(50),
                  AppColors.gold.withAlpha(0),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.gold.withAlpha(80)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.celebration, size: 12, color: AppColors.gold),
                  SizedBox(width: 6),
                  Text('TIMKET 2027',
                      style: TextStyle(color: AppColors.gold,
                          fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                ]),
              ),
              const SizedBox(height: 12),
              Text(tr(lang, 'timket_title'),
                  style: const TextStyle(color: Color(0xFFFBF7F0),
                      fontSize: 23,
                      fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text(tr(lang, 'timket_sub'),
                  style: const TextStyle(color: Color(0xFFB3A899),
                      fontSize: 13, height: 1.4)),
              const SizedBox(height: 18),
              Row(children: [
                _countBox('$days', tr(lang, 'days')),
                _colon(),
                _countBox(hours.toString().padLeft(2, '0'),
                    tr(lang, 'hrs')),
                _colon(),
                _countBox(mins.toString().padLeft(2, '0'),
                    tr(lang, 'min')),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _colon() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Text(':', style: TextStyle(color: Color(0xFF7A6E5F),
        fontSize: 24, fontWeight: FontWeight.w300)),
  );

  Widget _countBox(String val, String label) => Column(children: [
    Text(val, style: const TextStyle(color: AppColors.gold,
        fontSize: 32, fontWeight: FontWeight.w800, height: 1)),
    const SizedBox(height: 3),
    Text(label, style: const TextStyle(color: Color(0xFF8A7E70),
        fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
  ]);
}

// ── Quick Link ────────────────────────────────────────────────
class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.surfaceVariant),
            boxShadow: [BoxShadow(
                color: AppColors.charcoal.withAlpha(10),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: AppColors.rust, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.charcoal)),
      ]),
    );
  }
}

// ── Site Card (live data) ─────────────────────────────────────
class _SiteCard extends StatelessWidget {
  final Map<String, dynamic> site;
  final String lang;
  final VoidCallback onTap;
  const _SiteCard(
      {required this.site, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = localName(site, lang);
    final photo = sitePhoto(site);
    final location = (site['location'] ?? '') as String;

    return _PressScale(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 14),
        child: Stack(children: [
          ShimmerImage(
            url: photo,
            width: 180, height: 235,
            borderRadius: BorderRadius.circular(20),
            darkOverlay: true,
          ),
          Positioned(
            bottom: 14, left: 14, right: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 15.5, height: 1.2,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)])),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on,
                    size: 11, color: AppColors.gold),
                const SizedBox(width: 3),
                Expanded(child: Text(location,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFD8CDBC), fontSize: 11))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Hotel Mini Card (live data) ───────────────────────────────
class _HotelMiniCard extends StatelessWidget {
  final Map<String, dynamic> hotel;
  final String lang;
  final VoidCallback onTap;
  const _HotelMiniCard(
      {required this.hotel, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = localName(hotel, lang);
    final photo = hotelPhoto(hotel);
    final price = hotelPrice(hotel);
    final stars = hotelStars(hotel);

    return _PressScale(
      onTap: onTap,
      child: Container(
        width: 175,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(children: [
          Hero(
            tag: 'hotel-${hotel['id']}',
            child: ShimmerImage(
              url: photo,
              width: 175, height: 170,
              borderRadius: BorderRadius.circular(18),
              darkOverlay: true,
            ),
          ),
          // price chip
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('\$${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.charcoal, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          Positioned(
            bottom: 12, left: 12, right: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)])),
              const SizedBox(height: 3),
              Row(children: List.generate(5, (i) => Icon(
                Icons.star_rounded,
                size: 11,
                color: i < stars
                    ? AppColors.gold
                    : Colors.white.withAlpha(70),
              ))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Press-scale wrapper: gentle 0.97 scale on press, 150ms ────
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});
  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
