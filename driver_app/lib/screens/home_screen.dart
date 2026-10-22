import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/alerts.dart';
import '../services/driver_api.dart';
import '../services/location.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'active_ride_view.dart';
import 'apply_screen.dart';
import 'history_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  Home for an approved driver.
//    Offline → today's numbers + "Go online".
//    Online  → live list of tourists' requests (sound + notification
//              for each new one); Accept → the active ride view.
//  Requests come from the server every 5 s and instantly through the
//  live channel; the first driver to accept gets the ride.
// ═══════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onProfile;
  const HomeScreen({super.key, required this.profile, required this.onProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late bool _online = widget.profile['is_online'] == true;
  bool _switching = false, _loaded = false, _refreshing = false, _again = false;
  String? _netError, _accepting;
  Map<String, dynamic>? _active;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _done = [];
  final _seen = <String>{};

  /// Bumped on every change made here, so an older check that comes
  /// back later cannot undo it.
  int _gen = 0;
  int _tick = 0;
  Timer? _poll;
  StreamSubscription<void>? _live;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _live = DriverApi.changes('rides').listen((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      _tick++;
      if (_online || _active != null || _tick % 6 == 0) _refresh();
    });
    _refresh();
    _loadDone();
    if (_online) _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _live?.cancel();
    DriverLocation.stop();
    _keepAwake(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  // ── Data ──────────────────────────────────────────────────
  Future<void> _refresh() async {
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    final gen = _gen;
    try {
      final active = await DriverApi.myActiveRide();
      final requests = _online && active == null
          ? await DriverApi.openRequests()
          : const <Map<String, dynamic>>[];
      if (!mounted || gen != _gen) return;
      final before = _active;
      if (before != null && active?['id'] != before['id']) {
        _explainEnded('${before['id']}');
      }
      if (_online && active == null) _announce(requests);
      setState(() {
        _active = active;
        _requests = requests;
        _loaded = true;
        _netError = null;
      });
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _loaded = true;
          _netError = errorText(e);
        });
      }
    } finally {
      _refreshing = false;
      if (_again && mounted) {
        _again = false;
        _refresh();
      }
    }
  }

  Future<void> _loadDone() async {
    try {
      final rows = await DriverApi.myCompletedRides(limit: 200);
      if (mounted) setState(() => _done = rows);
    } catch (_) {}
  }

  double? _away(Map<String, dynamic> r) {
    final me = DriverLocation.last, p = pointOf(r, 'pickup_lat', 'pickup_lng');
    return me == null || p == null ? null : kmBetween(me, p);
  }

  /// Rings for requests this driver has not seen yet.
  void _announce(List<Map<String, dynamic>> rows) {
    final fresh = [for (final r in rows) if (_seen.add('${r['id']}')) r];
    if (fresh.isEmpty) return;
    if (fresh.length == 1) {
      final r = fresh.first, away = _away(r);
      Alerts.newRide(
        'New ride · ${money(r['fare_estimate'])}',
        '${r['pickup_label'] ?? 'Pickup'} → ${r['dropoff_label'] ?? 'Destination'}'
        '${away == null ? '' : ' · ${km(away)} from you'}',
      );
    } else {
      Alerts.newRide('${fresh.length} new ride requests', 'Open VG Driver and accept one.');
    }
  }

  /// My ride vanished from "active" without me doing it.
  Future<void> _explainEnded(String id) async {
    try {
      final r = await DriverApi.ride(id);
      if (!mounted || r == null || r['status'] != 'cancelled') return;
      final title = r['cancelled_by'] == 'admin'
          ? 'The Visit Gondar office cancelled this ride'
          : '${r['rider_name'] ?? 'The rider'} cancelled the ride';
      final reason = '${r['cancel_reason'] ?? ''}'.trim();
      final body = reason.isEmpty ? 'You are free for the next request.' : 'Reason: $reason';
      Alerts.update(title, body);
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.cancel_outlined, color: VG.danger, size: 44),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(body, textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } catch (_) {}
  }

  // ── Online / offline ──────────────────────────────────────
  void _keepAwake(bool on) {
    try {
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
    } catch (_) {}
  }

  /// Was online when the app closed: carry on where we left off.
  Future<void> _resume() async {
    final problem = await DriverLocation.ensurePermission();
    if (!mounted) return;
    if (problem != null) {
      showSnack(context, problem, error: true);
      _toggle(false);
      return;
    }
    DriverLocation.start();
    _keepAwake(true);
    final at = await DriverLocation.current();
    if (at != null) DriverApi.updateLocation(at).catchError((_) {});
  }

  Future<void> _toggle(bool on) async {
    if (_switching) return;
    if (!on && _active != null) {
      showSnack(context, 'Finish or hand back your ride first.');
      return;
    }
    setState(() => _switching = true);
    try {
      if (on) {
        final problem = await DriverLocation.ensurePermission();
        if (problem != null) {
          if (mounted) showSnack(context, problem, error: true);
          return;
        }
        final at = await DriverLocation.current();
        final row = await DriverApi.setOnline(true, at: at);
        DriverLocation.start();
        _keepAwake(true);
        _gen++;
        _online = true;
        _seen.clear();
        widget.onProfile(row);
        HapticFeedback.mediumImpact();
        _refresh();
      } else {
        final row = await DriverApi.setOnline(false);
        DriverLocation.stop();
        _keepAwake(false);
        _gen++;
        _online = false;
        _requests = [];
        widget.onProfile(row);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  // ── Ride actions ──────────────────────────────────────────
  Future<void> _accept(Map<String, dynamic> r) async {
    if (_accepting != null) return;
    setState(() => _accepting = '${r['id']}');
    try {
      final row = await DriverApi.accept('${r['id']}');
      _gen++;
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _active = row;
          _requests = [];
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      _refresh();
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  Future<void> _advance(String status) async {
    final r = _active;
    if (r == null) return;
    try {
      final row = await DriverApi.advance('${r['id']}', status);
      _gen++;
      if (!mounted) return;
      if (status == 'completed') {
        setState(() {
          _active = null;
          _done = [row, ..._done];
        });
        _showDone(row);
        _refresh();
      } else {
        setState(() => _active = row);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      _refresh();
    }
  }

  Future<void> _handBack(String? reason) async {
    final r = _active;
    if (r == null) return;
    try {
      await DriverApi.handBack('${r['id']}', reason: reason);
      _gen++;
      if (!mounted) return;
      setState(() => _active = null);
      showSnack(context, 'Ride handed back. Other drivers can take it now.');
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      _refresh();
    }
  }

  void _showDone(Map<String, dynamic> r) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: VG.online, size: 52),
        title: const Text('Trip complete', textAlign: TextAlign.center),
        content: Text(
          'Collect ${money(r['fare_estimate'])} in cash from '
          '${r['rider_name'] ?? 'the rider'}.\nThank you for driving with Visit Gondar!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15.5, height: 1.4),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ],
      ),
    );
  }

  // ── Menu ──────────────────────────────────────────────────
  Future<void> _menu(String choice) async {
    switch (choice) {
      case 'history':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
      case 'edit':
        final row = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (_) => ApplyScreen(existing: widget.profile)),
        );
        if (row != null) widget.onProfile(row);
      case 'signout':
        if (_active != null) {
          showSnack(context, 'Finish or hand back your ride first.');
          return;
        }
        if (_online) {
          try {
            await DriverApi.setOnline(false);
          } catch (_) {}
        }
        await signOut();
    }
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final type = p['vehicle_type'] as String?;
    final active = _active;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: VG.brown, shape: BoxShape.circle),
            child: Icon(vehicleIcon(type), color: VG.gold, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VG Driver'),
              Text('${p['plate'] ?? ''} · ${vehicleName(type)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: VG.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded),
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: ListTile(
                  leading: Icon(Icons.receipt_long_rounded), title: Text('My trips & earnings'))),
              PopupMenuItem(value: 'edit', child: ListTile(
                  leading: Icon(Icons.edit_outlined), title: Text('My details'))),
              PopupMenuItem(value: 'signout', child: ListTile(
                  leading: Icon(Icons.logout_rounded), title: Text('Sign out'))),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        child: active != null
            ? ActiveRideView(
                key: ValueKey('ride-${active['id']}'),
                ride: active,
                onAdvance: _advance,
                onHandBack: _handBack,
              )
            : _lobby(),
      ),
    );
  }

  Widget _lobby() {
    final p = widget.profile;
    final now = DateTime.now();
    final today = _done.where((r) {
      final t = parseTime(r['completed_at']);
      return t != null && sameDay(t, now);
    }).toList();
    final earned = today.fold<num>(0, (s, r) => s + ((r['fare_estimate'] as num?) ?? 0));
    final count = (p['rating_count'] as num?) ?? 0;
    final rating = count == 0 ? null : ((p['rating_sum'] as num? ?? 0) / count);
    final requests = [..._requests];
    if (DriverLocation.last != null) {
      requests.sort((a, b) => (_away(a) ?? 1e9).compareTo(_away(b) ?? 1e9));
    }
    final first = '${p['full_name'] ?? ''}'.trim().split(' ').first;

    return RefreshIndicator(
      key: const ValueKey('lobby'),
      color: VG.brown,
      onRefresh: () async {
        await _refresh();
        await _loadDone();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeIn(
            child: _OnlineCard(
              online: _online,
              busy: _switching,
              name: first,
              onTap: () => _toggle(!_online),
            ),
          ),
          const SizedBox(height: 12),
          FadeIn(delay: 80, child: _TodayStrip(rides: today.length, earned: earned, rating: rating)),
          const SizedBox(height: 22),
          if (_online) ...[
            Row(children: [
              const Text('Ride requests',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: VG.ink)),
              const SizedBox(width: 10),
              const LiveDot(),
              const Spacer(),
              if (requests.isNotEmpty)
                Text('${requests.length} open',
                    style: const TextStyle(color: VG.muted, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            if (_netError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VG.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded, color: VG.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_netError!, style: const TextStyle(color: VG.danger))),
                ]),
              ),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: VG.brown)),
              )
            else if (requests.isEmpty)
              const _Waiting()
            else
              for (final (i, r) in requests.indexed)
                FadeIn(
                  key: ValueKey('req-${r['id']}'),
                  delay: i < 4 ? i * 60 : 0,
                  child: _RequestCard(
                    ride: r,
                    away: _away(r),
                    busy: _accepting == '${r['id']}',
                    locked: _accepting != null,
                    onAccept: () => _accept(r),
                  ),
                ),
          ] else
            const FadeIn(delay: 140, child: _HowItWorks()),
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  final bool online, busy;
  final String name;
  final VoidCallback onTap;
  const _OnlineCard({required this.online, required this.busy, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = online
        ? const [Color(0xFF239157), Color(0xFF14573A)]
        : const [VG.brown, Color(0xFF55301A)];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(online ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
              color: online ? Colors.white : VG.gold, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(online ? "You're online" : "You're offline",
                style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          ),
          if (online) const LiveDot(color: Colors.white),
        ]),
        const SizedBox(height: 6),
        Text(
          online
              ? 'Tourists near you can request you. Keep this app open — new requests ring like a call.'
              : '${name.isEmpty ? 'Hello' : 'Hello $name'}! Go online to get ride requests from tourists.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5, height: 1.35),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: online ? Colors.white : VG.gold,
              foregroundColor: online ? VG.online : VG.deep,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: busy ? null : onTap,
            icon: busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: VG.brown))
                : Icon(online ? Icons.pause_circle_outline_rounded : Icons.power_settings_new_rounded),
            label: Text(online ? 'Go offline' : 'Go online'),
          ),
        ),
      ]),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  final int rides;
  final num earned;
  final double? rating;
  const _TodayStrip({required this.rides, required this.earned, this.rating});

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Icon(icon, color: VG.gold, size: 22),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VG.ink)),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12.5, color: VG.muted)),
            ]),
          ),
        );
    return Row(children: [
      tile('$rides', 'Trips today', Icons.route_rounded),
      const SizedBox(width: 10),
      tile(money(earned), 'Earned today', Icons.payments_rounded),
      const SizedBox(width: 10),
      tile(rating == null ? 'New' : rating!.toStringAsFixed(1), 'Rating', Icons.star_rounded),
    ]);
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final double? away;
  final bool busy, locked;
  final VoidCallback onAccept;
  const _RequestCard({
    required this.ride,
    required this.away,
    required this.busy,
    required this.locked,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final trip = (ride['distance_km'] as num?) ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(money(ride['fare_estimate']),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: VG.brown)),
            const Spacer(),
            Pill(icon: Icons.schedule_rounded, text: timeAgo(ride['created_at'])),
          ]),
          const SizedBox(height: 12),
          RouteLines(from: ride['pickup_label'] as String?, to: ride['dropoff_label'] as String?),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (away != null)
              Pill(icon: Icons.near_me_rounded, text: '${km(away!)} to pickup', color: VG.blue),
            Pill(icon: Icons.route_rounded, text: '${km(trip)} trip', color: VG.brown),
            if ((ride['rider_name'] ?? '').toString().isNotEmpty)
              Pill(icon: Icons.person_rounded, text: '${ride['rider_name']}'),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: VG.online),
              onPressed: locked ? null : onAccept,
              icon: busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded),
              label: Text(busy ? 'Accepting…' : 'Accept ride'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Online with no requests: a calm "listening" pulse.
class _Waiting extends StatefulWidget {
  const _Waiting();
  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Stack(alignment: Alignment.center, children: [
                for (final shift in const [0.0, 0.5])
                  Builder(builder: (_) {
                    final t = (_c.value + shift) % 1;
                    return Container(
                      width: 40 + 80 * t,
                      height: 40 + 80 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VG.online.withValues(alpha: 0.18 * (1 - t)),
                      ),
                    );
                  }),
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: VG.online, shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Waiting for ride requests…',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: VG.ink)),
          const SizedBox(height: 6),
          const Text(
            'Keep VG Driver open. You will hear a sound and see a notification '
            'as soon as a tourist near you needs a ride.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VG.muted, height: 1.4),
          ),
        ]),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: VG.goldTint, shape: BoxShape.circle),
              child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, color: VG.brown)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: VG.ink, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: VG.muted, height: 1.35)),
              ]),
            ),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How it works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VG.ink)),
          const SizedBox(height: 6),
          step(1, 'Go online', 'Tourists in Gondar see that a driver is near and request a ride in the Visit Gondar app.'),
          step(2, 'Accept a request', 'The first driver to accept gets it. The rider\'s name and phone appear, and they see you coming on their map.'),
          step(3, 'Pick up and drive', 'Tap "I\'ve arrived", then "Start trip". Use Navigate for Google Maps directions.'),
          step(4, 'Get paid in cash', 'Complete the trip and collect the price shown. The rider rates you.'),
        ]),
      ),
    );
  }
}
