import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

// ═══════════════════════════════════════════════════════════════
//  EMERGENCY / SOS
//  • Grabs the user's saved details (name, phone, email) — no typing.
//  • Grabs the real device GPS location on open and at send time.
//  • One tap on Taxi / Police / Ambulance / Fire sends help.
//    Police / Ambulance / Fire ALSO dial the national number.
// ═══════════════════════════════════════════════════════════════

// A single emergency option. `dial` is the national number to call
// (null for taxi/ride, which is handled in-app only).
class _Option {
  final String type, label, sub;
  final IconData icon;
  final Color color;
  final String? dial;
  const _Option(this.type, this.label, this.sub, this.icon, this.color,
      [this.dial]);
}

const _options = [
  _Option('transport', 'Taxi / Ride', 'A car comes to you',
      Icons.local_taxi_rounded, Color(0xFF6A1B9A)),
  _Option('police', 'Police', 'Calls 991', Icons.local_police_rounded,
      Color(0xFF1565C0), '991'),
  _Option('ambulance', 'Ambulance', 'Calls 907', Icons.medical_services_rounded,
      Color(0xFF2E7D32), '907'),
  _Option('fire', 'Fire', 'Calls 939', Icons.local_fire_department_rounded,
      Color(0xFFD84315), '939'),
];

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  final db = Supabase.instance.client;
  final _auth = AuthService();
  final _msgCtrl = TextEditingController();

  // Saved user details (filled in from their account)
  String _name = '', _phone = '', _email = '';

  // Live location
  LocationResult? _loc;
  bool _loadingLoc = true;

  bool _sending = false;
  bool _sent = false;
  String _sentLabel = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadProfile();
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await _auth.profile();
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
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1414),
        title: const Text('Your phone number',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'So the responder can reach you. We save it to your profile so you only enter it once.',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '+251 9xx xxx xxx',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text('Save')),
        ],
      ),
    );
    if (entered == null || entered.trim().isEmpty) return false;
    setState(() => _phone = entered.trim());
    await _auth.savePhone(_phone);
    return true;
  }

  // Tap a card → show a short confirm sheet → send.
  void _pick(_Option o) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          CircleAvatar(radius: 28, backgroundColor: o.color,
              child: Icon(o.icon, color: Colors.white, size: 28)),
          const SizedBox(height: 12),
          Text(o.label, style: const TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            o.dial != null
                ? 'We will call ${o.dial} and send your name, phone and live location.'
                : 'We will send your name, phone and live location to our team.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13.5,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          _locChip(),
          const SizedBox(height: 14),
          TextField(
            controller: _msgCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a note (optional) — what is happening?',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _submit(o); },
              style: ElevatedButton.styleFrom(
                backgroundColor: o.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(o.dial != null ? 'Call & send help' : 'Send request',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _submit(_Option o) async {
    if (!await _ensurePhone()) {
      _toast('A phone number is needed so help can reach you', Colors.orange);
      return;
    }
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    // Make sure we have a fresh fix.
    if (_loc == null || !_loc!.ok) await _fetchLocation();
    final pos = _loc?.position;
    final locText = pos != null
        ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
            '  (https://maps.google.com/?q=${pos.latitude},${pos.longitude})'
        : 'Location unavailable';

    // Dial the national number first (police / ambulance / fire).
    if (o.dial != null) {
      try {
        await launchUrl(Uri.parse('tel:${o.dial}'),
            mode: LaunchMode.externalApplication);
      } catch (_) {/* user can still see the number on screen */}
    }

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
      'user_id': _auth.currentUser?.id,
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
      setState(() => _sending = false);
      _toast('Could not send: $error', Colors.red);
      return;
    }
    setState(() { _sent = true; _sentLabel = o.label; _sending = false; });
  }

  void _toast(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0A),
      body: SafeArea(child: _sent ? _buildSuccess() : _buildBody()),
    );
  }

  // ── Location status chip ──
  Widget _locChip() {
    late final Color c;
    late final String text;
    late final IconData icon;
    if (_loadingLoc) {
      c = Colors.amber; icon = Icons.gps_fixed; text = 'Getting your location…';
    } else if (_loc?.ok == true) {
      c = Colors.green; icon = Icons.location_on;
      text = 'Location ready — we know where you are';
    } else {
      c = Colors.redAccent; icon = Icons.location_off;
      text = _loc?.error ?? 'Location unavailable';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(80)),
      ),
      child: Row(children: [
        _loadingLoc
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.amber))
            : Icon(icon, color: c, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(color: c, fontSize: 12.5,
                fontWeight: FontWeight.w600))),
        if (!_loadingLoc && _loc?.ok != true)
          GestureDetector(
            onTap: _fetchLocation,
            child: const Text('Retry',
                style: TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    return Stack(children: [
      SingleChildScrollView(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF3D0000), Color(0xFF1A0A0A)],
              ),
            ),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Expanded(
                  child: Text('Emergency Help',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 24),
              ]),
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.red,
                    boxShadow: [BoxShadow(color: Colors.red.withAlpha(120),
                        blurRadius: 30, spreadRadius: 8)],
                  ),
                  child: const Center(
                    child: Text('SOS', style: TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _name.isEmpty ? 'You are not alone' : 'Hi $_name, you are not alone',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Text('Tap what you need — we already have your details',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),

          // Location status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _locChip(),
          ),

          // Options grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('What do you need?',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: _options.map(_card).toList(),
              ),
            ]),
          ),

          // Your details (read-only summary — no typing needed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Row(children: [
                  Icon(Icons.badge_outlined, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Text('We will send these to the responder',
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                _detail(Icons.person_outline,
                    _name.isEmpty ? 'Your name' : _name),
                _detail(Icons.phone_outlined,
                    _phone.isEmpty ? 'Asked once when you send' : _phone),
                if (_email.isNotEmpty) _detail(Icons.email_outlined, _email),
                const SizedBox(height: 12),
                const Row(children: [
                  Icon(Icons.info_outline, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Text('Ethiopia Emergency Numbers',
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                _num('🚓 Police', '991'),
                _num('🚑 Ambulance', '907'),
                _num('🚒 Fire', '939'),
              ]),
            ),
          ),
        ]),
      ),
      if (_sending)
        Container(
          color: Colors.black54,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
    ]);
  }

  Widget _card(_Option o) {
    return GestureDetector(
      onTap: _sending ? null : () => _pick(o),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: o.color.withAlpha(28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: o.color.withAlpha(110), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 20, backgroundColor: o.color,
              child: Icon(o.icon, color: Colors.white, size: 22)),
          const Spacer(),
          Text(o.label, style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(o.sub, style: const TextStyle(color: Colors.white54,
              fontSize: 11.5)),
        ]),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );

  Widget _num(String label, String number) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12))),
      GestureDetector(
        onTap: () => launchUrl(Uri.parse('tel:$number'),
            mode: LaunchMode.externalApplication),
        child: Text(number, style: const TextStyle(color: Colors.white,
            fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 52),
          ),
          const SizedBox(height: 24),
          Text('$_sentLabel request sent!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const Text(
            'Help has your name, phone and live location.\nStay where you are if it is safe.\n\nStay calm — you are not alone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to App',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
