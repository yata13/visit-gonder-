import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../hotels/hotels_screen.dart';
import '../booking/my_bookings_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  STAY — everything a visitor needs on the ground:
//  Hotels (live) · Taxi & transfers · More services (food, shops).
// ═══════════════════════════════════════════════════════════════
class StayScreen extends ConsumerStatefulWidget {
  const StayScreen({super.key});
  @override
  ConsumerState<StayScreen> createState() => _StayScreenState();
}

class _StayScreenState extends ConsumerState<StayScreen> {
  int _tab = 0; // 0 hotels, 1 taxi, 2 more

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Expanded(
                child: Text(am ? 'ማረፊያና አገልግሎት' : 'Stay & Services',
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal, letterSpacing: -0.5)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MyBookingsScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long,
                        size: 15, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(am ? 'ማስያዣዎቼ' : 'My Bookings',
                        style: const TextStyle(color: AppColors.gold,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Tabs ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _tabChip(am ? 'ሆቴሎች' : 'Hotels', Icons.hotel, 0),
                _tabChip(am ? 'ታክሲ' : 'Taxi', Icons.local_taxi, 1),
                _tabChip(am ? 'ተጨማሪ' : 'More', Icons.storefront, 2),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tab) {
                0 => _HotelsTab(key: const ValueKey('h'), lang: lang),
                1 => _TaxiTab(key: const ValueKey('t'), am: am),
                _ => _MoreTab(key: const ValueKey('m'), lang: lang),
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabChip(String label, IconData icon, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.charcoal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected
              ? AppColors.charcoal : AppColors.surfaceVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15,
              color: selected ? AppColors.gold : AppColors.textMuted),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ── Hotels tab (live) ─────────────────────────────────────────
class _HotelsTab extends ConsumerWidget {
  final String lang;
  const _HotelsTab({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelsAsync = ref.watch(hotelsProvider);
    return hotelsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text(tr(lang, 'no_hotels'),
          style: const TextStyle(color: AppColors.textMuted))),
      data: (hotels) => hotels.isEmpty
          ? Center(child: Text(tr(lang, 'no_hotels'),
              style: const TextStyle(color: AppColors.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: hotels.length,
              itemBuilder: (_, i) => _fade(i, _HotelRow(
                  hotel: hotels[i], lang: lang)),
            ),
    );
  }
}

class _HotelRow extends StatelessWidget {
  final Map<String, dynamic> hotel;
  final String lang;
  const _HotelRow({required this.hotel, required this.lang});

  @override
  Widget build(BuildContext context) {
    final name = localName(hotel, lang);
    final photo = hotelPhoto(hotel);
    final price = hotelPrice(hotel);
    final stars = hotelStars(hotel);
    final location = (hotel['location'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => HotelDetailPage(hotel: hotel))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(12),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          ShimmerImage(url: photo, width: 112, height: 112,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18))),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5,
                      fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              const SizedBox(height: 3),
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded,
                  size: 13,
                  color: i < stars ? AppColors.gold
                      : AppColors.surfaceVariant))),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.rust),
                  const SizedBox(width: 3),
                  Expanded(child: Text(location, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5,
                          color: AppColors.textMuted))),
                ]),
              ],
              const SizedBox(height: 6),
              Text('\$${price.toStringAsFixed(0)}${tr(lang, 'per_night')}',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: AppColors.rust)),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Taxi tab ──────────────────────────────────────────────────
class _TaxiTab extends StatelessWidget {
  final bool am;
  const _TaxiTab({super.key, required this.am});

