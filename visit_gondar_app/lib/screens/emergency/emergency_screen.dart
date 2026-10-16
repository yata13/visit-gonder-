import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/location_service.dart';

// ═══════════════════════════════════════════════════════════════
//  EMERGENCY / SOS — design "SOS · hold to send".
//  • Grabs the user's saved details (name, phone, email) — no typing.
//  • Grabs the real device GPS location on open and at send time.
//  • Pick what is happening, then HOLD the red button for 3 seconds
//    to send the request (with live location) to the Safety Desk.
//  • Police 991 / Ambulance 907 can be called directly at the bottom.
// ═══════════════════════════════════════════════════════════════

// One kind of emergency. `type` is the value the admin dashboard
// filters on in `emergency_requests`.
class _Option {
  final String type, labelEn, labelAm;
  final IconData icon;
  const _Option(this.type, this.labelEn, this.labelAm, this.icon);
}

const _options = [
  _Option('police', 'Police', 'ፖሊስ', Icons.local_police_outlined),
  _Option('ambulance', 'Medical', 'ሕክምና', Icons.medical_services_outlined),
  _Option('fire', 'Fire', 'እሳት', Icons.local_fire_department_outlined),
  _Option('transport', 'Need a ride', 'መጓጓዣ', Icons.local_taxi_outlined),
];

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});
  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  // Lazy, so the screen still opens (with the call buttons) even if
  // Supabase could not start.
  SupabaseClient get db => Supabase.instance.client;
  AuthService? _authOrNull;
  AuthService get _auth => _authOrNull ??= AuthService();
  final _msgCtrl = TextEditingController();

  // Saved user details (filled in from their account)
  String _name = '', _phone = '', _email = '';

  // Live location
  LocationResult? _loc;
  bool _loadingLoc = true;

  int _type = 0;
  bool _showNote = false;
  bool _sending = false;
  bool _sent = false;
  String _sentLabel = '';

  // Hold-to-send ring (3 seconds).
  late final AnimationController _hold = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        _submit(_options[_type]);
      }
    });

  bool get _am => isAm(ref.read(languageProvider));

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchLocation();
  }

  @override
  void dispose() {
    _hold.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    Map<String, String> p;
    try {
      p = await _auth.profile();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _name = p['name'] ?? '';
      _phone = p['phone'] ?? '';
      _email = p['email'] ?? '';
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLoc = true);
    final r = await LocationService.current();
    if (!mounted) return;
    setState(() { _loc = r; _loadingLoc = false; });
  }

  // Make sure we have a phone number; if the account has none (older
  // sign-ups), ask once and save it to the profile forever.
  Future<bool> _ensurePhone() async {
    if (_phone.trim().isNotEmpty) return true;
    final am = _am;
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(am ? 'የስልክ ቁጥርዎ' : 'Your phone number'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              am
                  ? 'ምላሽ ሰጪው እንዲያገኝዎ። አንድ ጊዜ ብቻ ያስገባሉ።'
                  : 'So the responder can reach you. We save it to your '
                      'profile so you only enter it once.',
              style: const TextStyle(fontSize: 14, color: AppColors.ink700)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(hintText: '+251 9xx xxx xxx'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(am ? 'ሰርዝ' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              child: Text(am ? 'አስቀምጥ' : 'Save')),
        ],
      ),
    );
    if (entered == null || entered.trim().isEmpty) return false;
    setState(() => _phone = entered.trim());
    try {
      await _auth.savePhone(_phone);
    } catch (_) {/* still send with the number we have */}
    return true;
  }

  Future<void> _submit(_Option o) async {
    final am = _am;
    if (!await _ensurePhone()) {
      _hold.reset();
      _toast(am ? 'እርዳታ እንዲደርስዎ ስልክ ቁጥር ያስፈልጋል'
          : 'A phone number is needed so help can reach you');
      return;
    }
    setState(() => _sending = true);

    // Make sure we have a fresh fix.
    if (_loc == null || !_loc!.ok) await _fetchLocation();
    final pos = _loc?.position;
    final locText = pos != null
        ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
            '  (https://maps.google.com/?q=${pos.latitude},${pos.longitude})'
        : 'Location unavailable';

    // Log the request. Try the full row; if the table is missing the
    // newer columns, fall back to the base columns so it still saves.
    final base = {
      'type': o.type,
      'name': _name,
      'phone': _phone,
      'message': _msgCtrl.text.trim(),
      'location': locText,
      'status': 'pending',
    };
    final full = {
      ...base,
      'email': _email,
      'user_id': SupabaseService.safeUser?.id,
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
    };
    try {
      await db.from('emergency_requests').insert(full);
    } on PostgrestException {
      try {
        await db.from('emergency_requests').insert(base);
      } catch (e) {
        _afterSend(o, error: e);
        return;
      }
    } catch (e) {
      _afterSend(o, error: e);
      return;
    }
    _afterSend(o);
  }

  void _afterSend(_Option o, {Object? error}) {
    if (!mounted) return;
    if (error != null) {
      _hold.reset();
      setState(() => _sending = false);
      _toast(_am
          ? 'መላክ አልተቻለም። ፖሊስ 991 ይደውሉ።'
          : 'Could not send. Please call Police 991.');
      return;
    }
    setState(() {
      _sent = true;
      _sentLabel = _am ? o.labelAm : o.labelEn;
      _sending = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _call(String number) => launchUrl(Uri.parse('tel:$number'),
      mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final am = isAm(ref.watch(languageProvider));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: _sent ? _buildSuccess(am) : _buildBody(am),
      ),
      bottomNavigationBar: _sent ? null : _callBar(am),
    );
  }

  // ── Dark bottom bar: direct calls ──
  Widget _callBar(bool am) {
    Widget btn(String label, String number) => Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink700,
              foregroundColor: Colors.white,
              textStyle: AppFonts.button(15, FontWeight.w700),
            ),
            onPressed: () => _call(number),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text('$label $number'),
          ),
        );
    return Container(
      color: AppColors.ink,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            btn(am ? 'ፖሊስ' : 'Police', '991'),
            const SizedBox(width: 10),
            btn(am ? 'አምቡላንስ' : 'Ambulance', '907'),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody(bool am) {
    return Stack(children: [
      Column(children: [
        // Header
        SizedBox(
          height: 64,
          child: Row(children: [
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
              label: Text(am ? 'ሰርዝ' : 'Cancel'),
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  textStyle: AppFonts.button(15, FontWeight.w700)),
            ),
            Expanded(
              child: Text(am ? 'የአደጋ ጊዜ እርዳታ' : 'Emergency help',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dangerInk)),
            ),
            const SizedBox(width: 16),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              Text(
                  am
                      ? 'ቀዩን ቁልፍ ለ3 ሰከንድ ይያዙ። አካባቢዎን ለደህንነት ዴስክ እንልካለን።'
                      : 'Hold the red button for 3 seconds. We send your '
                          'location to the Safety Desk.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.45,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              Center(child: _holdButton(am)),
              const SizedBox(height: 22),

              Text(am ? 'ምን እየሆነ ነው?' : 'What is happening?',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _options.length; i++)
                  Semantics(
                    selected: i == _type,
                    button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _type = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: i == _type ? AppColors.ink : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: i == _type ? AppColors.ink
                                  : const Color(0xFF8C8C8C),
                              width: 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_options[i].icon, size: 18,
                              color: i == _type ? Colors.white
                                  : AppColors.ink),
                          const SizedBox(width: 6),
                          Text(am ? _options[i].labelAm : _options[i].labelEn,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: i == _type
                                      ? FontWeight.w800 : FontWeight.w600,
                                  color: i == _type ? Colors.white
                                      : AppColors.ink)),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),

              _locCard(am),
              const SizedBox(height: 14),

              if (_showNote)
                TextField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: am ? 'ማስታወሻ' : 'Note',
                    hintText: am ? 'ምን እየሆነ ነው?'
                        : 'What is happening? (optional)',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showNote = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(am ? 'ማስታወሻ ጨምር' : 'Add a note'),
                ),
              const SizedBox(height: 16),

              // What the responder receives
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ground,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(am ? 'ለምላሽ ሰጪው የሚላከው'
                          : 'We send these to the responder',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 8),
                  _detail(Icons.person_outline,
                      _name.isEmpty ? (am ? 'ስምዎ' : 'Your name') : _name),
                  _detail(Icons.phone_outlined,
                      _phone.isEmpty
                          ? (am ? 'ሲልኩ አንድ ጊዜ ይጠየቃል'
                              : 'Asked once when you send')
                          : _phone),
                  if (_email.isNotEmpty) _detail(Icons.email_outlined, _email),
                ]),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _call('939'),
                child: Text(am ? 'የእሳት አደጋ 939 ይደውሉ' : 'Fire brigade: call 939'),
              ),
            ],
          ),
        ),
      ]),
      if (_sending)
        Container(
          color: Colors.black54,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
    ]);
  }

  // ── The big hold-to-send button with a progress ring ──
  Widget _holdButton(bool am) {
    return Semantics(
      button: true,
      label: am ? 'SOS ለመላክ ለ3 ሰከንድ ይያዙ' : 'Hold for 3 seconds to send SOS',
      onLongPress: () => _submit(_options[_type]),
      child: Listener(
        onPointerDown: (_) {
          if (_sending) return;
          HapticFeedback.mediumImpact();
          _hold.forward(from: 0);
        },
        onPointerUp: (_) {
          if (!_hold.isCompleted) _hold.reverse();
        },
        onPointerCancel: (_) {
          if (!_hold.isCompleted) _hold.reverse();
        },
        child: SizedBox(
          width: 208,
          height: 208,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (_, _) => Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 196,
                height: 196,
                child: CircularProgressIndicator(
                  value: _hold.value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color: AppColors.sos,
                  backgroundColor: AppColors.dangerTint,
                ),
              ),
              Transform.scale(
                scale: 1 - _hold.value * 0.04,
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    color: AppColors.sos,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: AppColors.sos.withValues(alpha: 0.35),
                        blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Text('SOS',
                        style: TextStyle(color: Colors.white, fontSize: 40,
                            height: 1, fontWeight: FontWeight.w800,
                            letterSpacing: 2.4)),
                    const SizedBox(height: 4),
                    Text(am ? 'ይያዙ' : 'HOLD',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(am ? '3 ሰከንድ' : '3 seconds',
                        style: const TextStyle(color: Color(0xFFFFE5E2),
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Location card ──
  Widget _locCard(bool am) {
    final ok = _loc?.ok == true;
    final text = _loadingLoc
        ? (am ? 'አካባቢዎን በማግኘት ላይ…' : 'Getting your location…')
        : ok
            ? (am ? 'ዝግጁ — የት እንዳሉ እናውቃለን'
                : 'Ready — we know where you are')
            : (_loc?.error ?? (am ? 'አካባቢ አልተገኘም' : 'Location unavailable'));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _loadingLoc
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: ok ? AppColors.locationBlue : AppColors.muted,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(am ? 'የእርስዎ አካባቢ' : 'Your location',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.muted)),
            Text(text,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
        if (!_loadingLoc && !ok)
          TextButton(
            onPressed: _fetchLocation,
            child: Text(am ? 'እንደገና' : 'Retry'),
          ),
      ]),
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, color: AppColors.muted, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
    ]),
  );

  Widget _buildSuccess(bool am) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.safeTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.safe, size: 56),
          ),
          const SizedBox(height: 24),
          Text(am ? 'ለደህንነት ዴስክ ተልኳል' : 'Sent to the Safety Desk',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_sentLabel,
              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 14),
          Text(
            am
                ? 'እርዳታ ስምዎን፣ ስልክዎን እና አካባቢዎን አግኝቷል።\n'
                    'ደህንነቱ የተጠበቀ ከሆነ ባሉበት ይቆዩ። ብቻዎን አይደሉም።'
                : 'Help has your name, phone and live location.\n'
                    'Stay where you are if it is safe. You are not alone.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.6,
                color: AppColors.ink700),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _call('991'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sos),
              icon: const Icon(Icons.call_outlined),
              label: Text(am ? 'ፖሊስ 991 ይደውሉ' : 'Call Police 991'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52)),
              child: Text(am ? 'ወደ መተግበሪያው ተመለስ' : 'Back to the app'),
            ),
          ),
        ]),
      ),
    );
  }
}
