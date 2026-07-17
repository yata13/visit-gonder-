import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  LIVE TIMKET MODE — during Jan 18–20 the home card transforms
//  into a live festival dashboard: what is happening right now,
//  where to stand, and what comes next.
//  Long-press the Timket card to toggle DEMO mode any day.
// ═══════════════════════════════════════════════════════════════

class TimketPhase {
  final DateTime start, end;
  final String titleEn, titleAm;
  final String locationEn, locationAm;
  final String standEn, standAm;
  const TimketPhase({
    required this.start,
    required this.end,
    required this.titleEn,
    required this.titleAm,
    required this.locationEn,
    required this.locationAm,
    required this.standEn,
    required this.standAm,
  });

  String title(String lang) => isAm(lang) ? titleAm : titleEn;
  String location(String lang) => isAm(lang) ? locationAm : locationEn;
  String stand(String lang) => isAm(lang) ? standAm : standEn;
}

/// Festival year — the next Timket.
const int kTimketYear = 2027;

final List<TimketPhase> kTimketProgram = [
  TimketPhase(
    start: DateTime(kTimketYear, 1, 18, 15),
    end: DateTime(kTimketYear, 1, 18, 18),
    titleEn: 'Ketera — Tabots arriving at Fasilides Bath',
    titleAm: 'ከተራ — ታቦታት ወደ ፋሲለደስ መታጠቢያ እየገቡ ነው',
    locationEn: 'Procession routes → Fasilides Bath',
    locationAm: 'የሰልፍ መንገዶች → ፋሲለደስ መታጠቢያ',
    standEn:
        'Stand along the Piazza–Bath route for the processions. Arrive by 2:30 PM for a front spot.',
    standAm:
        'ሰልፉን ለማየት ከፒያሳ እስከ መታጠቢያው ባለው መንገድ ላይ ይቁሙ። ከ8:30 ሰዓት በፊት ይድረሱ።',
  ),
  TimketPhase(
    start: DateTime(kTimketYear, 1, 18, 18),
    end: DateTime(kTimketYear, 1, 19, 6),
    titleEn: 'Overnight vigil at the Bath',
    titleAm: 'በመታጠቢያው የሌሊት ጸሎት',
    locationEn: 'Fasilides Bath compound',
    locationAm: 'የፋሲለደስ መታጠቢያ ግቢ',
    standEn:
        'Chanting and prayers all night. The compound is candle-lit — one of the most beautiful moments of the festival.',
    standAm:
        'ሌሊቱን ሙሉ ዝማሬና ጸሎት ይካሄዳል። ግቢው በሻማ ብርሃን ያበራል።',
  ),
  TimketPhase(
    start: DateTime(kTimketYear, 1, 19, 6),
    end: DateTime(kTimketYear, 1, 19, 9),
    titleEn: 'Water Blessing — the peak of Timket',
    titleAm: 'የውሃ ቡራኬ — የጥምቀት ከፍተኛው ሥነ ሥርዓት',
    locationEn: 'Fasilides Bath',
    locationAm: 'ፋሲለደስ መታጠቢያ',
    standEn:
        'South bank of the pool has the best view. Arrive before 5:00 AM — it fills up fast.',
    standAm:
        'የመታጠቢያው ደቡብ ዳርቻ ምርጥ እይታ አለው። ከ11:00 ሰዓት ሌሊት በፊት ይድረሱ።',
  ),
  TimketPhase(
    start: DateTime(kTimketYear, 1, 19, 9),
    end: DateTime(kTimketYear, 1, 19, 20),
    titleEn: 'City-wide celebrations',
    titleAm: 'በከተማው ሁሉ በዓል',
    locationEn: 'All over Gondar',
    locationAm: 'በመላው ጎንደር',
    standEn:
        'Music, dancing and feasts across the city. Piazza and the Royal Enclosure area are liveliest.',
    standAm:
        'ሙዚቃ፣ ጭፈራና ግብዣ በመላው ከተማ። ፒያሳ እና ፋሲል ግቢ አካባቢ በጣም ደማቅ ናቸው።',
  ),
  TimketPhase(
    start: DateTime(kTimketYear, 1, 20, 8),
    end: DateTime(kTimketYear, 1, 20, 12),
    titleEn: 'Kana Ze Galila — return processions',
    titleAm: 'ቃና ዘገሊላ — የመመለሻ ሰልፍ',
    locationEn: 'Jan Meda & church routes',
    locationAm: 'ጃን ሜዳ እና የቤተ ክርስቲያን መንገዶች',
    standEn:
        'Follow the Tabots back to their churches — joyous music and dancing the whole way.',
    standAm:
        'ታቦታቱን ወደ ቤተ ክርስቲያናቸው ሲመለሱ ይከተሉ — ደስታና ዝማሬ በመንገዱ ሁሉ።',
  ),
];

