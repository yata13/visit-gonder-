import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../booking/booking_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  HOTELS — live from the same Supabase `hotels` table the admin
//  manages. Admin adds/edits a hotel → it appears here instantly.
// ═══════════════════════════════════════════════════════════════
class HotelsScreen extends ConsumerStatefulWidget {
  const HotelsScreen({super.key});
  @override
  ConsumerState<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends ConsumerState<HotelsScreen> {
  Map<String, dynamic>? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return HotelDetailPage(
        hotel: _selected!,
        onBack: () => setState(() => _selected = null),
      );
    }

    final hotelsAsync = ref.watch(hotelsProvider);
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
              Text(tr(lang, 'hotels_title'),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Text(tr(lang, 'live_db'),
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ),

          // ── List (live) ──
          Expanded(
            child: hotelsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: 3,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: ShimmerImage(url: '', height: 270,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text('Could not load hotels',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12,
                            color: AppColors.textMuted)),
                  ]),
                ),
              ),
              data: (hotels) {
                if (hotels.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.hotel_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(tr(lang, 'no_hotels_title'),
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
                  itemCount: hotels.length,
                  itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                        milliseconds: (250 + i * 60).clamp(250, 600)),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, 20 * (1 - v)), child: child)),
                    child: _HotelCard(
                      hotel: hotels[i],
                      onTap: () => setState(() => _selected = hotels[i]),
                    ),
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

// ── Hotel Card ─────────────────────────────────────────────────
class _HotelCard extends ConsumerWidget {
  final Map<String, dynamic> hotel;
  final VoidCallback onTap;
  const _HotelCard({required this.hotel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final name = localName(hotel, lang);
    final photo = hotelPhoto(hotel);
    final price = hotelPrice(hotel);
    final stars = hotelStars(hotel);
    final location = (hotel['location'] ?? '') as String;
    final description = (hotel['description'] ?? '') as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: AppColors.charcoal.withAlpha(14),
              blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo with price chip
          Stack(children: [
            Hero(
              tag: 'hotel-${hotel['id']}',
              child: ShimmerImage(
                url: photo,
                height: 190,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                darkOverlay: true,
              ),
            ),
            Positioned(
              bottom: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: RichText(text: TextSpan(children: [
                  TextSpan(
                    text: '\$${price.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.charcoal,
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const TextSpan(
                    text: ' /night',
                    style: TextStyle(color: Color(0xCC1C1410), fontSize: 11),
                  ),
                ])),
              ),
            ),
            Positioned(
              bottom: 12, left: 14,
              child: Row(children: List.generate(5, (i) => Icon(
                Icons.star_rounded,
                size: 15,
                color: i < stars
                    ? AppColors.gold
                    : Colors.white.withAlpha(80),
              ))),
            ),
          ]),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
              const SizedBox(height: 5),
              if (location.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.rust),
                  const SizedBox(width: 4),
                  Expanded(child: Text(location,
                      style: const TextStyle(color: AppColors.textMuted,
                          fontSize: 12.5))),
                ]),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.textSecondary, height: 1.5)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: AppColors.gold,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr(lang, 'view_book'),
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Hotel Detail ───────────────────────────────────────────────
//  Public + routable: opened in-place by HotelsScreen (via onBack)
//  or pushed directly from home cards and search results.
class HotelDetailPage extends ConsumerWidget {
  final Map<String, dynamic> hotel;
  final VoidCallback? onBack;
  const HotelDetailPage({super.key, required this.hotel, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final name = localName(hotel, lang);
    final photo = hotelPhoto(hotel);
    final price = hotelPrice(hotel);
    final stars = hotelStars(hotel);
    final location = (hotel['location'] ?? '') as String;
    final description = (hotel['description'] ?? '') as String;
    final contact = (hotel['contact'] ?? '') as String;
    final photos = hotel['photos'] is List
        ? List<String>.from(hotel['photos'])
        : <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.charcoal,
            leading: GestureDetector(
              onTap: onBack ?? () => Navigator.maybePop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'hotel-${hotel['id']}',
                child: ShimmerImage(
                  url: photo,
                  borderRadius: BorderRadius.zero,
                  darkOverlay: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal, letterSpacing: -0.4)),
                const SizedBox(height: 8),
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: i < stars
                        ? AppColors.gold : AppColors.surfaceVariant,
                  )),
                  const SizedBox(width: 8),
                  Text('$stars-star hotel',
                      style: const TextStyle(color: AppColors.textMuted,
                          fontSize: 13)),
                ]),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: AppColors.rust),
                    const SizedBox(width: 4),
                    Text(location,
                        style: const TextStyle(color: AppColors.textMuted,
                            fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 22),

                // Price + book card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(tr(lang, 'per_night_label'),
                          style: const TextStyle(color: Color(0xFF8A7E70),
                              fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('\$${price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold)),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: 135,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => BookingScreen(
                            type: 'hotel',
                            referenceId: hotel['id'].toString(),
                            referenceName: name,
                            referenceImage: photo,
                            pricePerUnit: price,
                            priceLabel: 'night',
                          ))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.charcoal,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(tr(lang, 'book_now'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                if (description.isNotEmpty) ...[
                  Text(tr(lang, 'about'),
                      style: const TextStyle(fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(fontSize: 14,
                          color: AppColors.textSecondary, height: 1.7)),
                  const SizedBox(height: 22),
                ],

                if (contact.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Row(children: [
                      const Icon(Icons.phone_outlined,
                          color: AppColors.rust, size: 20),
                      const SizedBox(width: 12),
                      Text(contact,
                          style: const TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                ],

                if (photos.length > 1) ...[
                  Text(tr(lang, 'gallery'),
                      style: const TextStyle(fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ShimmerImage(
                          url: photos[i],
                          width: 150, height: 110,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
