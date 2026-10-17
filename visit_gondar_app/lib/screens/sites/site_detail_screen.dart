import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../../widgets/ui.dart';
import '../ai/ask_gondar_screen.dart';
import '../auth/login_screen.dart';
import '../passport/passport_screen.dart';
import '../tour/virtual_tour_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SITE DETAIL — design "Site detail · Fasil Ghebbi".
//  Photo, name, tags, quick facts, story, Ask AI, Passport stamp,
//  then Directions / Check in at the bottom. SOS floats on top.
// ═══════════════════════════════════════════════════════════════
class SiteDetailScreen extends ConsumerWidget {
  final Map site;
  const SiteDetailScreen({super.key, required this.site});

  Future<void> _directions() async {
    final name = (site['name'] ?? '') as String;
    final loc = (site['location'] ?? '') as String;
    final q = Uri.encodeComponent('$name ${loc.isEmpty ? 'Gondar' : loc}');
    await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(ref.watch(languageProvider));
    final name = (site['name'] ?? '') as String;
    final subtitle = (site['subtitle'] ?? '') as String;
    final location = (site['location'] ?? '') as String;
    final image = (site['image'] ?? '') as String;
    final description = (site['description'] ?? '') as String;
    final rating = (site['rating'] ?? '') as String;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    void checkIn() {
      final signedIn = SupabaseService.safeUser != null;
      signedIn
          ? showCheckInSheet(context)
          : pushScreen(context, const LoginScreen());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Stack(children: [
          ListView(
            padding: EdgeInsets.only(bottom: 120 + bottomInset),
            children: [
              // ── Photo ─────────────────────────────────────
              SizedBox(
                height: 300,
                child: Stack(fit: StackFit.expand, children: [
                  Hero(
                    tag: 'site-${site['id']}',
                    child: image.isEmpty
                        ? Container(
                            color: AppColors.stone,
                            child: const Icon(Icons.castle_outlined,
                                size: 64, color: Color(0xFFB3B3B3)),
                          )
                        : ShimmerImage(url: image,
                            borderRadius: BorderRadius.zero),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _RoundButton(
                          icon: Icons.arrow_back_rounded,
                          label: am ? 'ተመለስ' : 'Back',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(name,
                      style: const TextStyle(fontSize: 28, height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 15,
                            color: AppColors.muted)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    StatusTag(am ? 'የፓስፖርት ማህተም' : 'Passport stamp',
                        icon: Icons.badge_outlined),
                    if (rating.isNotEmpty)
                      StatusTag(rating, icon: Icons.star_rounded,
                          background: AppColors.stone,
                          foreground: AppColors.ink700),
                  ]),
                  const SizedBox(height: 20),

                  // ── Quick facts ─────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _Fact(
                        label: am ? 'ቦታ' : 'Where',
                        value: location.isEmpty ? 'Gondar' : location,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Fact(
                        label: am ? 'ደረጃ' : 'Rating',
                        value: rating.isEmpty ? '—' : '$rating ★',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),

                  // ── Story ───────────────────────────────────
                  if (description.isNotEmpty) ...[
                    Text(am ? 'ታሪኩ' : 'The story',
                        style: const TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(fontSize: 16, height: 1.55,
                            color: AppColors.ink700)),
                    const SizedBox(height: 22),
                  ],

                  // ── Ask AI ──────────────────────────────────
                  PressScale(
                    onTap: () =>
                        pushScreen(context, const AskGondarScreen()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              color: AppColors.ink700,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome_outlined,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(am ? 'ስለዚህ ቦታ AI መሪውን ይጠይቁ'
                                    : 'Ask the AI guide about this place',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            Text(am ? 'ማን ገነባው? መጀመሪያ ምን ልይ?'
                                    : 'Who built it? What should I see first?',
                                style: const TextStyle(
                                    color: Color(0xFFCCCCCC), fontSize: 13)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Virtual tour (Premium) ──────────────────
                  PressScale(
                    onTap: () =>
                        pushScreen(context, const VirtualTourScreen()),
                    child: GlassPanel(
                      radius: 22,
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.threesixty_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(am ? 'የፋሲል ግቢ ምናባዊ ጉብኝት'
                                    : 'Virtual tour of Fasil Ghebbi',
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            Text(am ? 'ፕሪሚየም · 7 ቦታዎች'
                                    : 'Premium · 7 stops',
                                style: const TextStyle(fontSize: 13,
                                    color: AppColors.muted)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.muted),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Passport stamp ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.gray100, width: 3),
                          boxShadow: const [BoxShadow(
                              color: AppColors.ink, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.castle_outlined,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(am ? 'የፓስፖርት ማህተምዎን ይውሰዱ'
                                  : 'Collect your Passport stamp',
                              style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              am
                                  ? 'በቦታው ያለውን የፓስፖርት ምልክት ኮድ ያስገቡ።'
                                  : 'Enter the code on the Passport sign '
                                      'at the site.',
                              style: const TextStyle(fontSize: 14,
                                  height: 1.45, color: AppColors.black)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
          ),

          // ── Bottom actions ─────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.ground.withValues(alpha: 0),
                    AppColors.ground,
                  ],
                  stops: const [0, 0.3],
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _directions,
                    style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(48, 52)),
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: Text(am ? 'አቅጣጫ' : 'Directions'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: checkIn,
                    icon: const Icon(Icons.qr_code_scanner_rounded,
                        size: 18),
                    label: Text(am ? 'ማህተም ይውሰዱ' : 'Check in'),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomInset + 84,
            child: const SosButton(),
          ),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label, value;
  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDecor.card(radius: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x29000000), blurRadius: 8,
                  offset: Offset(0, 2))],
            ),
            child: Icon(icon, color: AppColors.ink, size: 22),
          ),
        ),
      );
}