  @override
  Widget build(BuildContext context) {
    final services = [
      (Icons.flight_land, am ? 'የአውሮፕላን ማረፊያ ዝውውር' : 'Airport Transfer',
       am ? 'ከጎንደር አውሮፕላን ማረፊያ ወደ ሆቴልዎ' : 'Gondar Airport ↔ your hotel',
       '+251 91 100 2030'),
      (Icons.local_taxi, am ? 'የከተማ ታክሲ' : 'City Taxi',
       am ? 'በጎንደር ከተማ ውስጥ ጉዞ' : 'Rides anywhere inside Gondar',
       '+251 91 200 4050'),
      (Icons.electric_rickshaw, am ? 'ባጃጅ' : 'Bajaj (Tuk-tuk)',
       am ? 'አጭር ርቀት፣ ርካሽ ጉዞ' : 'Short, cheap trips around town',
       '+251 91 300 6070'),
      (Icons.directions_car, am ? 'መኪና ከሾፌር ጋር' : 'Car with Driver',
       am ? 'ሙሉ ቀን የቱሪስት ጉዞ' : 'Full-day tours & outskirts',
       '+251 91 400 8090'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
              am ? 'ለማዘዝ ይደውሉ። ዋጋ ከመሳፈርዎ በፊት ይስማሙ።'
                 : 'Tap to call. Always agree the fare before you ride.',
              style: const TextStyle(color: Color(0xFFEFE6D8),
                  fontSize: 12.5, height: 1.4))),
          ]),
        ),
        ...services.asMap().entries.map((e) => _fade(e.key,
            _taxiCard(context, e.value.$1, e.value.$2, e.value.$3, e.value.$4,
                am))),
      ],
    );
  }

  Widget _taxiCard(BuildContext context, IconData icon, String title,
      String sub, String phone, bool am) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant)),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: AppColors.gold.withAlpha(36),
              borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: AppColors.goldDark, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w800, color: AppColors.charcoal)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 12,
              color: AppColors.textMuted)),
          const SizedBox(height: 3),
          Text(phone, style: const TextStyle(fontSize: 12.5,
              fontWeight: FontWeight.w600, color: AppColors.rust)),
        ])),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
            try { await launchUrl(uri); } catch (_) {}
          },
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(color: AppColors.charcoal,
                shape: BoxShape.circle),
            child: const Icon(Icons.call, color: AppColors.gold, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── More services tab (live places: food, shops, clubs) ───────
class _MoreTab extends ConsumerWidget {
  final String lang;
  const _MoreTab({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placesProvider);
    return placesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => const Center(child: Text(
          'Add restaurants, shops & clubs in the admin Map Manager',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted))),
      data: (places) {
        final services = places.where((p) =>
            const ['restaurant', 'store', 'club', 'museum']
                .contains(p['category'])).toList();
        if (services.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text(
                'No extra services yet.\nAdd restaurants, shops & clubs in the admin Map Manager.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.5)),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: services.length,
          itemBuilder: (_, i) => _fade(i, _serviceCard(services[i])),
        );
      },
    );
  }

  Widget _serviceCard(Map<String, dynamic> p) {
    final name = localName(p, lang);
    final cat = (p['category'] ?? 'other') as String;
    final info = (p['info'] ?? '') as String;
    final photo = (p['photo'] ?? '') as String;
    IconData icon = switch (cat) {
      'restaurant' => Icons.restaurant,
      'store' => Icons.storefront,
      'club' => Icons.nightlife,
      'museum' => Icons.museum,
      _ => Icons.place,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant)),
      child: Row(children: [
        if (photo.isNotEmpty)
          ShimmerImage(url: photo, width: 84, height: 84,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)))
        else
          Container(width: 84, height: 84,
            decoration: const BoxDecoration(color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(16))),
            child: Icon(icon, color: AppColors.textMuted, size: 28)),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(cat.toUpperCase(), style: const TextStyle(fontSize: 9.5,
                fontWeight: FontWeight.w800, color: AppColors.rust,
                letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: AppColors.charcoal)),
            if (info.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(info, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textMuted)),
            ],
          ]),
        )),
      ]),
    );
  }
}

Widget _fade(int i, Widget child) => TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 1),
  duration: Duration(milliseconds: (250 + i * 50).clamp(250, 550)),
  curve: Curves.easeOutCubic,
  builder: (_, v, c) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
  child: child,
);
