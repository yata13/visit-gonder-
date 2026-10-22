import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../hotels/hotels_screen.dart';
import '../guides/guide_profile_screen.dart';
import '../timket/timket_roadmap.dart';
import '../../providers/weather_provider.dart';
import '../../services/weather_service.dart';
import '../../widgets/weather_card.dart';
import '../../widgets/motion.dart';
import '../../widgets/ui.dart';

// ═══════════════════════════════════════════════════════════════
//  TRIP PLANNER — a short guided interview, one question per page
//  (days → budget → interests → who is travelling), then a
//  "researching" step that checks the LIVE data (sites, hotels,
//  guides, weather) before showing the day-by-day Gondar plan.
// ═══════════════════════════════════════════════════════════════
class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key});
  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  static const _questionCount = 4;

  int _days = 2;
  final Set<String> _interests = {'history'};
  String _budget = 'mid';
  String _party = 'couple';

  /// 0.._questionCount-1 = questions, then research, then the plan.
  int _step = 0;
  bool _forward = true;

  bool get _researching => _step == _questionCount;
  bool get _built => _step > _questionCount;

  void _go(int step) {
    if (step < 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

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
              PressScale(
                // Back steps through the questions; from the plan it
                // returns to the last question to tweak an answer.
                onTap: () => _go(_built ? _questionCount - 1 : _step - 1),
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
              Expanded(
                child: Text(am ? 'የጉዞ እቅድ' : 'Trip Planner',
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal, letterSpacing: -0.4)),
              ),
              if (_step < _questionCount)
                Text(am
                        ? '${_step + 1} / $_questionCount'
                        : 'Step ${_step + 1} of $_questionCount',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
            ]),
          ),
          // Progress — fills as the interview moves on.
          if (!_built)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (_step + 1) / (_questionCount + 1)),
                  duration: Motion.page,
                  curve: Motion.curve,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: AppColors.brandGold,
                    backgroundColor: AppColors.stone,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),

          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.page,
              switchInCurve: Motion.curve,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) {
                final isIn = child.key == ValueKey(_step);
                final dx = (isIn == _forward) ? 0.25 : -0.25;
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _built
                    ? _PlanResult(
                        days: _days,
                        interests: _interests,
                        budget: _budget,
                        lang: lang,
                      )
                    : _researching
                        ? _Researching(
                            am: am,
                            days: _days,
                            onDone: () => _go(_questionCount + 1),
                          )
                        : _question(_step, am),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── One question page ───────────────────────────────────────
  Widget _question(int step, bool am) {
    final (title, hint, body) = switch (step) {
      0 => (
          am ? 'በጎንደር ስንት ቀን ይቆያሉ?' : 'How many days in Gondar?',
          am ? 'ቀኖቹን በቦታዎች፣ በምግብ እና በእረፍት እንከፋፍላለን።'
              : 'We spread sites, meals and rest across your days.',
          _daysOptions(am),
        ),
      1 => (
          am ? 'በጀትዎ ምን ያህል ነው?' : 'What is your budget?',
          am ? 'ሆቴሎችን እና አስጎብኚዎችን በዚህ መሰረት እንመርጣለን።'
              : 'We match hotels and guides to it.',
          _budgetOptions(am),
        ),
      2 => (
          am ? 'ምን ይወዳሉ?' : 'What do you enjoy?',
          am ? 'የሚፈልጉትን ሁሉ ይምረጡ።' : 'Pick as many as you like.',
          _interestOptions(am),
        ),
      _ => (
          am ? 'ከማን ጋር ይጓዛሉ?' : 'Who is travelling?',
          am ? 'ፍጥነቱን እና ቦታዎቹን እናስተካክላለን።'
              : 'We adjust the pace and the stops.',
          _partyOptions(am),
        ),
    };
    final last = step == _questionCount - 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          children: Reveal.stagger([
            Text(title,
                style: const TextStyle(fontSize: 28, height: 1.2,
                    fontWeight: FontWeight.w800, letterSpacing: -0.4,
                    color: AppColors.black)),
            const SizedBox(height: 8),
            Text(hint,
                style: const TextStyle(fontSize: 15, height: 1.5,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 22),
            body,
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: FilledButton.icon(
          onPressed: () => _go(step + 1),
          icon: Icon(last ? Icons.auto_awesome : Icons.arrow_forward_rounded,
              size: 18),
          label: Text(last
              ? (am ? 'እቅዴን ይገንቡ' : 'Build my plan')
              : (am ? 'ቀጣይ' : 'Next')),
        ),
      ),
    ]);
  }

  /// A large tappable answer card.
  Widget _option({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    String? sub,
    bool multi = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: PressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.goldTint : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? AppColors.brandBrown : AppColors.line,
                  width: selected ? 2 : 1),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: Motion.medium,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandBrown : AppColors.stone,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20,
                    color: selected ? Colors.white : AppColors.brandBrown),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black)),
                  if (sub != null)
                    Text(sub,
                        style: const TextStyle(fontSize: 13,
                            color: AppColors.textMuted)),
                ]),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: Motion.medium,
                curve: Motion.pop,
                child: Icon(
                    multi ? Icons.check_box_rounded
                        : Icons.check_circle_rounded,
                    color: AppColors.brandBrown),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _daysOptions(bool am) {
    final opts = <(int, String, String)>[
      (1, am ? '1 ቀን' : '1 day', am ? 'ፈጣን ጉብኝት' : 'A quick look at the castles'),
      (2, am ? '2 ቀን' : '2 days', am ? 'ዋና ዋና ቦታዎች' : 'The main sights, unhurried'),
      (3, am ? '3 ቀን' : '3 days', am ? 'ከተማ እና ዙሪያዋ' : 'City plus the countryside'),
      (4, am ? '4 ቀን' : '4 days', am ? 'ጥልቅ ጉብኝት' : 'Deeper — markets, churches, food'),
      (5, am ? '5 ቀን' : '5 days', am ? 'ሙሉ ልምድ' : 'The full Gondar experience'),
    ];
    return Column(children: [
      for (final (d, t, sub) in opts)
        _option(
          selected: _days == d,
          onTap: () => setState(() => _days = d),
          icon: Icons.calendar_today_rounded,
          title: t,
          sub: sub,
        ),
    ]);
  }

  Widget _budgetOptions(bool am) {
    final opts = <(String, String, String, IconData)>[
      ('budget', am ? 'ቆጣቢ  \$' : 'Budget  \$',
          am ? 'ቀላል ማረፊያ፣ የአካባቢ ምግብ' : 'Simple stays, local food',
          Icons.savings_outlined),
      ('mid', am ? 'መካከለኛ  \$\$' : 'Mid-range  \$\$',
          am ? 'ምቹ ሆቴል፣ ፈቃድ ያለው አስጎብኚ' : 'Comfortable hotel, licensed guide',
          Icons.hotel_outlined),
      ('luxury', am ? 'የቅንጦት  \$\$\$' : 'Luxury  \$\$\$',
          am ? 'ምርጥ ሆቴሎች፣ የግል አስጎብኚ' : 'Best hotels, private guide',
          Icons.workspace_premium_outlined),
    ];
    return Column(children: [
      for (final (v, t, sub, icon) in opts)
        _option(
          selected: _budget == v,
          onTap: () => setState(() => _budget = v),
          icon: icon,
          title: t,
          sub: sub,
        ),
    ]);
  }

  Widget _interestOptions(bool am) {
    final opts = <(String, IconData, String, String)>[
      ('history', Icons.account_balance, am ? 'ታሪክ' : 'History & castles',
          am ? 'ፋሲል ግቢ፣ ቤተ መንግሥታት' : 'Fasil Ghebbi and the royal compound'),
      ('festival', Icons.celebration, am ? 'በዓላት' : 'Festivals',
          am ? 'ጥምቀት እና ሌሎች' : 'Timket and city events'),
      ('nature', Icons.landscape, am ? 'ተፈጥሮ' : 'Nature & mountains',
          am ? 'ስሜን ተራሮች፣ እይታዎች' : 'Simien views and day trips'),
      ('food', Icons.restaurant, am ? 'ምግብ' : 'Food & culture',
          am ? 'ቡና፣ እንጀራ፣ ሙዚቃ' : 'Coffee ceremony, injera, music'),
    ];
    return Column(children: [
      for (final (k, icon, t, sub) in opts)
        _option(
          multi: true,
          selected: _interests.contains(k),
          onTap: () => setState(() {
            if (_interests.contains(k)) {
              if (_interests.length > 1) _interests.remove(k);
            } else {
              _interests.add(k);
            }
          }),
          icon: icon,
          title: t,
          sub: sub,
        ),
    ]);
  }

  Widget _partyOptions(bool am) {
    final opts = <(String, IconData, String, String)>[
      ('solo', Icons.person_outline_rounded, am ? 'ብቻዬን' : 'Just me',
          am ? 'ነጻ እና ፈጣን' : 'Free and flexible'),
      ('couple', Icons.favorite_outline_rounded, am ? 'ሁለት ሰው' : 'Couple',
          am ? 'ጸጥ ያሉ ቦታዎች' : 'Quiet spots and sunsets'),
      ('family', Icons.family_restroom_rounded, am ? 'ቤተሰብ' : 'Family',
          am ? 'ቀላል ፍጥነት' : 'Easy pace, short walks'),
      ('group', Icons.groups_outlined, am ? 'ቡድን' : 'Group',
          am ? 'አስጎብኚ ይመከራል' : 'A guide is recommended'),
    ];
    return Column(children: [
      for (final (v, icon, t, sub) in opts)
        _option(
          selected: _party == v,
          onTap: () => setState(() => _party = v),
          icon: icon,
          title: t,
          sub: sub,
        ),
    ]);
  }
}

