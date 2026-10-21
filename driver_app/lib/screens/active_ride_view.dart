import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/driver_api.dart';
import '../services/location.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  The ride I'm driving: map (me → pickup → destination), the rider
//  with a call button, Google Maps directions, and the steps:
//    accepted → "I've arrived" → "Start trip" → "Complete trip".
//  The rider sees each step and my position live in their app.
// ═══════════════════════════════════════════════════════════════
class ActiveRideView extends StatefulWidget {
  final Map<String, dynamic> ride;
  final Future<void> Function(String status) onAdvance;
  final Future<void> Function(String? reason) onHandBack;
  const ActiveRideView({
    super.key,
    required this.ride,
    required this.onAdvance,
    required this.onHandBack,
  });

  @override
  State<ActiveRideView> createState() => _ActiveRideViewState();
}

class _ActiveRideViewState extends State<ActiveRideView> {
  final _map = MapController();
  bool _busy = false, _mapReady = false;
  Timer? _tick;

  Map<String, dynamic> get _r => widget.ride;
  String get _status => '${_r['status']}';
  bool get _onTrip => _status == 'in_progress';
  LatLng? get _pickup => pointOf(_r, 'pickup_lat', 'pickup_lng');
  LatLng? get _dropoff => pointOf(_r, 'dropoff_lat', 'dropoff_lng');
  LatLng? get _me => DriverLocation.last ?? pointOf(_r, 'driver_lat', 'driver_lng');
  LatLng? get _target => _onTrip ? _dropoff : _pickup;

