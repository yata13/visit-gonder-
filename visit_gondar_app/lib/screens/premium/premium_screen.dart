import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import '../../providers/tier_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../../widgets/motion.dart';

// ═══════════════════════════════════════════════════════════════
//  PLANS — Free vs Premium, exactly as in the proposal (page 9).
//  Safety is always free. Premium is requested here and approved
//  by an admin in the City dashboard.
// ═══════════════════════════════════════════════════════════════
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _sending = false;

  static const _free = [
    ('Discover sites, maps and verified listings', 'ቦታዎች፣ ካርታ እና የተረጋገጡ አገልግሎቶች'),
    ('Honest guide ratings', 'ትክክለኛ የአስጎብኚ ደረጃዎች'),
    ('Live weather — today and 7 days', 'የአየር ሁኔታ — ዛሬ እና 7 ቀናት'),
    ('SOS, emergency numbers and safety notices', 'SOS፣ የአደጋ ጊዜ ቁጥሮች እና የደህንነት ማሳወቂያዎች'),
    ('Safety is always free', 'ደህንነት ሁልጊዜ ነፃ ነው'),
  ];

  static const _premium = [
    ('Ask Gondar AI chat (Amharic & English)', 'ጎንደርን ይጠይቁ — AI ውይይት (አማርኛ እና እንግሊዝኛ)'),
    ('Official city news, posted anytime', 'ይፋዊ የከተማ ዜና በማንኛውም ጊዜ'),
    ('Full day-by-day planner', 'ሙሉ የቀን በቀን እቅድ'),
    ('Offline guide packs + audio guides', 'ከመስመር ውጭ መመሪያዎች + የድምጽ መመሪያ'),
    ('Priority booking help', 'ቅድሚያ የቦታ ማስያዝ እርዳታ'),
    ('Virtual tour of Fasil Ghebbi', 'የፋሲል ግቢ ምናባዊ ጉብኝት'),
  ];

  Future<void> _request() async {
    setState(() => _sending = true);
    final am = isAm(ref.read(languageProvider));
    try {
      await requestPremium();
      ref.invalidate(userTierProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(am
            ? 'ጥያቄዎ ተልኳል። ሲጸድቅ ፕሪሚየም ይከፈታል።'
            : 'Request sent. Premium unlocks as soon as it is approved.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(am ? 'መላክ አልተቻለም። እንደገና ይሞክሩ።'
            : 'Could not send the request. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final tier = ref.watch(userTierProvider).valueOrNull ?? UserTier.guest;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(am ? 'እቅዶች' : 'Plans')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: Reveal.stagger([
          Text(am ? 'የሕዝብ አገልግሎቱ ክፍት ነው።' : 'The public service stays open.',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.charcoal, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(am
                  ? 'ሁሉም ጎብኚ በነፃ ይጠቀማል። ፕሪሚየም ተጨማሪ አገልግሎቶችን ይከፍታል።'
                  : 'Every visitor uses the app free. Premium adds optional extras.',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 20),
          _planCard(
            title: am ? 'ነፃ' : 'Free',
            tag: am ? 'ለሁሉም ጎብኚ' : 'EVERY VISITOR',
            items: _free,
            am: am,
            current: tier.signedIn && !tier.isPremium,
            dark: false,
          ),
          const SizedBox(height: 14),
          _planCard(
            title: am ? 'ፕሪሚየም' : 'Premium',
            tag: am ? 'አማራጭ' : 'OPTIONAL UPGRADE',
            items: _premium,
            am: am,
            current: tier.isPremium,
            dark: true,
          ),
          const SizedBox(height: 22),
          _action(tier, am),
        ]),
      ),
    );
  }

  Widget _action(UserTier tier, bool am) {
    if (tier.isPremium) {
      final until = tier.premiumUntil;
      return _statusBox(Icons.workspace_premium, AppColors.green,
          until == null
              ? (am ? 'ፕሪሚየም ንቁ ነው' : 'Premium is active')
              : (am
                  ? 'ፕሪሚየም እስከ ${until.toLocal().toString().substring(0, 10)} ንቁ ነው'
                  : 'Premium is active until ${until.toLocal().toString().substring(0, 10)}'));
    }
    if (!tier.signedIn) {
      return FilledButton(
        style: _btn(),
        onPressed: () => Navigator.push(context,
            SmoothPageRoute(builder: (_) => const LoginScreen())),
        child: Text(am ? 'ፕሪሚየም ለመጠየቅ ይግቡ' : 'Sign in to request Premium'),
      );
    }
    if (tier.requestPending) {
      return _statusBox(Icons.hourglass_top_rounded, AppColors.goldDark,
          am ? 'ጥያቄዎ በመገምገም ላይ ነው' : 'Your request is being reviewed');
    }
    return FilledButton(
      style: _btn(),
      onPressed: _sending ? null : _request,
      child: _sending
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(am ? 'ፕሪሚየም ይጠይቁ' : 'Request Premium'),
    );
  }

  ButtonStyle _btn() => FilledButton.styleFrom(
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppFonts.button(15, FontWeight.w700),
      );

  Widget _statusBox(IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(
              color: color, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _planCard({
    required String title,
    required String tag,
    required List<(String, String)> items,
    required bool am,
    required bool current,
    required bool dark,
  }) {
    final fg = dark ? const Color(0xFFFFFFFF) : AppColors.charcoal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? AppColors.charcoal : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark ? Colors.white : AppColors.surfaceVariant,
            width: dark ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: TextStyle(fontSize: 19,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : fg)),
          if (current) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(dark ? 60 : 30),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(am ? 'የእርስዎ እቅድ' : 'Your plan',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : AppColors.goldDark)),
            ),
          ],
          const Spacer(),
          Text(tag, style: TextStyle(fontSize: 10, letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : AppColors.textMuted)),
        ]),
        const SizedBox(height: 12),
        for (final (en, amText) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_rounded, size: 17,
                  color: dark ? Colors.white : AppColors.green),
              const SizedBox(width: 9),
              Expanded(child: Text(am ? amText : en,
                  style: TextStyle(fontSize: 13.5, color: fg, height: 1.35))),
            ]),
          ),
      ]),
    );
  }
}