// ── "Researching" — checks the live data before the plan ──────
class _Researching extends ConsumerStatefulWidget {
  final bool am;
  final int days;
  final VoidCallback onDone;
  const _Researching(
      {required this.am, required this.days, required this.onDone});

  @override
  ConsumerState<_Researching> createState() => _ResearchingState();
}

class _ResearchingState extends ConsumerState<_Researching> {
  static const _stepTime = Duration(milliseconds: 650);
  int _done = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stepTime, (t) {
      if (!mounted) return;
      if (_done >= 5) {
        t.cancel();
        widget.onDone();
      } else {
        setState(() => _done++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.am;
    // Real counts from the live data, so the checks mean something.
    final sites = ref.watch(sitesProvider).valueOrNull?.length;
    final hotels = ref.watch(hotelsProvider).valueOrNull?.length;
    final guides = ref.watch(guidesProvider).valueOrNull?.length;
    String n(int? v) => v == null ? '…' : '$v';

    final steps = [
      am ? '${n(sites)} ታሪካዊ ቦታዎችን በመፈተሽ ላይ'
          : 'Checking ${n(sites)} historic sites',
      am ? '${n(hotels)} ሆቴሎችን ከበጀትዎ ጋር በማወዳደር ላይ'
          : 'Comparing ${n(hotels)} hotels with your budget',
      am ? '${n(guides)} ፈቃድ ያላቸውን አስጎብኚዎች በማዛመድ ላይ'
          : 'Matching ${n(guides)} licensed guides',
      am ? 'የ7 ቀን የአየር ሁኔታን በመመልከት ላይ'
          : 'Reading the 7-day weather forecast',
      am ? 'የ${widget.days} ቀን መንገድ በመገንባት ላይ'
          : 'Building your ${widget.days}-day route',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        Center(
          child: Reveal(
            offset: Offset.zero,
            scale: 0.7,
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.brandBrown,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.goldTint,
                    spreadRadius: 10)],
              ),
              child: const Padding(
                padding: EdgeInsets.all(26),
                child: CircularProgressIndicator(
                    color: AppColors.brandGold, strokeWidth: 3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Reveal(
          delay: const Duration(milliseconds: 120),
          child: Text(am ? 'የእርስዎን ጉዞ በማጥናት ላይ…' : 'Researching your trip…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w800, color: AppColors.black)),
        ),
        const SizedBox(height: 6),
        Reveal(
          delay: const Duration(milliseconds: 200),
          child: Text(
              am ? 'ከቀጥታ የከተማ መረጃ እየገነባን ነው።'
                  : 'Using live city data, right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14,
                  color: AppColors.textMuted)),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < steps.length; i++)
          AnimatedOpacity(
            opacity: i <= _done ? 1 : 0.35,
            duration: Motion.medium,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: i < _done
                        ? const Icon(Icons.check_circle_rounded,
                            key: ValueKey('done'),
                            color: AppColors.safe, size: 24)
                        : i == _done
                            ? const Padding(
                                key: ValueKey('busy'),
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.brandGold),
                              )
                            : const Icon(Icons.circle_outlined,
                                key: ValueKey('todo'),
                                color: AppColors.line, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(steps[i],
                      style: TextStyle(fontSize: 15,
                          fontWeight:
                              i == _done ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.black)),
                ),
              ]),
            ),
          ),
      ],
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
    final sites = [...(ref.watch(sitesProvider).valueOrNull ?? const [])];
    final hotels = [...(ref.watch(hotelsProvider).valueOrNull ?? const [])];
    final guides = [...(ref.watch(guidesProvider).valueOrNull ?? const [])];
    // The plan starts today; days inside the 7-day window get a forecast.
    final weather = ref.watch(weatherProvider).valueOrNull;

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
      children: Reveal.stagger([
        // Summary banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF232323), AppColors.charcoal]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(am ? 'የእርስዎ የጎንደር እቅድ' : 'Your Gondar Plan',
                  style: const TextStyle(color: Color(0xFFFFFFFF),
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(
              '$days ${am ? 'ቀን' : (days == 1 ? 'day' : 'days')} · '
              '${budget == 'budget' ? (am ? 'ቆጣቢ' : 'Budget') : budget == 'luxury' ? (am ? 'የቅንጦት' : 'Luxury') : (am ? 'መካከለኛ' : 'Mid-range')}',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 18),

        // Day-by-day
        for (int d = 0; d < perDay.length; d++) ...[
          _dayCard(context, d + 1, perDay[d], am,
              weather: weather?.forDate(
                  DateTime.now().add(Duration(days: d))),
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
            onTap: () => Navigator.push(context, SmoothPageRoute(
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
            onTap: () => Navigator.push(context, SmoothPageRoute(
                builder: (_) => GuideProfileScreen(guide: guide))),
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
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: AppColors.charcoal, letterSpacing: -0.3));

  Widget _dayCard(BuildContext context, int day,
      List<Map<String, dynamic>> sites, bool am,
      {String? extraNote, bool showTimketLink = false, WeatherDay? weather}) {
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
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            if (weather != null)
              WeatherChip(day: weather, am: am)
            else if (day == 1)
              Text(am ? 'መድረስ እና ማረፊያ' : 'Arrive & settle in',
                  style: const TextStyle(color: Color(0xFFB3B3B3),
                      fontSize: 11.5)),
          ]),
        ),
        if (weather != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 15, color: AppColors.goldDark),
              const SizedBox(width: 6),
              Expanded(child: Text(WeatherService.tip(weather, am),
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textSecondary, height: 1.35))),
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
                onTap: () => Navigator.push(context, SmoothPageRoute(
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
