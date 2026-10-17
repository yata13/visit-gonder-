import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/nav.dart';
import '../../core/utils/ethiopian_date.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../../widgets/ui.dart';
import '../map/map_screen.dart';
import '../stay/stay_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  EXPLORE (tab 2) — design "Explore · list".
//  One searchable list with category chips: Sites, Hotels, Guides,
//  Bajaj, Events. "Map" opens the live map. All rows are LIVE from
//  the same tables the admin dashboard manages.
// ═══════════════════════════════════════════════════════════════
enum ExploreCategory { sites, hotels, guides, bajaj, events }

class ExploreScreen extends ConsumerStatefulWidget {
  final ExploreCategory initial;
  const ExploreScreen({super.key, this.initial = ExploreCategory.sites});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late ExploreCategory _cat = widget.initial;
  bool _showMap = true; // the map is the first thing visitors see
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _label(ExploreCategory c, bool am) => switch (c) {
        ExploreCategory.sites => am ? 'ቦታዎች' : 'Sites',
        ExploreCategory.hotels => am ? 'ሆቴሎች' : 'Hotels',
        ExploreCategory.guides => am ? 'አስጎብኚዎች' : 'Guides',
        ExploreCategory.bajaj => am ? 'ባጃጅ' : 'Bajaj',
        ExploreCategory.events => am ? 'ዝግጅቶች' : 'Events',
      };

  bool _matches(Map<String, dynamic> row) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [row['name_en'], row['name_am'], row['name'], row['location'],
            row['specialty'], row['info']]
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(
                  child: Text(am ? 'ያስሱ' : 'Explore',
                      style: const TextStyle(fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4)),
                ),
                _ViewToggle(
                  showMap: _showMap,
                  am: am,
                  onChanged: (v) => setState(() => _showMap = v),
                ),
              ]),
            ),
            if (_showMap) ...[
              const SizedBox(height: 12),
              const Expanded(
                child: ClipRect(child: MapScreen(embedded: true)),
              ),
            ] else ...[
            const SizedBox(height: 14),

            // ── Search ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchField(
                controller: _search,
                hint: am
                    ? 'ቤተ መንግሥት፣ ሆቴል፣ አስጎብኚ ይፈልጉ'
                    : 'Search castles, hotels, guides',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),

            // ── Category chips ───────────────────────────────
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ExploreCategory.values.map((c) {
                  final on = c == _cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      selected: on,
                      button: true,
                      child: PressScale(
                        onTap: () => setState(() => _cat = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: on
                              ? BoxDecoration(
                                  color: AppColors.ink,
                                  borderRadius: BorderRadius.circular(22))
                              : AppDecor.glass(radius: 22),
                          child: Text(_label(c, am),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      on ? FontWeight.w800 : FontWeight.w600,
                                  color: on ? Colors.white : AppColors.ink)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── List ─────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_cat),
                  child: _list(lang),
                ),
              ),
            ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _list(String lang) {
    final am = isAm(lang);
    switch (_cat) {
      case ExploreCategory.sites:
        return _AsyncList(
          error: am ? 'አልተጫነም — ኢንተርኔትዎን ያረጋግጡ'
              : 'Could not load — check your connection',
          async: ref.watch(sitesProvider),
          filter: _matches,
          count: (n) => am ? '$n ቦታዎች' : '$n places',
          empty: tr(lang, 'no_sites'),
          item: (s) => _ListCard(
            photo: sitePhoto(s),
            icon: Icons.castle_outlined,
            title: localName(s, lang),
            meta: [(s['info'] ?? '') as String,
                    (s['location'] ?? '') as String]
                .where((v) => v.isNotEmpty)
                .join(' · '),
            onTap: () => openSite(context, s, lang),
          ),
        );
      case ExploreCategory.hotels:
        return _AsyncList(
          error: am ? 'አልተጫነም — ኢንተርኔትዎን ያረጋግጡ'
              : 'Could not load — check your connection',
          async: ref.watch(hotelsProvider),
          filter: _matches,
          count: (n) => am ? '$n ሆቴሎች' : '$n hotels',
          empty: tr(lang, 'no_hotels'),
          item: (h) => _ListCard(
            photo: hotelPhoto(h),
            icon: Icons.hotel_outlined,
            title: localName(h, lang),
            verified: true,
            meta: [
              '${hotelStars(h)}★',
              (h['location'] ?? '') as String,
            ].where((v) => v.isNotEmpty).join(' · '),
            price: '\$${hotelPrice(h).toStringAsFixed(0)}'
                '${tr(lang, 'per_night')}',
            onTap: () => openHotel(context, h),
          ),
        );
      case ExploreCategory.guides:
        return _AsyncList(
          error: am ? 'አልተጫነም — ኢንተርኔትዎን ያረጋግጡ'
              : 'Could not load — check your connection',
          async: ref.watch(guidesProvider),
          filter: _matches,
          count: (n) => am ? '$n አስጎብኚዎች' : '$n guides',
          empty: am ? 'እስካሁን አስጎብኚ የለም' : 'No guides yet',
          item: (g) => _ListCard(
            photo: (g['photo'] ?? '') as String,
            icon: Icons.person_outline_rounded,
            title: (g['name'] ?? '') as String,
            verified: (g['license_status'] ?? '') == 'licensed',
            meta: (g['specialty'] ?? '') as String,
            price: '\$${((g['price'] ?? 0) as num).toStringAsFixed(0)}'
                '${tr(lang, 'per_day')}',
            onTap: () => openGuide(context, g),
          ),
        );
      case ExploreCategory.bajaj:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            PressScale(
              onTap: () =>
                  pushScreen(context, const StayScreen(initialTab: 1)),
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                        color: AppColors.ink, shape: BoxShape.circle),
                    child: const Icon(Icons.electric_rickshaw_outlined,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(am ? 'የባጃጅ አሽከርካሪዎች' : 'Bajaj drivers',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(am
                          ? 'ይደውሉ። ዋጋ ከመሳፈርዎ በፊት ይስማሙ።'
                          : 'Tap to call. Agree the fare before you ride.',
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ]),
              ),
            ),
          ],
        );
      case ExploreCategory.events:
        return _AsyncList(
          error: am ? 'አልተጫነም — ኢንተርኔትዎን ያረጋግጡ'
              : 'Could not load — check your connection',
          async: ref.watch(eventsProvider),
          filter: (e) =>
              _query.isEmpty ||
              ((e['name'] ?? '') as String)
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
          sort: (a, b) => (a['includes_timket'] == true ? 0 : 1)
              .compareTo(b['includes_timket'] == true ? 0 : 1),
          count: (n) => am ? '$n ዝግጅቶች' : '$n events',
          empty: am ? 'እስካሁን ዝግጅት የለም' : 'No events yet',
          item: (e) => _EventRow(event: e, am: am,
              onTap: () => openEvent(context, e, lang)),
        );
    }
  }
}

