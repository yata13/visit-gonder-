import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../providers/tier_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../premium/premium_screen.dart';
import '../../widgets/motion.dart';
import '../../core/constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
//  ASK GONDAR — Premium AI guide (proposal page 7)
//  Chat in Amharic or English. The `ask-gondar` edge function
//  answers ONLY from City-approved data; if it is not sure it
//  says so and gives the Safety Desk number.
//  Layout follows the design "Ask AI · chat home / chat".
// ═══════════════════════════════════════════════════════════════
class AskGondarScreen extends ConsumerStatefulWidget {
  const AskGondarScreen({super.key});
  @override
  ConsumerState<AskGondarScreen> createState() => _AskGondarScreenState();
}

class _AskGondarScreenState extends ConsumerState<AskGondarScreen> {
  int _chatKey = 0; // bump to start a new chat

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    final tierAsync = ref.watch(userTierProvider);
    final premium = tierAsync.valueOrNull?.isPremium ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          child: Column(children: [
            // ── Header ───────────────────────────────────────
            Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(children: [
                if (Navigator.canPop(context))
                  IconButton(
                    tooltip: am ? 'ተመለስ' : 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(am ? 'የጎንደር መሪ' : 'Gondar guide',
                      style: const TextStyle(fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: AppFonts.button(14, FontWeight.w800),
                  ),
                  onPressed: () =>
                      ref.read(languageProvider.notifier).toggle(),
                  child: Text(am ? 'EN' : 'አማ',
                      semanticsLabel:
                          am ? 'በእንግሊዝኛ መልስ' : 'Answer in Amharic'),
                ),
                if (premium)
                  IconButton(
                    tooltip: am ? 'አዲስ ውይይት' : 'New chat',
                    onPressed: () => setState(() => _chatKey++),
                    icon: const Icon(Icons.add_comment_outlined),
                  )
                else
                  const SizedBox(width: 8),
              ]),
            ),
            Expanded(
              child: tierAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Locked(am: am),
                data: (t) => t.isPremium
                    ? _Chat(key: ValueKey(_chatKey), am: am)
                    : _Locked(am: am),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Hello block shared by locked + empty chat ───────────────────
class _Hello extends StatelessWidget {
  final bool am;
  const _Hello({required this.am});

  @override
  Widget build(BuildContext context) {
    return Column(children: Reveal.stagger([
      Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.gray100, spreadRadius: 8)],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 38),
      ),
      const SizedBox(height: 18),
      Text(am ? 'ሰላም! እኔ የጎንደር መሪዎ ነኝ።' : 'Selam! I am your Gondar guide.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, height: 1.25,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
          am
              ? 'ስለ ቦታዎች፣ ታሪክ፣ ጥምቀት፣ ምግብ ወይም መጓጓዣ ይጠይቁኝ።'
              : 'Ask me about places, history, Timket, food or getting around.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.5,
              color: AppColors.ink700)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.stone,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.place_outlined, size: 14, color: AppColors.ink700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
                am ? 'የምመልሰው ስለ ጎንደር እና ስለ አማራ ክልል ብቻ ነው።'
                    : 'I answer only about Gondar and the Amhara region.',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: AppColors.ink700)),
          ),
        ]),
      ),
    ]));
  }
}