  @override
  void initState() {
    super.initState();
    // Moves my own marker as the phone's position changes.
    _tick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ActiveRideView old) {
    super.didUpdateWidget(old);
    if (old.ride['status'] != widget.ride['status']) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Shows me and where I'm going next.
  void _frame() {
    if (!_mapReady || !mounted) return;
    final pts = [?_me, ?_target];
    if (pts.isEmpty) return;
    if (pts.length == 1 || kmBetween(pts.first, pts.last) < 0.05) {
      _map.move(pts.last, 16);
      return;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 40),
      maxZoom: 17,
    ));
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate() async {
    final t = _target;
    if (t == null) return;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${t.latitude},${t.longitude}&travelmode=driving');
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) showSnack(context, 'Could not open Google Maps.', error: true);
  }

  Future<void> _call() async {
    final phone = '${_r['rider_phone'] ?? ''}'.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return;
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {}
    if (!opened && mounted) showSnack(context, 'Could not start the call. The number is $phone.');
  }

  Future<void> _complete() async {
    final ok = await confirm(
      context,
      title: 'Complete the trip?',
      message: 'Only when the rider is at the destination. '
          'Collect ${money(_r['fare_estimate'])} in cash.',
      yes: 'Complete trip',
    );
    if (ok) await _run(() => widget.onAdvance('completed'));
  }

  Future<void> _handBack() async {
    const reasons = [
      'My vehicle has a problem',
      'The pickup is too far',
      'I cannot reach the rider',
      'Something else',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VG.cream,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Text('Hand back this ride?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: VG.ink)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text('Other drivers get the request again and the rider is told. Why?',
                style: TextStyle(color: VG.muted, height: 1.35)),
          ),
          for (final r in reasons)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: const Icon(Icons.undo_rounded, color: VG.danger),
              title: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, r),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (reason == null) return;
    await _run(() => widget.onHandBack(reason));
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickup, dropoff = _dropoff, me = _me, target = _target;
    final rider = '${_r['rider_name'] ?? ''}'.trim();
    final phone = '${_r['rider_phone'] ?? ''}'.trim();
    final toTarget = me != null && target != null ? kmBetween(me, target) : null;
    final (String title, String sub, Color color, IconData icon) = switch (_status) {
      'arrived' => (
          'Waiting for the rider',
          '${rider.isEmpty ? 'The rider' : rider} was told you are here.',
          const Color(0xFFB7832F),
          Icons.hail_rounded,
        ),
      'in_progress' => (
          'Trip in progress',
          'Drive to ${_r['dropoff_label'] ?? 'the destination'}.',
          VG.online,
          Icons.route_rounded,
        ),
      _ => (
          'Go to the pickup',
          '${rider.isEmpty ? 'The rider' : rider} waits at ${_r['pickup_label'] ?? 'the pickup point'}.',
          VG.blue,
          Icons.near_me_rounded,
        ),
    };

    return Column(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: target ?? pickup ?? const LatLng(Config.gondarLat, Config.gondarLng),
                initialZoom: 15,
                minZoom: 11,
                maxZoom: 18,
                onMapReady: () {
                  _mapReady = true;
                  _frame();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: Config.mapTiles,
                  userAgentPackageName: 'com.visitgondar.driver',
                  maxNativeZoom: 19,
                ),
                PolylineLayer(polylines: [
                  if (pickup != null && dropoff != null)
                    Polyline(
                      points: [pickup, dropoff],
                      color: VG.brown.withValues(alpha: _onTrip ? 0.95 : 0.4),
                      strokeWidth: _onTrip ? 4 : 3,
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  if (!_onTrip && me != null && pickup != null)
                    Polyline(
                      points: [me, pickup],
                      color: VG.blue,
                      strokeWidth: 4,
                      pattern: const StrokePattern.dotted(),
                    ),
                ]),
                MarkerLayer(markers: [
                  if (pickup != null)
                    Marker(point: pickup, width: 28, height: 28, child: const _Dot(color: VG.online)),
                  if (dropoff != null)
                    Marker(
                      point: dropoff,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.flag_rounded, color: VG.brown, size: 36),
                    ),
                  if (me != null)
                    Marker(
                      point: me,
                      width: 44,
                      height: 44,
                      child: _MePin(icon: vehicleIcon(_r['vehicle_type'] as String?)),
                    ),
                ]),
                const SimpleAttributionWidget(
                  alignment: Alignment.topLeft,
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: 'frame-ride',
              tooltip: 'Show me and the next stop',
              backgroundColor: Colors.white,
              foregroundColor: VG.brown,
              onPressed: _frame,
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
        ]),
      ),

      // ── Panel ─────────────────────────────────────────────
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
        decoration: const BoxDecoration(
          color: VG.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, -4))],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 14 + MediaQuery.paddingOf(context).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: Row(key: ValueKey(_status), children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: VG.ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: VG.muted, height: 1.3)),
                  ]),
                ),
                if (toTarget != null && _status != 'arrived')
                  Text(km(toTarget),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ]),
            ),
            const SizedBox(height: 14),

            // Rider
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: VG.goldTint,
                  child: Text(rider.isEmpty ? '?' : rider[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: VG.brown, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rider.isEmpty ? 'Visit Gondar rider' : rider,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: VG.ink)),
                    if (phone.isNotEmpty)
                      Text(phone, style: const TextStyle(color: VG.muted, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (phone.isNotEmpty)
                  IconButton.filled(
                    tooltip: 'Call the rider',
                    style: IconButton.styleFrom(backgroundColor: VG.online, minimumSize: const Size(50, 50)),
                    onPressed: _call,
                    icon: const Icon(Icons.call_rounded, color: Colors.white),
                  ),
              ]),
            ),
            const SizedBox(height: 10),

            // Route + price
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                RouteLines(from: _r['pickup_label'] as String?, to: _r['dropoff_label'] as String?),
                const Divider(height: 22, color: VG.line),
                Row(children: [
                  Pill(
                    icon: Icons.route_rounded,
                    text: '${km((_r['distance_km'] as num?) ?? 0)} trip',
                    color: VG.brown,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(children: [
                          const Text('Collect in cash  ', style: TextStyle(color: VG.muted)),
                          Text(money(_r['fare_estimate']),
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800, color: VG.brown)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            // Steps
            OutlinedButton.icon(
              onPressed: target == null ? null : _navigate,
              icon: const Icon(Icons.navigation_rounded),
              label: Text(_onTrip ? 'Navigate to destination' : 'Navigate to pickup'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: _onTrip ? FilledButton.styleFrom(backgroundColor: VG.online) : null,
              onPressed: _busy
                  ? null
                  : switch (_status) {
                      'accepted' => () => _run(() => widget.onAdvance('arrived')),
                      'arrived' => () => _run(() => widget.onAdvance('in_progress')),
                      _ => _complete,
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Icon(switch (_status) {
                      'accepted' => Icons.where_to_vote_rounded,
                      'arrived' => Icons.play_arrow_rounded,
                      _ => Icons.flag_circle_rounded,
                    }),
              label: Text(switch (_status) {
                'accepted' => "I've arrived",
                'arrived' => 'Start trip',
                _ => 'Complete trip · ${money(_r['fare_estimate'])}',
              }),
            ),
            if (_status == 'accepted')
              TextButton(
                onPressed: _busy ? null : () => _run(() => widget.onAdvance('in_progress')),
                child: const Text('The rider is already with me — start trip'),
              ),
            if (!_onTrip)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: VG.danger),
                onPressed: _busy ? null : _handBack,
                child: const Text('Hand back this ride'),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)],
        ),
      );
}

class _MePin extends StatelessWidget {
  final IconData icon;
  const _MePin({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: VG.brown,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
        ),
        child: Icon(icon, color: VG.gold, size: 24),
      );
}
