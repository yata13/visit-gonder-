import 'dart:async';
import 'package:flutter/material.dart';
import '../services/driver_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'apply_screen.dart';
import 'home_screen.dart';
import 'pending_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  Which screen a signed-in driver sees, from their drivers row:
//    none      → apply (name, phone, vehicle, plate)
//    pending   → waiting for the Visit Gondar office
//    suspended → paused, call the office
//    approved  → home (go online, take rides)
//  The row is watched live, so approval opens the app by itself.
// ═══════════════════════════════════════════════════════════════
class DriverGate extends StatefulWidget {
  const DriverGate({super.key});
  @override
  State<DriverGate> createState() => _DriverGateState();
}

class _DriverGateState extends State<DriverGate> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  StreamSubscription<void>? _live;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _live = DriverApi.profileChanges().listen((_) => _load());
    // Backup for when the live channel drops on weak mobile data.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _live?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// Location pings change the row every few seconds; only rebuild
  /// for changes the screens show.
  static String _sig(Map<String, dynamic>? p) => p == null
      ? ''
      : [
          for (final k in const ['status', 'full_name', 'phone', 'vehicle_type', 'plate',
                                 'vehicle_desc', 'is_online', 'rating_sum', 'rating_count',
                                 'rides_completed'])
            '${p[k]}'
        ].join('|');

  Future<void> _load() async {
    try {
      final p = await DriverApi.myProfile();
      if (!mounted) return;
      if (_loading || _error != null || _sig(p) != _sig(_profile)) {
        setState(() {
          _profile = p;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      // Only the first load shows an error; later checks retry quietly.
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = errorText(e);
        });
      }
    }
  }

  void _set(Map<String, dynamic> row) => setState(() => _profile = row);

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final String stage;
    final Widget child;
    if (_loading) {
      stage = 'loading';
      child = const Scaffold(body: Center(child: CircularProgressIndicator(color: VG.brown)));
    } else if (p == null && _error != null) {
      stage = 'error';
      child = _Offline(message: _error!, onRetry: () {
        setState(() => _loading = true);
        _load();
      });
    } else if (p == null) {
      stage = 'apply';
      child = ApplyScreen(onSaved: _set);
    } else if (p['status'] == 'approved') {
      stage = 'home';
      child = HomeScreen(profile: p, onProfile: _set);
    } else {
      stage = 'pending';
      child = PendingScreen(profile: p, onProfile: _set);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(stage), child: child),
    );
  }
}

class _Offline extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Offline({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const BrandBadge(icon: Icons.wifi_off_rounded, color: VG.muted),
              const SizedBox(height: 22),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.5, color: VG.ink, height: 1.4)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              TextButton(onPressed: signOut, child: const Text('Sign out')),
            ]),
          ),
        ),
      );
}
