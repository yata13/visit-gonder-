import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../hotels/hotels_screen.dart';
import '../guides/guide_profile_screen.dart';
import '../timket/timket_roadmap.dart';

// ═══════════════════════════════════════════════════════════════
//  TRIP PLANNER — the visitor answers 3 questions and the app
//  builds a full day-by-day Gondar plan from the LIVE data
//  (sites, hotels, guides). No idea needed — it does the thinking.
// ═══════════════════════════════════════════════════════════════
class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key});
  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  int _days = 2;
  final Set<String> _interests = {'history'};
  String _budget = 'mid';
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => _built
                    ? setState(() => _built = false)
                    : Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppColors.charcoal),
                ),
              ),
              const SizedBox(width: 14),
              Text(am ? 'የጉዞ እቅድ' : 'Trip Planner',
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _built
                ? _PlanResult(
                    days: _days,
                    interests: _interests,
                    budget: _budget,
                    lang: lang,
                  )
                : _questions(am, lang),
          ),
        ]),
      ),
    );
  }

  Widget _questions(bool am, String lang) {
    final interestOptions = <String, (IconData, String)>{
      'history': (Icons.account_balance, am ? 'ታሪክ' : 'History & castles'),
      'festival': (Icons.celebration, am ? 'በዓላት' : 'Festivals'),
      'nature': (Icons.landscape, am ? 'ተፈጥሮ' : 'Nature & mountains'),
      'food': (Icons.restaurant, am ? 'ምግብ' : 'Food & culture'),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text(am
                ? 'ምን ማየት እንደሚፈልጉ ይንገሩን — እኛ እቅዱን እንሰራለን።'
                : 'Tell us what you like — we build the plan for you.',
            style: const TextStyle(fontSize: 14,
                color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 22),

        // Q1 — days
        _qLabel(am ? '1 · ስንት ቀን ይቆያሉ?' : '1 · How many days?'),
        const SizedBox(height: 10),
        Row(children: List.generate(5, (i) {
          final d = i + 1;
          final sel = _days == d;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _days = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.charcoal : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel
                      ? AppColors.charcoal : AppColors.surfaceVariant),
                ),
                child: Center(child: Text('$d',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: sel ? AppColors.gold : AppColors.charcoal))),
              ),
            ),
          );
        })),
        const SizedBox(height: 26),

        // Q2 — interests (multi)
        _qLabel(am ? '2 · ምን ይወዳሉ? (ብዙ ይምረጡ)'
                   : '2 · What do you enjoy? (pick any)'),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10,
          children: interestOptions.entries.map((e) {
            final sel = _interests.contains(e.key);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  if (_interests.length > 1) _interests.remove(e.key);
                } else {
                  _interests.add(e.key);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: sel ? AppColors.rust.withAlpha(26) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel
                      ? AppColors.rust : AppColors.surfaceVariant),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.value.$1, size: 16,
                      color: sel ? AppColors.rust : AppColors.textMuted),
                  const SizedBox(width: 7),
                  Text(e.value.$2, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? AppColors.rust : AppColors.textSecondary)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),

        // Q3 — budget
        _qLabel(am ? '3 · የበጀት መጠን?' : '3 · Your budget?'),
        const SizedBox(height: 10),
        Row(children: [
          _budgetChip('budget', am ? 'ቆጣቢ' : 'Budget', '\$'),
          const SizedBox(width: 8),
          _budgetChip('mid', am ? 'መካከለኛ' : 'Mid', '\$\$'),
          const SizedBox(width: 8),
          _budgetChip('luxury', am ? 'የቅንጦት' : 'Luxury', '\$\$\$'),
        ]),
        const SizedBox(height: 32),

        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _built = true),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(am ? 'እቅዴን ይገንቡ' : 'Build My Plan',
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _qLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800,
          color: AppColors.charcoal));

  Widget _budgetChip(String val, String label, String marks) {
    final sel = _budget == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _budget = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? AppColors.charcoal : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel
                ? AppColors.charcoal : AppColors.surfaceVariant),
          ),
          child: Column(children: [
            Text(marks, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800,
                color: sel ? AppColors.gold : AppColors.charcoal)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5,
                color: sel ? const Color(0xFFD8CDBC) : AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

// ── Plan result — built from live data ────────────────────────
class _PlanResult extends ConsumerWidget {
  final int days;
  final Set<String> interests;
  final String budget;
  final String lang;
  const _PlanResult({
    required this.days,
    required this.interests,
    required this.budget,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(lang);
    final sites = [...(ref.watch(sitesProvider).value ?? const [])];
    final hotels = [...(ref.watch(hotelsProvider).value ?? const [])];
    final guides = [...(ref.watch(guidesProvider).value ?? const [])];

    // Pick a hotel by budget.
    hotels.sort((a, b) => hotelPrice(a).compareTo(hotelPrice(b)));
    Map<String, dynamic>? hotel;
    if (hotels.isNotEmpty) {
      hotel = switch (budget) {
        'budget' => hotels.first,
        'luxury' => hotels.last,
        _ => hotels[hotels.length ~/ 2],
      };
    }

    // Pick a guide (cheapest for budget, else first licensed).
    guides.sort((a, b) =>
        ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));
    final guide = guides.isEmpty
        ? null
        : (budget == 'budget' ? guides.first : guides.last);

    final wantsFestival = interests.contains('festival');
    final wantsNature = interests.contains('nature');
    final wantsFood = interests.contains('food');

    // Spread sites ~2 per day.
    final perDay = <List<Map<String, dynamic>>>[];
    if (sites.isNotEmpty) {
      int idx = 0;
      for (int d = 0; d < days; d++) {
        final dayItems = <Map<String, dynamic>>[];
        for (int k = 0; k < 2; k++) {
          dayItems.add(sites[idx % sites.length]);
          idx++;
        }
        perDay.add(dayItems);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
      physics: const BouncingScrollPhysics(),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1D14), AppColors.charcoal]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(am ? 'የእርስዎ የጎንደር እቅድ' : 'Your Gondar Plan',
                  style: const TextStyle(color: Color(0xFFFBF7F0),
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(
              '$days ${am ? 'ቀን' : (days == 1 ? 'day' : 'days')} · '
              '${budget == 'budget' ? (am ? 'ቆጣቢ' : 'Budget') : budget == 'luxury' ? (am ? 'የቅንጦት' : 'Luxury') : (am ? 'መካከለኛ' : 'Mid-range')}',
              style: const TextStyle(color: Color(0xFFB3A899), fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 18),

        // Day-by-day
        for (int d = 0; d < perDay.length; d++) ...[
          _dayCard(context, d + 1, perDay[d], am,
              // Timket note on day 1 if festival interest
              extraNote: (d == 0 && wantsFestival)
                  ? (am
                      ? 'የጥምቀት በዓል ካለ — ወደ ፋሲለደስ መታጠቢያ ይሂዱ።'
                      : 'If it is Timket season, head to Fasilides Bath for the festival.')
                  : (d == perDay.length - 1 && wantsNature)
                      ? (am
                          ? 'የቀን ጉዞ፡ ስሜን ተራራዎች (ከጎንደር 100 ኪሜ)።'
                          : 'Day trip option: Simien Mountains (100km from Gondar).')
                      : wantsFood
                          ? (am
                              ? 'ምሽት፡ ባህላዊ እንጀራና ዶሮ ወጥ ይቅመሱ።'
                              : 'Evening: try cultural injera & doro wat at a local restaurant.')
                          : null,
              showTimketLink: d == 0 && wantsFestival),
        ],

        // Where to stay
        if (hotel != null) ...[
          const SizedBox(height: 4),
          _sectionTitle(am ? 'የሚቆዩበት' : 'Where to stay'),
          const SizedBox(height: 10),
          _suggestCard(
            title: hotelName(hotel),
            subtitle: '\$${hotelPrice(hotel).toStringAsFixed(0)}'
                '${am ? '/ሌሊት' : '/night'} · ${'★' * hotelStars(hotel)}',
            icon: Icons.hotel,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => HotelDetailPage(hotel: hotel!))),
          ),
        ],

        // Recommended guide
        if (guide != null) ...[
          const SizedBox(height: 18),
          _sectionTitle(am ? 'የሚመከር መመሪያ' : 'Recommended guide'),
          const SizedBox(height: 10),
          _suggestCard(
            title: (guide['name'] ?? '') as String,
            subtitle: '\$${((guide['price'] ?? 0) as num).toStringAsFixed(0)}'
                '${am ? '/ቀን' : '/day'} · ${(guide['specialty'] ?? '') as String}',
            icon: Icons.person_pin,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => GuideProfileScreen(guide: guide!))),
          ),
        ],

        if (sites.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(am
                    ? 'ቦታዎች በአስተዳዳሪው ሲጨመሩ እቅዱ የተሟላ ይሆናል።'
                    : 'Add sites in the admin and the plan fills out fully.',
                style: const TextStyle(color: AppColors.textMuted)),
          ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: AppColors.charcoal, letterSpacing: -0.3));

  Widget _dayCard(BuildContext context, int day,
      List<Map<String, dynamic>> sites, bool am,
      {String? extraNote, bool showTimketLink = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(12),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Text('${am ? 'ቀን' : 'Day'} $day',
                style: const TextStyle(color: AppColors.gold,
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            if (day == 1)
              Text(am ? 'መድረስ እና ማረፊያ' : 'Arrive & settle in',
                  style: const TextStyle(color: Color(0xFFB3A899),
                      fontSize: 11.5)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            ...sites.asMap().entries.map((e) {
              final s = e.value;
              final label = e.key == 0
                  ? (am ? 'ጥዋት' : 'Morning')
                  : (am ? 'ከሰዓት' : 'Afternoon');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(label, style: const TextStyle(fontSize: 11,
                        color: AppColors.rust, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.account_balance,
                      size: 15, color: AppColors.goldDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text(localName(s, lang),
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal))),
                ]),
              );
            }),
            if (extraNote != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      size: 15, color: AppColors.goldDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text(extraNote,
                      style: const TextStyle(fontSize: 12.5,
                          color: AppColors.textSecondary, height: 1.4))),
                ]),
              ),
            ],
            if (showTimketLink) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TimketRoadmapScreen(lang: lang))),
                child: Row(children: [
                  Text(am ? 'የጥምቀት መንገድ ካርታ ይክፈቱ'
                          : 'Open the Timket roadmap',
                      style: const TextStyle(color: AppColors.rust,
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 13, color: AppColors.rust),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _suggestCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(36),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.goldDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: AppColors.charcoal)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
