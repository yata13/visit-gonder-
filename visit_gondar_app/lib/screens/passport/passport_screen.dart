import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/ethiopian_date.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/passport_provider.dart';
import '../../widgets/shimmer_image.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';
import '../timket/timket_roadmap.dart';

// ═══════════════════════════════════════════════════════════════
//  GONDAR PASSPORT (tab 3) — design "Passport · home".
//  Night header with progress + "Check in at a site", Timket
//  Quest, a grid of stamps (done / next / locked) and badges.
// ═══════════════════════════════════════════════════════════════
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    ref.watch(authStateProvider);
    final signedIn = SupabaseService.safeUser != null;
    final cpsAsync = ref.watch(passportCheckpointsProvider);
    final mine = ref.watch(myCheckinsProvider).valueOrNull ?? const {};
    final p = ref.watch(passportProgressProvider);

    Future<void> refresh() async {
      ref.invalidate(passportCheckpointsProvider);
      ref.invalidate(myCheckinsProvider);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              _Header(am: am, progress: p, signedIn: signedIn),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _QuestCard(am: am, lang: lang),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Text(am ? 'ማህተሞች' : 'Stamps',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 14),
              cpsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => EmptyNote(
                  icon: Icons.cloud_off_rounded,
                  title: am ? 'ፓስፖርቱ አልተጫነም' : 'Could not load the Passport',
                  body: am ? 'ለማደስ ወደ ታች ይጎትቱ' : 'Pull down to try again',
                ),
                data: (cps) => cps.isEmpty
                    ? EmptyNote(
                        icon: Icons.badge_outlined,
                        title: am ? 'እስካሁን የማህተም ቦታ የለም'
                            : 'No stamp sites yet',
                        body: am ? 'በአስተዳዳሪው የተጨመሩት እዚህ ይታያሉ'
                            : 'Sites added in the admin appear here',
                      )
                    : _StampGrid(
                        checkpoints: cps,
                        mine: mine,
                        lang: lang,
                        nextId: p.next?['id']?.toString(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
                child: Text(am ? 'ባጆች' : 'Badges',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Badges(am: am, progress: p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Night header ──────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool am, signedIn;
  final PassportProgress progress;
  const _Header({required this.am, required this.progress,
      required this.signedIn});

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    final frac = total == 0 ? 0.0 : progress.stamps / total;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.black, AppColors.ink],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Row(children: [
              const AppMark(size: 28, background: AppColors.ink700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(am ? 'የጎንደር ፓስፖርት' : 'Gondar Passport',
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              if (signedIn && progress.stamps > 0)
                IconButton(
                  tooltip: am ? 'ሂደቱን ቅዳ' : 'Copy my progress',
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.ink700,
                      minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: am
                            ? 'በጎንደር ፓስፖርት ከ$total ማህተሞች ${progress.stamps}ቱን ሰብስቤአለሁ!'
                            : 'I collected ${progress.stamps} of $total stamps '
                                'on the Gondar Passport!'));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(am ? 'ተቀድቷል — ያጋሩት'
                            : 'Copied — paste it to share')));
                  },
                ),
            ]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                      am ? 'ከ$total ማህተሞች ${progress.stamps}ቱ'
                          : '${progress.stamps} of $total stamps',
                      style: const TextStyle(fontSize: 26,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                Text(am ? '${progress.points} ነጥብ'
                        : '${progress.points} points',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: am ? 'ከ$total ማህተሞች ${progress.stamps}ቱ'
                  : '${progress.stamps} of $total stamps',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 10,
                  color: Colors.white,
                  backgroundColor: AppColors.ink700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              onPressed: () => signedIn
                  ? showCheckInSheet(context)
                  : pushScreen(context, const LoginScreen()),
              icon: Icon(signedIn
                  ? Icons.qr_code_scanner_rounded
                  : Icons.login_rounded),
              label: Text(signedIn
                  ? (am ? 'በቦታው ማህተም ይውሰዱ' : 'Check in at a site')
                  : (am ? 'ማህተም ለመሰብሰብ ይግቡ' : 'Sign in to collect stamps')),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Timket Quest ──────────────────────────────────────────────
class _QuestCard extends StatelessWidget {
  final bool am;
  final String lang;
  const _QuestCard({required this.am, required this.lang});

  @override
  Widget build(BuildContext context) {
    final eve = EthDate.fromGregorian(DateTime(2027, 1, 18));
    final dates = am ? '${eve.monthName(true)} 10–12' : 'Jan 18–20';
    return PressScale(
      onTap: () => pushScreen(context, TimketRoadmapScreen(lang: lang)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE6E6E6), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
                color: AppColors.ink, shape: BoxShape.circle),
            child: const Icon(Icons.water_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(am ? 'የጥምቀት ተልዕኮ' : 'Timket Quest',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text(am ? 'ደረጃ በደረጃ · $dates · የተሳላሚ ባጅ ያግኙ'
                      : 'Step by step · $dates · earn the Pilgrim badge',
                  style: const TextStyle(fontSize: 13,
                      color: AppColors.black)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(am ? 'ጀምር' : 'Start',
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Stamps grid ───────────────────────────────────────────────
class _StampGrid extends StatelessWidget {
  final List<Map<String, dynamic>> checkpoints;
  final Map<String, DateTime> mine;
  final String lang;
  final String? nextId;
  const _StampGrid({
    required this.checkpoints,
    required this.mine,
    required this.lang,
    required this.nextId,
  });

  @override
  Widget build(BuildContext context) {
    final am = isAm(lang);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: checkpoints.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        mainAxisExtent: 128,
      ),
      itemBuilder: (_, i) {
        final c = checkpoints[i];
        final id = c['id'].toString();
        final doneAt = mine[id];
        final done = doneAt != null;
        final next = !done && id == nextId;
        final name = localName(c, lang);
        final sub = done
            ? (am ? EthDate.fromGregorian(doneAt).short(true)
                : _shortDate(doneAt))
            : next
                ? (am ? 'ቀጣይ' : 'Next')
                : '${c['points'] ?? 10} ${am ? 'ነጥብ' : 'pts'}';

        return Semantics(
          button: true,
          label: '$name, $sub',
          excludeSemantics: true,
          child: PressScale(
            onTap: () => pushScreen(context,
                CheckpointScreen(checkpoint: c, checkedIn: done)),
            child: Column(children: [
              _StampCircle(done: done, next: next),
              const SizedBox(height: 8),
              Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.3,
                      fontWeight: FontWeight.w700)),
              Text(sub,
                  style: TextStyle(fontSize: 12,
                      fontWeight: next ? FontWeight.w800 : FontWeight.w600,
                      color: done || next ? AppColors.black
                          : AppColors.muted)),
            ]),
          ),
        );
      },
    );
  }

  static String _shortDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
        'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }
}

class _StampCircle extends StatelessWidget {
  final bool done, next;
  const _StampCircle({required this.done, required this.next});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 74,
        height: 74,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: Container(
          decoration: const BoxDecoration(
              color: AppColors.ink, shape: BoxShape.circle),
          child: const Icon(Icons.castle_outlined,
              color: Colors.white, size: 28),
        ),
      );
    }
    if (next) {
      return SizedBox(
        width: 74,
        height: 74,
        child: CustomPaint(
          painter: _DashedRing(),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.gray100, shape: BoxShape.circle),
              child: const Icon(Icons.place_outlined,
                  color: AppColors.black, size: 28),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.stone,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFB3B3B3), width: 2),
        ),
        child: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF737373), size: 26),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2 - 1;
    const dashes = 22;
    for (var i = 0; i < dashes; i++) {
      final start = (i / dashes) * 2 * 3.14159265;
      canvas.drawArc(
          Rect.fromCircle(center: size.center(Offset.zero), radius: r),
          start, (2 * 3.14159265 / dashes) * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => false;
}

// ── Badges (derived from progress) ─────────────────────────────
class _Badges extends StatelessWidget {
  final bool am;
  final PassportProgress progress;
  const _Badges({required this.am, required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    final badges = [
      (Icons.star_rounded, am ? 'የመጀመሪያ ማህተም' : 'First stamp',
          progress.stamps >= 1),
      (Icons.castle_rounded, am ? 'የግንብ ጠባቂ' : 'Castle keeper',
          total > 0 && progress.stamps * 2 >= total),
      (Icons.water_drop_rounded, am ? 'የጥምቀት ተሳላሚ' : 'Timket pilgrim',
          total > 0 && progress.stamps >= total),
    ];
    return Row(
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: '${badges[i].$2}, '
                  '${badges[i].$3 ? (am ? 'ተገኝቷል' : 'earned') : (am ? 'ተቆልፏል' : 'locked')}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: AppDecor.glass(radius: 22),
                child: Column(children: [
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: badges[i].$3 ? AppColors.ink : AppColors.stone,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Transform.rotate(
                        angle: -0.785398,
                        child: Icon(
                            badges[i].$3 ? badges[i].$1
                                : Icons.lock_outline_rounded,
                            size: 22,
                            color: badges[i].$3 ? Colors.white
                                : const Color(0xFF737373)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(badges[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: badges[i].$3 ? AppColors.ink
                              : AppColors.muted)),
                ]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHECK-IN — type the code printed under the QR sign at a site.
// ═══════════════════════════════════════════════════════════════
Future<void> showCheckInSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CheckInSheet(),
  );
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet();
  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(bool am) async {
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await passportCheckIn(_code.text);
      ref.invalidate(myCheckinsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (_) => _StampEarnedDialog(result: res, am: am),
      );
    } on PostgrestException catch (e) {
      setState(() => _error = e.code == 'P0002'
          ? (am ? 'ኮዱ ትክክል አይደለም። እንደገና ይሞክሩ።'
              : 'That code is not right. Check the sign and try again.')
          : e.message);
    } catch (_) {
      setState(() => _error = am ? 'ኢንተርኔት የለም። እንደገና ይሞክሩ።'
          : 'No connection. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Text(am ? 'በቦታው ማህተም ይውሰዱ' : 'Check in at a site',
            style: const TextStyle(fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            am
                ? 'በቦታው ያለው የፓስፖርት ምልክት ላይ ከQR ኮዱ በታች የተጻፈውን ኮድ ያስገቡ።'
                : 'Type the code printed under the QR code on the '
                    'Passport sign at the site.',
            style: const TextStyle(fontSize: 15, color: AppColors.ink700,
                height: 1.45)),
        const SizedBox(height: 18),
        TextField(
          controller: _code,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(am),
          style: const TextStyle(fontSize: 18, letterSpacing: 1.2,
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: am ? 'የቦታው ኮድ' : 'Site code',
            prefixIcon: const Icon(Icons.qr_code_2_rounded),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.clayTint,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.clayInk, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.clayInk,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : () => _submit(am),
          child: _busy
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(am ? 'ማህተም ውሰድ' : 'Get my stamp'),
        ),
      ]),
    );
  }
}

class _StampEarnedDialog extends StatelessWidget {
  final CheckInResult result;
  final bool am;
  const _StampEarnedDialog({required this.result, required this.am});

  @override
  Widget build(BuildContext context) {
    final name = am && result.nameAm.isNotEmpty ? result.nameAm
        : result.nameEn;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Transform.rotate(
            angle: -0.17,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 4),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const Icon(Icons.castle_outlined, size: 52,
                    color: AppColors.black),
                const SizedBox(height: 4),
                const Text('GONDAR · ጎንደር',
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Text(
              result.alreadyChecked
                  ? (am ? 'ይህ ማህተም አለዎት' : 'You already have this stamp')
                  : (am ? 'ማህተም አግኝተዋል!' : 'Stamp earned!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.ink700)),
          if (!result.alreadyChecked && result.points > 0) ...[
            const SizedBox(height: 12),
            StatusTag('+${result.points} ${am ? 'ነጥብ' : 'points'}',
                background: AppColors.safeTint, foreground: AppColors.safe),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(am ? 'ጥሩ' : 'Great'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHECKPOINT — photo, about, story (read after check-in) and a
//  short trivia quiz.
// ═══════════════════════════════════════════════════════════════
class CheckpointScreen extends ConsumerWidget {
  final Map<String, dynamic> checkpoint;
  final bool checkedIn;
  const CheckpointScreen(
      {super.key, required this.checkpoint, required this.checkedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final am = isAm(lang);
    final id = checkpoint['id'].toString();
    final photo = (checkpoint['photo'] ?? '') as String;
    final desc = am && ((checkpoint['description_am'] ?? '') as String).isNotEmpty
        ? checkpoint['description_am'] as String
        : (checkpoint['description_en'] ?? '') as String;
    final stories = ref.watch(passportStoriesProvider(id));
    final trivia = ref.watch(passportTriviaProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(localName(checkpoint, lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (photo.isNotEmpty)
            ShimmerImage(url: photo, height: 200,
                borderRadius: BorderRadius.circular(AppRadius.glass)),
          const SizedBox(height: 14),
          Row(children: [
            StatusTag(
              checkedIn
                  ? (am ? 'ማህተም ተወስዷል' : 'Stamp collected')
                  : (am ? 'ገና አልተጎበኘም' : 'Not visited yet'),
              icon: checkedIn ? Icons.check_rounded
                  : Icons.lock_outline_rounded,
              background: checkedIn ? AppColors.ink : AppColors.gray100,
              foreground: checkedIn ? Colors.white : AppColors.black,
            ),
            const SizedBox(width: 8),
            StatusTag('${checkpoint['points'] ?? 10} '
                '${am ? 'ነጥብ' : 'points'}'),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(desc,
                style: const TextStyle(fontSize: 16, height: 1.5,
                    color: AppColors.ink700)),
          ],
          const SizedBox(height: 22),
          Text(am ? 'ታሪክ' : 'Story',
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (!checkedIn)
            _LockedNote(am: am)
          else
            stories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? Text(am ? 'ታሪክ በቅርቡ ይጨመራል' : 'A story is coming soon',
                      style: const TextStyle(color: AppColors.muted))
                  : Column(
                      children: list.map((s) {
                        final title = am &&
                                ((s['title_am'] ?? '') as String).isNotEmpty
                            ? s['title_am'] as String
                            : (s['title_en'] ?? '') as String;
                        final body = am &&
                                ((s['body_am'] ?? '') as String).isNotEmpty
                            ? s['body_am'] as String
                            : (s['body_en'] ?? '') as String;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: AppDecor.card(),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(body,
                                style: const TextStyle(fontSize: 15,
                                    height: 1.55, color: AppColors.ink700)),
                          ]),
                        );
                      }).toList(),
                    ),
            ),
          const SizedBox(height: 22),
          if (checkedIn)
            trivia.maybeWhen(
              data: (qs) => qs.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(am ? 'ጥያቄ' : 'Trivia',
                            style: const TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ...qs.map((q) => _TriviaCard(question: q, am: am)),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (!checkedIn) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => showCheckInSheet(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(am ? 'በቦታው ማህተም ይውሰዱ' : 'Check in at this site'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedNote extends StatelessWidget {
  final bool am;
  const _LockedNote({required this.am});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                am ? 'ታሪኩን ለመክፈት ቦታውን ይጎብኙ እና ማህተም ይውሰዱ።'
                    : 'Visit the site and check in to unlock its story.',
                style: const TextStyle(fontSize: 14, color: AppColors.ink700)),
          ),
        ]),
      );
}

class _TriviaCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final bool am;
  const _TriviaCard({required this.question, required this.am});
  @override
  State<_TriviaCard> createState() => _TriviaCardState();
}

class _TriviaCardState extends State<_TriviaCard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final am = widget.am;
    final optsAm = List<String>.from((q['options_am'] ?? const []) as List);
    final opts = am && optsAm.isNotEmpty
        ? optsAm
        : List<String>.from((q['options_en'] ?? const []) as List);
    final text = am && ((q['question_am'] ?? '') as String).isNotEmpty
        ? q['question_am'] as String
        : (q['question_en'] ?? '') as String;
    final correct = ((q['correct_index'] ?? 0) as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text,
            style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, height: 1.4)),
        const SizedBox(height: 12),
        for (var i = 0; i < opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _option(i, opts[i], correct),
          ),
        if (_picked != null)
          Text(
              _picked == correct
                  ? (am ? 'ትክክል! +${q['points'] ?? 5} ነጥብ'
                      : 'Correct! +${q['points'] ?? 5} points')
                  : (am ? 'አልተሳካም — ትክክለኛው መልስ ምልክት ተደርጎበታል።'
                      : 'Not quite — the right answer is marked.'),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _picked == correct ? AppColors.safe
                      : AppColors.clayInk)),
      ]),
    );
  }

  Widget _option(int i, String label, int correct) {
    final picked = _picked;
    Color bg = Colors.white, fg = AppColors.ink;
    Color border = const Color(0xFF8C8C8C);
    IconData? icon;
    if (picked != null) {
      if (i == correct) {
        bg = AppColors.safeTint;
        fg = AppColors.safe;
        border = AppColors.safe;
        icon = Icons.check_circle_rounded;
      } else if (i == picked) {
        bg = AppColors.clayTint;
        fg = AppColors.clayInk;
        border = AppColors.clayInk;
        icon = Icons.cancel_rounded;
      }
    }
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: picked == null ? () => setState(() => _picked = i) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 15, color: fg,
                      fontWeight: FontWeight.w600)),
            ),
            if (icon != null) Icon(icon, color: fg, size: 20),
          ]),
        ),
      ),
    );
  }
}
