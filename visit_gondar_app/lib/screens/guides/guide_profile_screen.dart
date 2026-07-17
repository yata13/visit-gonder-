import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_image.dart';
import '../booking/booking_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  GUIDE PROFILE — live row from the same Supabase `guides` table
//  the admin manages. Opened from search results and guide cards.
// ═══════════════════════════════════════════════════════════════
class GuideProfileScreen extends StatelessWidget {
  final Map<String, dynamic> guide;
  const GuideProfileScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final name = (guide['name'] ?? '') as String;
    final initials = (guide['initials'] ?? 'GD') as String;
    final specialty = (guide['specialty'] ?? '') as String;
    final photo = (guide['photo'] ?? '') as String;
    final price = ((guide['price'] ?? 0) as num).toDouble();
    final licensed = (guide['license_status'] ?? '') == 'licensed';
    final languages = guide['languages'] is List
        ? List<String>.from(guide['languages'])
        : <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const SizedBox(height: 70),

            // ── Profile header ──
            Center(
              child: Column(children: [
                Hero(
                  tag: 'guide-${guide['id']}',
                  child: photo.isNotEmpty
                      ? ShimmerImage(
                          url: photo,
                          width: 110, height: 110,
                          borderRadius: BorderRadius.circular(28))
                      : Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.rust, AppColors.rustDark]),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Center(
                            child: Text(initials,
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 34)),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(name,
                      style: const TextStyle(fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                          letterSpacing: -0.4)),
                  if (licensed) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified,
                        size: 20, color: AppColors.gold),
                  ],
                ]),
                if (specialty.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5,
                            color: AppColors.textMuted, height: 1.5)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // ── Price card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Guide fee, per day',
                        style: TextStyle(color: Color(0xFF8A7E70),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('\$${price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold)),
                  ]),
                  const Spacer(),
                  if (licensed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(30),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.gold.withAlpha(80)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.shield_outlined,
                            size: 13, color: AppColors.gold),
                        SizedBox(width: 5),
                        Text('LICENSED',
                            style: TextStyle(color: AppColors.gold,
                                fontSize: 10, fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 22),

            // ── Languages ──
            if (languages.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text('Languages',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: languages.map((l) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.language,
                          size: 14, color: AppColors.rust),
                      const SizedBox(width: 6),
                      Text(l, style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                    ]),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ── Trust note ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: AppColors.gold.withAlpha(100)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(children: [
                  Icon(Icons.verified_user_outlined,
                      color: AppColors.goldDark, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Verified by the Gondar Tourism Bureau. Agree the plan first — pay on the day.',
                        style: TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 13, height: 1.5,
                            color: AppColors.textSecondary)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 120),
          ]),
        ),

        // ── Top bar ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: GestureDetector(
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
          ),
        ),

        // ── Bottom book bar ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [BoxShadow(
                  color: AppColors.charcoal.withAlpha(20),
                  blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BookingScreen(
                    type: 'guide',
                    referenceId: guide['id'].toString(),
                    referenceName: name,
                    referenceImage: photo,
                    pricePerUnit: price,
                    priceLabel: 'day',
                  ))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: AppColors.gold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Book This Guide',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
