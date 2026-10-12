import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/language_provider.dart';
import '../../providers/tier_provider.dart';
import '../../theme/app_theme.dart';
import '../premium/premium_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  ASK GONDAR — Premium AI guide (proposal page 7)
//  Chat in Amharic or English. The `ask-gondar` edge function
//  answers ONLY from City-approved data; if it is not sure it
//  says so and gives the Safety Desk number.
// ═══════════════════════════════════════════════════════════════
class AskGondarScreen extends ConsumerWidget {
  const AskGondarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(ref.watch(languageProvider));
    final tierAsync = ref.watch(userTierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        foregroundColor: const Color(0xFFFBF7F0),
        titleTextStyle: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.w700, color: Color(0xFFFBF7F0)),
        title: Text(am ? 'ጎንደርን ይጠይቁ' : 'Ask Gondar'),
      ),
      body: tierAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => _Locked(am: am),
        data: (t) => t.isPremium ? _Chat(am: am) : _Locked(am: am),
      ),
    );
  }
}

// ── Free users see what Premium unlocks ─────────────────────────
class _Locked extends StatelessWidget {
  final bool am;
  const _Locked({required this.am});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: AppColors.charcoal, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: AppColors.gold, size: 34),
          ),
          const SizedBox(height: 18),
          Text(am ? 'የፕሪሚየም አገልግሎት' : 'A Premium feature',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
          const SizedBox(height: 8),
          Text(
            am
                ? 'በአማርኛ ወይም በእንግሊዝኛ ይጠይቁ፣ ከተማው ያጸደቀውን መልስ ያግኙ።'
                : 'Chat in Amharic or English and get answers the City has approved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: AppColors.gold,
              minimumSize: const Size(220, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen())),
            icon: const Icon(Icons.workspace_premium),
            label: Text(am ? 'ፕሪሚየም ይመልከቱ' : 'See Premium'),
          ),
          const SizedBox(height: 14),
          Text(
            am ? 'SOS እና የደህንነት መረጃ ሁልጊዜ ነፃ ነው።'
                : 'SOS and safety information are always free.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ]),
      ),
    );
  }
}

// ── The chat ────────────────────────────────────────────────────
class _Msg {
  final String role; // user | assistant
  final String text;
  final String? source;
  final bool badge; // show `source` as-is (greeting) instead of "Source: …"
  const _Msg(this.role, this.text, {this.source, this.badge = false});
}

class _Chat extends StatefulWidget {
  final bool am;
  const _Chat({required this.am});
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _thinking = false;

  List<String> get _suggestions => widget.am
      ? ['ጥምቀትን የት ማየት እችላለሁ?', 'ፋሲል ግቢ መቼ ይከፈታል?', 'ነገ ዝናብ ይዘንባል?']
      : ['Where can I watch Timket?', 'Fasil Ghebbi opening hours?',
         'Will it rain tomorrow?'];

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
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            _bubble(_Msg('assistant', am
                ? 'ሰላም! ስለ ጎንደር ማንኛውንም ይጠይቁኝ።'
                : 'Selam! Ask me anything about Gondar.',
                source: am ? 'በከተማው የጸደቀ · ፕሪሚየም' : 'City-approved · Premium',
                badge: true)),
            if (_msgs.isEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12.5)),
                    backgroundColor: AppColors.surfaceContainer,
                    side: BorderSide.none,
                    onPressed: () => _send(s),
                  ),
              ]),
            for (final m in _msgs) _bubble(m),
            if (_thinking)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold)),
                  const SizedBox(width: 10),
                  Text(am ? 'እያሰበ ነው…' : 'Thinking…',
                      style: const TextStyle(color: AppColors.textMuted)),
                ]),
              ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: am ? 'ስለ ጎንደር ማንኛውንም ይጠይቁ…'
                      : 'Ask anything about Gondar…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.surfaceVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.surfaceVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.goldDeep),
              onPressed: _thinking ? null : _send,
              icon: const Icon(Icons.send_rounded),
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
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.rust : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(m.text, style: TextStyle(
              fontSize: 14, height: 1.4,
              color: mine ? Colors.white : AppColors.charcoal)),
          if (!mine && m.source != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, size: 13, color: AppColors.green),
              const SizedBox(width: 4),
              Text(m.badge
                      ? m.source!
                      : widget.am && m.source == 'City of Gondar'
                          ? 'ምንጭ፡ የጎንደር ከተማ'
                          : 'Source: ${m.source}',
                  style: const TextStyle(fontSize: 11,
                      color: AppColors.green, fontWeight: FontWeight.w600)),
            ]),
          ],
        ]),
      ),
    );
  }
}
