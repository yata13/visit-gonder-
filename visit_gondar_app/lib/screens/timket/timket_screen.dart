import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import 'timket_live.dart';

class TimketScreen extends ConsumerWidget {
  const TimketScreen({super.key});

  /// Hero image comes from the database so it can be changed in the
  /// admin: first a Timket event photo, then the Fasilides Bath site
  /// photo, then any site photo.
  String _heroUrl(WidgetRef ref) {
    final events = ref.watch(eventsProvider).value ?? const [];
    for (final e in events) {
      final p = (e['photo'] ?? '') as String;
      if (e['includes_timket'] == true && p.isNotEmpty) return p;
    }
    final sites = ref.watch(sitesProvider).value ?? const [];
    for (final s in sites) {
      final name = ((s['name_en'] ?? '') as String).toLowerCase();
      final p = (s['photo'] ?? '') as String;
      if (name.contains('bath') && p.isNotEmpty) return p;
    }
    for (final s in sites) {
      final p = (s['photo'] ?? '') as String;
      if (p.isNotEmpty) return p;
    }
    return '';
  }

  final _events = const [
    {
      'day': 'JAN 18',
      'title': 'Ketera',
      'subtitle': 'Procession to Jan Meda',
      'desc': 'The Tabots (replicas of the Ark of the Covenant) are carried in a vibrant procession from their respective churches to the historic pool of Fasilides.',
      'time': '3:00 PM',
    },
    {
      'day': 'JAN 19',
      'title': 'Water Blessing',
      'subtitle': 'Timket — Epiphany Day',
      'desc': 'The pinnacle of the festival. The pool\'s water is blessed at dawn and sprinkled upon the crowd. Thousands symbolically renew their baptismal vows.',
      'time': '6:00 AM',
    },
    {
      'day': 'JAN 20',
      'title': 'Kana Ze Galila',
      'subtitle': 'Return procession',
      'desc': 'Dedicated to the archangel Michael. The Tabots are returned to their churches as the remaining crowds celebrate with joyous music and dance.',
      'time': '8:00 AM',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero image with overlay — from the database (admin-managed)
          Stack(children: [
            ShimmerImage(
              url: _heroUrl(ref),
              height: 260, width: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
            Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Text('Visit Gondar',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white38),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('EN / አማ',
                          style: TextStyle(color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20, left: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('UNESCO INTANGIBLE HERITAGE',
                      style: TextStyle(color: Colors.white70, fontSize: 10,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 8),
                const Text('Timket\nFestival',
                    style: TextStyle(color: Colors.white, fontSize: 34,
                        fontWeight: FontWeight.w700, height: 1.1)),
              ]),
            ),
          ]),

          // Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Row(children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              const Text('HAPPENING NOW',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.goldDark, letterSpacing: 1)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Text('Procession to Jan Meda',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),

          // 3-day schedule
          ...(_events as List).map((event) => _eventCard(event)).toList(),

          // CTA button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _showStandGuide(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Show me where to stand',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  /// Every moment of the festival with its viewing spot —
  /// the full program from Live Timket Mode.
  void _showStandGuide(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageProvider);
    final fmt = DateFormat('EEE d MMM · HH:mm');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 18),
            Text(
              isAm(lang)
                  ? 'የት መቆም እንዳለብዎ — እያንዳንዱ ቅጽበት'
                  : 'Where to stand — every moment',
              style: const TextStyle(color: Color(0xFFFBF7F0),
                  fontSize: 21, fontWeight: FontWeight.w800,
                  letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            Text(
              isAm(lang)
                  ? 'የጥምቀት ሙሉ መርሃ ግብር ከምርጥ መቆሚያ ቦታዎች ጋር'
                  : 'The full Timket program with the best viewing spots',
              style: const TextStyle(color: Color(0xFFB3A899),
                  fontSize: 13)),
            const SizedBox(height: 20),

            ...kTimketProgram.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(fmt.format(p.start).toUpperCase(),
                    style: const TextStyle(color: AppColors.gold,
                        fontSize: 10.5, fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(p.title(lang),
                    style: const TextStyle(color: Color(0xFFFBF7F0),
                        fontSize: 16, fontWeight: FontWeight.w800,
                        height: 1.3)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 12, color: AppColors.rust),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p.location(lang),
                      style: const TextStyle(color: Color(0xFFD8CDBC),
                          fontSize: 12))),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.gold.withAlpha(60)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        size: 15, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.stand(lang),
                        style: const TextStyle(color: Color(0xFFEFE6D8),
                            fontSize: 12.5, height: 1.5))),
                  ]),
                ),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(Map event) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(event['day'],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.goldDark, letterSpacing: 1)),
          Text(event['time'],
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        Text(event['title'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(event['subtitle'],
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Text(event['desc'],
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
      ]),
    );
  }
}
