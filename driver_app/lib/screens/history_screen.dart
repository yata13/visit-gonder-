import 'package:flutter/material.dart';
import '../services/driver_api.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════
//  My finished trips and what I earned (cash fares), by day.
// ═══════════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>>? _rides;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DriverApi.myCompletedRides(limit: 300);
      if (mounted) {
        setState(() {
          _rides = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  static num _fare(Map<String, dynamic> r) => (r['fare_estimate'] as num?) ?? 0;

  @override
  Widget build(BuildContext context) {
    final rides = _rides;
    return Scaffold(
      appBar: AppBar(title: const Text('My trips & earnings')),
      body: rides == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: VG.brown)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, style: const TextStyle(color: VG.muted)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Try again')),
                    ]),
            )
          : RefreshIndicator(
              color: VG.brown,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  FadeIn(child: _Totals(rides: rides)),
                  const SizedBox(height: 18),
                  if (rides.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Column(children: [
                        Icon(Icons.receipt_long_rounded, size: 56, color: VG.line),
                        SizedBox(height: 12),
                        Text('No trips yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VG.ink)),
                        SizedBox(height: 4),
                        Text('Go online to get your first ride.', style: TextStyle(color: VG.muted)),
                      ]),
                    ),
                  ..._byDay(rides),
                ],
              ),
            ),
    );
  }

  List<Widget> _byDay(List<Map<String, dynamic>> rides) {
    final out = <Widget>[];
    DateTime? day;
    for (var i = 0; i < rides.length; i++) {
      final r = rides[i];
      final t = parseTime(r['completed_at']) ?? DateTime.now();
      if (day == null || !sameDay(day, t)) {
        day = t;
        final total = rides
            .where((x) => sameDay(parseTime(x['completed_at']) ?? DateTime.now(), t))
            .fold<num>(0, (s, x) => s + _fare(x));
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(children: [
            Text(dayLabel(t),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: VG.ink)),
            const Spacer(),
            Text(money(total), style: const TextStyle(fontWeight: FontWeight.w800, color: VG.brown)),
          ]),
        ));
      }
      out.add(FadeIn(delay: i < 8 ? i * 40 : 0, child: _TripTile(ride: r, at: t)));
    }
    return out;
  }
}

class _Totals extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  const _Totals({required this.rides});

  @override
  Widget build(BuildContext context) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    num all = 0, week = 0;
    for (final r in rides) {
      final f = (r['fare_estimate'] as num?) ?? 0;
      all += f;
      if ((parseTime(r['completed_at']) ?? DateTime(2000)).isAfter(weekAgo)) week += f;
    }
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            FittedBox(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VG.brown, Color(0xFF55301A)],
        ),
      ),
      child: Row(children: [
        stat('${rides.length}', 'Trips'),
        stat(money(week), 'Last 7 days'),
        stat(money(all), 'All time'),
      ]),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Map<String, dynamic> ride;
  final DateTime at;
  const _TripTile({required this.ride, required this.at});

  @override
  Widget build(BuildContext context) {
    final stars = ride['rider_rating'] as num?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 48,
            child: Text(clock(at),
                style: const TextStyle(fontWeight: FontWeight.w800, color: VG.muted)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${ride['pickup_label'] ?? 'Pickup'} → ${ride['dropoff_label'] ?? 'Destination'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: VG.ink)),
              const SizedBox(height: 3),
              Text(
                '${km((ride['distance_km'] as num?) ?? 0)}'
                '${(ride['rider_name'] ?? '').toString().isEmpty ? '' : ' · ${ride['rider_name']}'}',
                style: const TextStyle(color: VG.muted, fontSize: 13),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(ride['fare_estimate']),
                style: const TextStyle(fontWeight: FontWeight.w800, color: VG.brown, fontSize: 15.5)),
            if (stars != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < stars.toInt(); i++)
                  const Icon(Icons.star_rounded, color: VG.gold, size: 14),
              ]),
          ]),
        ]),
      ),
    );
  }
}
