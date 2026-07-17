import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../sites/site_detail_screen.dart';
import '../timket/timket_roadmap.dart';

// ═══════════════════════════════════════════════════════════════
//  EXPLORE — Historic Sites + Events (Timket, Meskel, festivals)
//  in one page, switched by a segmented toggle. Timket is pinned.
// ═══════════════════════════════════════════════════════════════
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _tab = 0; // 0 = sites, 1 = events

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
            child: Text(am ? 'ያስሱ' : 'Explore Gondar',
                style: const TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal, letterSpacing: -0.5)),
          ),

          // ── Segmented toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Row(children: [
                _segment(am ? 'ታሪካዊ ቦታዎች' : 'Historic Sites',
                    Icons.account_balance, 0),
                _segment(am ? 'በዓላት' : 'Events',
                    Icons.celebration, 1),
              ]),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _tab == 0
                  ? _SitesList(key: const ValueKey('sites'), lang: lang)
                  : _EventsList(key: const ValueKey('events'), lang: lang),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _segment(String label, IconData icon, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.charcoal : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
                color: selected ? AppColors.gold : AppColors.textMuted),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

// ── Sites list ────────────────────────────────────────────────
class _SitesList extends ConsumerWidget {
  final String lang;
  const _SitesList({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);
    return sitesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(child: Text(tr(lang, 'no_sites'),
          style: const TextStyle(color: AppColors.textMuted))),
      data: (sites) => sites.isEmpty
          ? Center(child: Text(tr(lang, 'no_sites'),
              style: const TextStyle(color: AppColors.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: sites.length,
              itemBuilder: (_, i) => _fadeIn(i, _SiteCard(
                  site: sites[i], lang: lang)),
            ),
    );
  }
}

// ── Events list (Timket pinned first) ─────────────────────────
class _EventsList extends ConsumerWidget {
  final String lang;
  const _EventsList({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    return eventsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => const Center(child: Text('Could not load events',
          style: TextStyle(color: AppColors.textMuted))),
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('No events yet',
              style: TextStyle(color: AppColors.textMuted)));
        }
        // Timket pinned first
        final sorted = [...events]..sort((a, b) {
          final at = a['includes_timket'] == true ? 0 : 1;
          final bt = b['includes_timket'] == true ? 0 : 1;
          return at.compareTo(bt);
        });
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _fadeIn(i,
              _EventCard(event: sorted[i], lang: lang)),
        );
      },
    );
  }
}

Widget _fadeIn(int i, Widget child) => TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 1),
  duration: Duration(milliseconds: (250 + i * 60).clamp(250, 600)),
  curve: Curves.easeOutCubic,
  builder: (_, v, c) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c)),
  child: child,
);

// ── Site card ─────────────────────────────────────────────────
class _SiteCard extends StatelessWidget {
  final Map<String, dynamic> site;
  final String lang;
  const _SiteCard({required this.site, required this.lang});

  @override
  Widget build(BuildContext context) {
    final name = localName(site, lang);
    final photo = sitePhoto(site);
    final location = (site['location'] ?? '') as String;
    final info = (site['info'] ?? '') as String;
    final description = (site['description'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => SiteDetailScreen(site: {
          'id': site['id'], 'name': name, 'subtitle': info,
          'location': location, 'image': photo,
          'description': description, 'rating': '4.8',
          'tag': '', 'audio': false,
        }),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(14),
              blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ShimmerImage(url: photo, height: 185, width: double.infinity,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                darkOverlay: true),
            if (location.isNotEmpty)
              Positioned(bottom: 12, left: 14, child: Row(children: [
                const Icon(Icons.location_on, size: 13, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(location, style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
              ])),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, style: const TextStyle(fontSize: 17.5,
                  fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              if (info.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(info, style: const TextStyle(fontSize: 12.5,
                    color: AppColors.rust, fontWeight: FontWeight.w600)),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.textSecondary, height: 1.5)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Event card ────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String lang;
  const _EventCard({required this.event, required this.lang});

  @override
  Widget build(BuildContext context) {
    final name = (event['name'] ?? '') as String;
    final date = (event['date'] ?? '') as String;
    final desc = (event['description'] ?? '') as String;
    final photo = (event['photo'] ?? '') as String;
    final isTimket = event['includes_timket'] == true;
    final am = isAm(lang);

    return GestureDetector(
      onTap: () {
        if (isTimket) {
          // Timket is the only live event — open its full roadmap.
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => TimketRoadmapScreen(lang: lang)));
        } else {
          // Other festivals are coming soon.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.charcoal,
            behavior: SnackBarBehavior.floating,
            content: Text(
              am ? '$name — በቅርቡ ይመጣል' : '$name — full guide coming soon',
              style: const TextStyle(color: AppColors.gold),
            ),
          ));
        }
      },
      child: Opacity(
        opacity: isTimket ? 1.0 : 0.85,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(14),
                blurRadius: 16, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Stack(children: [
              ShimmerImage(url: photo, height: 175, width: double.infinity,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  darkOverlay: true),
              // Date chip
              Positioned(top: 12, left: 14, child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.event, size: 12, color: AppColors.charcoal),
                  const SizedBox(width: 5),
                  Text(date, style: const TextStyle(color: AppColors.charcoal,
                      fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              )),
              // FEATURED (Timket) or SOON (everything else)
              Positioned(top: 12, right: 14, child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: isTimket ? AppColors.rust : AppColors.charcoal,
                    borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isTimket ? Icons.push_pin : Icons.schedule,
                      size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(isTimket
                          ? 'FEATURED'
                          : (am ? 'በቅርቡ' : 'SOON'),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ]),
              )),
              Positioned(bottom: 12, left: 16, right: 16, child: Text(name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 19,
                      fontWeight: FontWeight.w900, letterSpacing: -0.4,
                      shadows: [Shadow(blurRadius: 10,
                          color: Colors.black54)]))),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Text(isTimket
                          ? (am ? 'የመንገድ ካርታውን ይመልከቱ' : 'View the roadmap')
                          : (am ? 'በቅርቡ ይመጣል' : 'Coming soon'),
                      style: TextStyle(
                          color: isTimket
                              ? AppColors.rust : AppColors.textMuted,
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 3),
                  Icon(isTimket
                          ? Icons.arrow_forward_rounded
                          : Icons.schedule,
                      size: 13,
                      color: isTimket
                          ? AppColors.rust : AppColors.textMuted),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
