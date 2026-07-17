import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/data_providers.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import 'site_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SITES — live from the same Supabase `sites` table the admin
//  manages.
// ═══════════════════════════════════════════════════════════════
class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);
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
              Text(tr(lang, 'sites_title'),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal, letterSpacing: -0.4)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Text(tr(lang, 'sites_sub'),
                style: const TextStyle(fontSize: 12.5,
                    color: AppColors.textMuted)),
          ),

          // ── List (live) ──
          Expanded(
            child: sitesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: 3,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: ShimmerImage(url: '', height: 240,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Could not load sites\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
              data: (sites) {
                if (sites.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(tr(lang, 'no_sites_title'),
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
                  itemCount: sites.length,
                  itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                        milliseconds: (250 + i * 60).clamp(250, 600)),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, 20 * (1 - v)), child: child)),
                    child: _SiteCard(site: sites[i], lang: lang),
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

// ── Site Card ──────────────────────────────────────────────────
class _SiteCard extends StatelessWidget {
  final Map<String, dynamic> site;
  final String lang;
  const _SiteCard({required this.site, required this.lang});

  @override
  Widget build(BuildContext context) {
    final name = localName(site, lang);
    final photo = sitePhoto(site);
    final location = (site['location'] ?? '') as String;
    final description = (site['description'] ?? '') as String;
    final info = (site['info'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.push(context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SiteDetailScreen(site: {
            'id': site['id'],
            'name': name,
            'subtitle': info,
            'location': location,
            'image': photo,
            'description': description,
            'rating': '4.8',
            'tag': '',
            'audio': false,
          }),
          transitionsBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
                parent: anim, curve: Curves.easeOut);
            return FadeTransition(opacity: curved, child: child);
          },
          transitionDuration: const Duration(milliseconds: 260),
        )),
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
          Stack(children: [
            ShimmerImage(
              url: photo,
              height: 185,
              width: double.infinity,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              darkOverlay: true,
            ),
            if (location.isNotEmpty)
              Positioned(
                bottom: 12, left: 14,
                child: Row(children: [
                  const Icon(Icons.location_on,
                      size: 13, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(location,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 6,
                              color: Colors.black54)])),
                ]),
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
              if (info.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(info,
                    style: const TextStyle(fontSize: 12.5,
                        color: AppColors.rust,
                        fontWeight: FontWeight.w600)),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
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