// ── Free users see what Premium unlocks ─────────────────────────
class _Locked extends StatelessWidget {
  final bool am;
  const _Locked({required this.am});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 200),
      children: Reveal.stagger([
        _Hello(am: am),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppDecor.card(),
          child: Column(children: [
            StatusTag(am ? 'ፕሪሚየም' : 'Premium',
                icon: Icons.workspace_premium_outlined),
            const SizedBox(height: 10),
            Text(
              am
                  ? 'በአማርኛ ወይም በእንግሊዝኛ ይጠይቁ፣ ከተማው ያጸደቀውን መልስ ያግኙ።'
                  : 'Chat in Amharic or English and get answers the City has approved.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.45,
                  color: AppColors.ink700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    pushScreen(context, const PremiumScreen()),
                icon: const Icon(Icons.workspace_premium),
                label: Text(am ? 'ፕሪሚየም ይመልከቱ' : 'See Premium'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
          am ? 'SOS እና የደህንነት መረጃ ሁልጊዜ ነፃ ነው።'
              : 'SOS and safety information are always free.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ]),
    );
  }
}

// ── The chat ────────────────────────────────────────────────────
class _Msg {
  final String role; // user | assistant
  final String text;
  final String? source;
  const _Msg(this.role, this.text, {this.source});
}

class _Chat extends StatefulWidget {
  final bool am;
  const _Chat({super.key, required this.am});
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _thinking = false;

  List<String> get _suggestions => widget.am
      ? ['በአንድ ቀን ምን ማየት እችላለሁ?', 'ጥምቀት መቼና የት ነው?',
         'ፋሲል ግቢ መቼ ይከፈታል?', 'ነገ ዝናብ ይዘንባል?', 'የትኛውን ምግብ ልሞክር?']
      : ['What can I see in one day?', 'When is Timket, and where?',
         'Fasil Ghebbi opening hours?', 'Will it rain tomorrow?',
         'What food should I try?'];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg('user', text));
      _thinking = true;
    });
    _toBottom();

    String reply;
    String? source;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ask-gondar',
        body: {
          'mode': 'visitor',
          'lang': widget.am ? 'am' : 'en',
          'messages': [
            for (final m in _msgs) {'role': m.role, 'content': m.text},
          ],
        },
      );
      final data = res.data as Map<String, dynamic>;
      reply = (data['answer'] ?? '') as String;
      source = data['source'] as String?;
      if (reply.trim().isEmpty) reply = _errorText(null);
    } on FunctionException catch (e) {
      final code = (e.details is Map) ? (e.details as Map)['error'] : null;
      reply = _errorText(code as String?);
    } catch (_) {
      reply = _errorText(null);
    }

    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg('assistant', reply, source: source));
      _thinking = false;
    });
    _toBottom();
  }

  String _errorText(String? code) {
    final am = widget.am;
    // Demo: while the AI is not live yet, answer with a warm hello.
    if (AppConstants.demoMode && code != 'daily_limit') {
      return am
          ? 'ሰላም! 👋 እኔ የጎንደር መሪዎ ነኝ።\n\n'
              'ሙሉ መልሶቼ በቅርቡ ይመጣሉ — ይጠብቁን! 🏰\n\n'
              'እስከዚያው ካርታውን፣ የጎንደር ፓስፖርትን እና የፋሲል ግቢን '
              'የ360° ምናባዊ ጉብኝት ይሞክሩ።'
          : "Hi there! 👋 Selam — I'm your Gondar guide.\n\n"
              "My full answers are coming soon — stay tuned! 🏰\n\n"
              'Meanwhile, explore the map, collect stamps in the Gondar '
              'Passport, and look around Fasil Ghebbi in the 360° virtual tour.';
    }
    return switch (code) {
      'premium_required' => am
          ? 'ይህ የፕሪሚየም አገልግሎት ነው።' : 'This is a Premium feature.',
      'daily_limit' => am
          ? 'የዛሬ የጥያቄ ገደብ ደርሷል። ነገ እንደገና ይሞክሩ።'
          : "You've reached today's question limit. Please try again tomorrow.",
      'sign_in_required' => am ? 'እባክዎ መጀመሪያ ይግቡ።' : 'Please sign in first.',
      _ => am
          ? 'አሁን መመለስ አልቻልኩም። ለእርዳታ የከተማውን የደህንነት ዴስክ ይደውሉ ወይም SOS ይጠቀሙ።'
          : "I can't answer right now. For help, call the City Safety Desk or use SOS.",
    };
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: Motion.medium, curve: Motion.curve);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final am = widget.am;
    return Column(children: [
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          children: [
            if (_msgs.isEmpty) ...Reveal.stagger([
              _Hello(am: am),
              const SizedBox(height: 22),
              Kicker(am ? 'እነዚህን ይጠይቁ' : 'Try asking',
                  color: AppColors.muted),
              const SizedBox(height: 10),
              for (final s in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _send(s),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(children: [
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: AppColors.black),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
            // Each new message glides in from its own side.
            for (final m in _msgs)
              Reveal(
                key: ObjectKey(m),
                duration: Motion.page,
                offset: Offset(m.role == 'user' ? 40 : -40, 12),
                scale: 0.94,
                child: _bubble(m),
              ),
            if (_thinking)
              Reveal(
                key: const ValueKey('thinking'),
                duration: Motion.medium,
                child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(am ? 'እያሰበ ነው…' : 'Thinking…',
                      style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              ),
          ],
        ),
      ),
      // Input — sits above the floating tab bar.
      Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 8 + MediaQuery.paddingOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF8C8C8C), width: 1.5),
          ),
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  filled: false,
                  hintText: am ? 'ስለ ጎንደር ይጠይቁ…' : 'Ask about Gondar…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            IconButton.filled(
              tooltip: am ? 'ላክ' : 'Send',
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44)),
              onPressed: _thinking ? null : _send,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _bubble(_Msg m) {
    final mine = m.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          border: mine ? null : Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(m.text, style: TextStyle(
              fontSize: 15, height: 1.45,
              color: mine ? Colors.white : AppColors.ink)),
          if (!mine && m.source != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, size: 13,
                  color: AppColors.verified),
              const SizedBox(width: 4),
              Text(widget.am && m.source == 'City of Gondar'
                      ? 'ምንጭ፡ የጎንደር ከተማ'
                      : 'Source: ${m.source}',
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.verified, fontWeight: FontWeight.w700)),
            ]),
          ],
        ]),
      ),
    );
  }
}
