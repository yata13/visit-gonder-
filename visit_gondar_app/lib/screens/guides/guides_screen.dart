import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../booking/booking_screen.dart';
import 'guide_profile_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  GUIDES — live from the same Supabase `guides` table the admin
//  manages.
// ═══════════════════════════════════════════════════════════════
class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidesAsync = ref.watch(guidesProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
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
              Text(tr(lang, 'guides_title'),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Text(tr(lang, 'guides_sub'),
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ),

          // ── List (live) ──
          Expanded(
            child: guidesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => Center(
                child: Text('Could not load guides\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
              data: (guides) {
                if (guides.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.person_pin_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(tr(lang, 'no_guides_title'),
                          style: const TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 16, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(tr(lang, 'admin_appear'),
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.textMuted)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: guides.length,
                  itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                        milliseconds: (250 + i * 60).clamp(250, 600)),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, 20 * (1 - v)), child: child)),
                    child: _GuideCard(guide: guides[i]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Guide Card ─────────────────────────────────────────────────
class _GuideCard extends ConsumerWidget {
  final Map<String, dynamic> guide;
  const _GuideCard({required this.guide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final name = (guide['name'] ?? '') as String;
    final initials = (guide['initials'] ?? 'GD') as String;
    final specialty = (guide['specialty'] ?? '') as String;
    final price = ((guide['price'] ?? 0) as num).toDouble();
    final licensed = (guide['license_status'] ?? '') == 'licensed';
    final languages = guide['languages'] is List
        ? List<String>.from(guide['languages'])
        : <String>[];

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => GuideProfileScreen(guide: guide))),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: AppColors.charcoal.withAlpha(12),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.rust, AppColors.rustDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal))),
              if (licensed) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified,
                    size: 16, color: AppColors.gold),
              ],
            ]),
            const SizedBox(height: 3),
            Text(specialty,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ])),
          Text('\$${price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 19,
                  fontWeight: FontWeight.w800, color: AppColors.rust)),
          const Text('/day',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),

        if (languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: languages.map((l) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l, style: const TextStyle(fontSize: 11,
                  color: AppColors.textSecondary)),
            )).toList(),
          ),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => BookingScreen(
                type: 'guide',
                referenceId: guide['id'].toString(),
                referenceName: name,
                referenceImage: (guide['photo'] ?? '') as String,
                pricePerUnit: price,
                priceLabel: 'day',
              ))),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: AppColors.gold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr(lang, 'book_guide'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ]),
      ),
    );
  }
}
