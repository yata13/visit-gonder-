import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import 'timket_live.dart';

// ═══════════════════════════════════════════════════════════════
//  TIMKET ROADMAP — every moment of the festival as a timeline,
//  so a visitor can follow the whole program: what, when, where,
//  and where to stand for the best view.
// ═══════════════════════════════════════════════════════════════
class TimketRoadmapScreen extends StatelessWidget {
  final String lang;
  const TimketRoadmapScreen({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final am = isAm(lang);
    final fmt = DateFormat('MMM d · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.charcoal,
            leading: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Fasilides_Bath_Gondar_Ethiopia.jpg/800px-Fasilides_Bath_Gondar_Ethiopia.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.charcoal),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x551C1410), Color(0xF21C1410)],
                    ),
                  ),
                ),
                Positioned(
                  left: 20, right: 20, bottom: 18,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.rust,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(am ? 'ጥር 18–20' : 'January 18–20',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10.5, fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    Text(am ? 'የጥምቀት መንገድ ካርታ' : 'Timket Roadmap',
                        style: const TextStyle(color: Color(0xFFFBF7F0),
                            fontSize: 28, fontWeight: FontWeight.w900,
                            letterSpacing: -0.6)),
                  ]),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _MomentTile(
                  phase: kTimketProgram[i],
                  lang: lang,
                  fmt: fmt,
                  isFirst: i == 0,
                  isLast: i == kTimketProgram.length - 1,
                  index: i + 1,
                ),
                childCount: kTimketProgram.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentTile extends StatelessWidget {
  final TimketPhase phase;
  final String lang;
  final DateFormat fmt;
  final bool isFirst, isLast;
  final int index;
  const _MomentTile({
    required this.phase,
    required this.lang,
    required this.fmt,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Timeline rail ──
        Column(children: [
          Container(width: 2, height: 6,
              color: isFirst ? Colors.transparent : const Color(0xFF5A4A3A)),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.charcoal, width: 3),
            ),
            child: Center(
              child: Text('$index',
                  style: const TextStyle(color: AppColors.charcoal,
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2,
                color: const Color(0xFF5A4A3A))),
        ]),
        const SizedBox(width: 14),

        // ── Moment card ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(fmt.format(phase.start).toUpperCase(),
                    style: const TextStyle(color: AppColors.gold,
                        fontSize: 10.5, fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(phase.title(lang),
                    style: const TextStyle(color: Color(0xFFFBF7F0),
                        fontSize: 16.5, fontWeight: FontWeight.w800,
                        height: 1.3)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 12, color: AppColors.rust),
                  const SizedBox(width: 4),
                  Expanded(child: Text(phase.location(lang),
                      style: const TextStyle(color: Color(0xFFD8CDBC),
                          fontSize: 12.5))),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(20),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.gold.withAlpha(60)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        size: 15, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text(phase.stand(lang),
                        style: const TextStyle(color: Color(0xFFEFE6D8),
                            fontSize: 12.5, height: 1.5))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