/// True during the real festival days.
bool isTimketLive(DateTime now) =>
    !now.isBefore(DateTime(kTimketYear, 1, 18)) &&
    now.isBefore(DateTime(kTimketYear, 1, 21));

/// In demo mode we pretend it is Ketera afternoon, so the dashboard
/// shows a "happening now" phase and a countdown to the blessing.
final DateTime kDemoNow = DateTime(kTimketYear, 1, 18, 15, 45);

class TimketLiveDashboard extends StatefulWidget {
  final String lang;
  final bool demo;
  final VoidCallback onOpenMap, onOpenSchedule;
  const TimketLiveDashboard({
    super.key,
    required this.lang,
    required this.demo,
    required this.onOpenMap,
    required this.onOpenSchedule,
  });

  @override
  State<TimketLiveDashboard> createState() => _TimketLiveDashboardState();
}

class _TimketLiveDashboardState extends State<TimketLiveDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final Timer _tick = Timer.periodic(
      const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });

  @override
  void dispose() {
    _pulse.dispose();
    _tick.cancel();
    super.dispose();
  }

  DateTime get _now => widget.demo ? kDemoNow : DateTime.now();

  TimketPhase? get _current {
    final n = _now;
    for (final p in kTimketProgram) {
      if (!n.isBefore(p.start) && n.isBefore(p.end)) return p;
    }
    return null;
  }

  TimketPhase? get _next {
    final n = _now;
    for (final p in kTimketProgram) {
      if (n.isBefore(p.start)) return p;
    }
    return null;
  }

  String _countdown(Duration d, String lang) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0) return isAm(lang) ? 'በ$h ሰ $m ደ' : 'in ${h}h ${m}m';
    return isAm(lang) ? 'በ$m ደቂቃ' : 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final current = _current;
    final next = _next;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38150A), Color(0xFF1C1410)],
        ),
        border: Border.all(color: const Color(0xFF7A2F12)),
        boxShadow: [BoxShadow(
            color: AppColors.rust.withAlpha(70),
            blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── LIVE badge row ──
        Row(children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                  color: Color(0xFFFF5347), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isAm(lang) ? 'ቀጥታ · የጥምቀት በዓል' : 'LIVE · TIMKET FESTIVAL',
            style: const TextStyle(color: Color(0xFFFF8A7E),
                fontSize: 11, fontWeight: FontWeight.w800,
                letterSpacing: 1.4),
          ),
          const Spacer(),
          if (widget.demo)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(34),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.gold.withAlpha(90)),
              ),
              child: const Text('DEMO',
                  style: TextStyle(color: AppColors.gold, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
        ]),
        const SizedBox(height: 14),

        // ── Happening now ──
        if (current != null) ...[
          Text(isAm(lang) ? 'አሁን እየተካሄደ ያለ' : 'HAPPENING NOW',
              style: const TextStyle(color: AppColors.gold, fontSize: 10.5,
                  fontWeight: FontWeight.w800, letterSpacing: 1.6)),
          const SizedBox(height: 6),
          Text(current.title(lang),
              style: const TextStyle(color: Color(0xFFFBF7F0),
                  fontSize: 20, fontWeight: FontWeight.w800,
                  height: 1.25, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on,
                size: 13, color: AppColors.gold),
            const SizedBox(width: 4),
            Expanded(
              child: Text(current.location(lang),
                  style: const TextStyle(color: Color(0xFFD8CDBC),
                      fontSize: 12.5)),
            ),
          ]),
          const SizedBox(height: 12),

          // Where to stand
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withAlpha(70)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 17, color: AppColors.gold),
              const SizedBox(width: 9),
              Expanded(
                child: Text(current.stand(lang),
                    style: const TextStyle(color: Color(0xFFEFE6D8),
                        fontSize: 12.5, height: 1.5)),
              ),
            ]),
          ),
        ],

        // ── Next up ──
        if (next != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.schedule,
                size: 14, color: Color(0xFF8A7E70)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${isAm(lang) ? 'ቀጣይ' : 'Next'}: ${next.title(lang)} · ${_countdown(next.start.difference(_now), lang)}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFB3A899),
                    fontSize: 12.5, fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 16),

        // ── Actions ──
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onOpenMap,
              icon: const Icon(Icons.map_outlined, size: 16),
              label: Text(isAm(lang) ? 'ካርታ ክፈት' : 'Open Map',
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onOpenSchedule,
              icon: const Icon(Icons.event_note_outlined, size: 16),
              label: Text(
                  isAm(lang) ? 'ሙሉ መርሃ ግብር' : 'Full schedule',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEFE6D8),
                side: const BorderSide(color: Color(0xFF5A4A3A)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
