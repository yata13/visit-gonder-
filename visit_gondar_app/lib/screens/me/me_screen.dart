import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/passport_provider.dart';
import '../../providers/tier_provider.dart';
import '../../widgets/ui.dart';
import '../account/account_screen.dart';
import '../auth/login_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../emergency/emergency_screen.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../premium/premium_screen.dart';
import '../../widgets/motion.dart';

// ═══════════════════════════════════════════════════════════════
//  ME (tab 5) — design "Me". Profile, plan, menu, language, log out.
// ═══════════════════════════════════════════════════════════════
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    ref.watch(authStateProvider);
    final user = SupabaseService.safeUser;
    final tier = ref.watch(userTierProvider).valueOrNull;
    final premium = tier?.isPremium ?? false;
    final p = ref.watch(passportProgressProvider);

    final meta = user?.userMetadata;
    var name = (meta?['full_name'] ?? meta?['name'] ?? '') as String;
    if (name.trim().isEmpty) {
      name = user?.email?.split('@').first ?? (am ? 'እንግዳ' : 'Guest');
    }
    final initial = name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase();

    final menu = <(IconData, String, VoidCallback)>[
      (Icons.calendar_month_outlined, am ? 'የእኔ ቦታ ማስያዣዎች' : 'My bookings',
          () => pushScreen(context, const MyBookingsScreen())),
      (Icons.notifications_none_rounded, am ? 'ማሳወቂያዎች' : 'Notifications',
          () => pushScreen(context, const NotificationsScreen())),
      if (user != null)
        (Icons.manage_accounts_outlined, am ? 'መለያ' : 'Account',
            () => pushScreen(context, const AccountScreen())),
      (Icons.health_and_safety_outlined, am ? 'ደህንነት እና SOS' : 'Safety & SOS',
          () => pushScreen(context, const EmergencyScreen())),
      (Icons.help_outline_rounded, am ? 'እርዳታ' : 'Help',
          () => _showHelp(context, am)),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
            children: Reveal.stagger([
              // ── Profile ─────────────────────────────────────
              Row(children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  child: Text(initial,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 32, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(fontSize: 26, height: 1.2,
                            fontWeight: FontWeight.w800)),
                    if (user?.email != null)
                      Text(user!.email!,
                          style: const TextStyle(fontSize: 14,
                              color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (user != null)
                        StatusTag(am
                            ? '${p.stamps} ማህተሞች · ${p.points} ነጥብ'
                            : '${p.stamps} stamps · ${p.points} pts'),
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFF8C8C8C)),
                        ),
                        child: Text(
                            premium
                                ? (am ? 'ፕሪሚየም' : 'Premium')
                                : (am ? 'ነፃ እቅድ' : 'Free plan'),
                            style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink700)),
                      ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              if (user == null)
                FilledButton.icon(
                  onPressed: () => pushScreen(context, const LoginScreen()),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(am ? 'ይግቡ ወይም ይመዝገቡ' : 'Sign in or create account'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => pushScreen(context, const AccountScreen()),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(am ? 'መገለጫ' : 'Profile'),
                ),
              const SizedBox(height: 16),

              // ── Premium ─────────────────────────────────────
              PressScale(
                onTap: () => pushScreen(context, const PremiumScreen()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.ink700,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.workspace_premium_outlined,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            premium
                                ? (am ? 'ፕሪሚየም ነዎት' : 'You are Premium')
                                : (am ? 'ወደ ፕሪሚየም' : 'Go Premium'),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(
                            am ? 'Ask Gondar AI እና ተጨማሪዎች'
                                : 'Ask Gondar AI and more extras',
                            style: const TextStyle(color: Color(0xFFCCCCCC),
                                fontSize: 13)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── Menu ────────────────────────────────────────
              Container(
                decoration: AppDecor.card(),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < menu.length; i++)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: menu[i].$3,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: i < menu.length - 1
                                ? const Border(bottom: BorderSide(
                                    color: AppColors.stone))
                                : null,
                          ),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.ground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(menu[i].$1, size: 20,
                                  color: AppColors.black),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(menu[i].$2,
                                  style: const TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.muted),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Language ────────────────────────────────────
              GlassPanel(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(children: [
                  Expanded(
                    child: Text(am ? 'ቋንቋ' : 'Language',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.stone,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      _LangOption(label: 'EN', on: !am, onTap: () {
                        if (am) ref.read(languageProvider.notifier).toggle();
                      }),
                      const SizedBox(width: 4),
                      _LangOption(label: 'አማ', on: am, onTap: () {
                        if (!am) ref.read(languageProvider.notifier).toggle();
                      }),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),

              if (user != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        textStyle: AppFonts.button(15, FontWeight.w700)),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                              SmoothPageRoute(
                                  builder: (_) => const OnboardingScreen()),
                              (_) => false);
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(am ? 'ውጣ' : 'Log out'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('${AppConstants.appName} · v1.5',
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.muted)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context, bool am) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(am ? 'እርዳታ' : 'Help',
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              am
                  ? 'በአደጋ ጊዜ በማንኛውም ገጽ ላይ ያለውን ቀይ SOS ቁልፍ ይጫኑ።'
                  : 'In an emergency, tap the red SOS button on any screen.',
              style: const TextStyle(fontSize: 15, color: AppColors.ink700)),
          const SizedBox(height: 16),
          for (final (label, number) in [
            (am ? 'ፖሊስ' : 'Police', '991'),
            (am ? 'አምቡላንስ' : 'Ambulance', '907'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:$number')),
                icon: const Icon(Icons.call_outlined),
                label: Text('$label $number'),
              ),
            ),
        ]),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _LangOption(
      {required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            constraints: const BoxConstraints(minWidth: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: on
                  ? const [BoxShadow(color: Color(0x26000000), blurRadius: 3,
                      offset: Offset(0, 1))]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on ? AppColors.ink : AppColors.muted)),
          ),
        ),
      );
}