// ── Map / List switch ─────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  final bool showMap, am;
  final ValueChanged<bool> onChanged;
  const _ViewToggle(
      {required this.showMap, required this.am, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(bool map, IconData icon, String label) {
      final on = showMap == map;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(map),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18,
                  color: on ? Colors.white : AppColors.ink),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 14,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? Colors.white : AppColors.ink)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: AppDecor.glass(radius: 22),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option(true, Icons.map_outlined, am ? 'ካርታ' : 'Map'),
        option(false, Icons.view_list_rounded, am ? 'ዝርዝር' : 'List'),
      ]),
    );
  }
}

// ── Search field (glass pill) ─────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: AppDecor.glass(radius: 26),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15, color: AppColors.ink),
          decoration: InputDecoration(
            filled: false,
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.muted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}

// ── Generic async list with count + empty state ───────────────
class _AsyncList extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> async;
  final bool Function(Map<String, dynamic>) filter;
  final int Function(Map<String, dynamic>, Map<String, dynamic>)? sort;
  final String Function(int) count;
  final String empty, error;
  final Widget Function(Map<String, dynamic>) item;
  const _AsyncList({
    required this.error,
    required this.async,
    required this.filter,
    required this.count,
    required this.empty,
    required this.item,
    this.sort,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: List.generate(
            4,
            (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerImage(url: '', height: 112,
                      borderRadius: BorderRadius.all(Radius.circular(24))),
                )),
      ),
      error: (_, _) => EmptyNote(icon: Icons.cloud_off_rounded,
          title: error),
      data: (rows) {
        final list = rows.where(filter).toList();
        if (sort != null) list.sort(sort);
        if (list.isEmpty) {
          return ListView(children: [
            EmptyNote(icon: Icons.search_off_rounded, title: empty),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(count(list.length),
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: item(list[i - 1]),
            );
          },
        );
      },
    );
  }
}

// ── Row card: photo left, text right ──────────────────────────
class _ListCard extends StatelessWidget {
  final String photo, title, meta;
  final String? price;
  final IconData icon;
  final bool verified;
  final VoidCallback onTap;
  const _ListCard({
    required this.photo,
    required this.icon,
    required this.title,
    required this.meta,
    required this.onTap,
    this.price,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppDecor.glass(radius: 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 96,
            height: 96,
            child: photo.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.stone,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, size: 32, color: const Color(0xFF8C8C8C)),
                  )
                : ShimmerImage(url: photo, width: 96, height: 96,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800, height: 1.25)),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedTick(size: 16),
                  ],
                ]),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13,
                          color: AppColors.muted)),
                ],
                if (price != null) ...[
                  const SizedBox(height: 6),
                  Text(price!,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.chevron_right_rounded,
                color: AppColors.muted),
          ),
        ]),
      ),
    );
  }
}

// ── Event row: calendar block + both calendars ─────────────────
class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool am;
  final VoidCallback onTap;
  const _EventRow({required this.event, required this.am, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (event['name'] ?? '') as String;
    final rawDate = (event['date'] ?? '') as String;
    final date = DateTime.tryParse(rawDate);
    final isTimket = event['includes_timket'] == true;
    final (line1, line2) = date != null ? dualDate(date, am) : (rawDate, '');

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: isTimket
            ? AppDecor.night(radius: 24)
            : AppDecor.glass(radius: 24),
        child: Row(children: [
          Container(
            width: 56,
            height: 60,
            decoration: BoxDecoration(
              color: isTimket ? Colors.white : AppColors.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text(date != null
                  ? (am ? EthDate.fromGregorian(date).monthName(true)
                      : _mon(date.month))
                  : '—',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isTimket ? AppColors.ink : Colors.white)),
              Text(date != null
                  ? '${am ? EthDate.fromGregorian(date).day : date.day}'
                  : '',
                  style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800, height: 1.1,
                      color: isTimket ? AppColors.ink : Colors.white)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isTimket ? Colors.white : AppColors.ink)),
              const SizedBox(height: 3),
              Text(line1,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: isTimket
                          ? const Color(0xFFE6E6E6)
                          : AppColors.ink700)),
              if (line2.isNotEmpty)
                Text(line2,
                    style: TextStyle(fontSize: 13,
                        color: isTimket
                            ? AppColors.onDarkMuted
                            : AppColors.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: isTimket ? Colors.white : AppColors.muted),
        ]),
      ),
    );
  }

  static String _mon(int m) => const [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ][m - 1];
}
