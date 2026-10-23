import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  RIDES — tourist side. Bajaj / taxi rides from partner drivers
//  (Visit Gondar Driver app). Everything goes through the server
//  (migration 0017): the fare, the first driver to accept, and the
//  driver's live location on the ride row.
// ═══════════════════════════════════════════════════════════════

enum VehicleType { bajaj, taxi }

/// A ride is "live" from the request until the trip ends.
const liveRideStatuses = {'requested', 'accepted', 'arrived', 'in_progress'};

class RideQuote {
  final double distanceKm, fare;
  const RideQuote(this.distanceKm, this.fare);
}

/// A point on the map with a name ("My location", "Fasil Ghebbi"…).
class RidePlace {
  final String label;
  final LatLng point;
  const RidePlace(this.label, this.point);
}

class RideService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<RideQuote> quote(
      VehicleType type, LatLng pickup, LatLng dropoff) async {
    final res = await _db.rpc('ride_quote', params: {
      'p_vehicle_type': type.name,
      'p_pickup_lat': pickup.latitude,
      'p_pickup_lng': pickup.longitude,
      'p_dropoff_lat': dropoff.latitude,
      'p_dropoff_lng': dropoff.longitude,
    });
    final row = (res as List).first as Map;
    return RideQuote((row['distance_km'] as num).toDouble(),
        (row['fare'] as num).toDouble());
  }

  static Future<Map<String, dynamic>> request({
    required VehicleType type,
    required RidePlace pickup,
    required RidePlace dropoff,
    required String name,
    required String phone,
  }) async {
    final res = await _db.rpc('request_ride', params: {
      'p_vehicle_type': type.name,
      'p_pickup_lat': pickup.point.latitude,
      'p_pickup_lng': pickup.point.longitude,
      'p_pickup_label': pickup.label,
      'p_dropoff_lat': dropoff.point.latitude,
      'p_dropoff_lng': dropoff.point.longitude,
      'p_dropoff_label': dropoff.label,
      'p_rider_name': name,
      'p_rider_phone': phone,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> cancel(String rideId, {String? reason}) =>
      _db.rpc('cancel_ride', params: {'p_ride_id': rideId, 'p_reason': reason});

  static Future<void> rate(String rideId, int stars) =>
      _db.rpc('rate_ride', params: {'p_ride_id': rideId, 'p_stars': stars});
}

/// The signed-in visitor's most recent ride, live (driver position,
/// status changes). Null when they have never ridden. Realtime keeps
/// it current; an 8 s check backs it up if the live channel drops.
final myLatestRideProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  ref.watch(authStateProvider);
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return Stream.value(null);

  final out = StreamController<Map<String, dynamic>?>();
  void emit(List<Map<String, dynamic>> rows) {
    if (!out.isClosed) out.add(rows.isEmpty ? null : rows.first);
  }

  Future<void> check() async {
    try {
      final rows = await db
          .from('rides')
          .select()
          .eq('rider_id', uid)
          .order('created_at', ascending: false)
          .limit(1);
      emit(List<Map<String, dynamic>>.from(rows));
    } catch (_) {} // offline — the next tick tries again
  }

  final live = db
      .from('rides')
      .stream(primaryKey: ['id'])
      .eq('rider_id', uid)
      .order('created_at', ascending: false)
      .limit(1)
      .listen(emit, onError: (_) {});
  check();
  final timer = Timer.periodic(const Duration(seconds: 8), (_) => check());
  ref.onDispose(() {
    timer.cancel();
    live.cancel();
    out.close();
  });
  return out.stream;
});

/// Straight-line distance in km (for "driver is 1.2 km away").
double kmBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b) / 1000;

/// Rough city ETA: bajaj/taxi average ~18 km/h in Gondar traffic.
int etaMinutes(double km) => math.max(1, (km / 18 * 60).round());

/// How many bajaj / taxi drivers are online right now — no names, no
/// positions, just the count (so the app can show "3 bajaj online now"
/// before someone requests a ride). Polls since the drivers table
/// itself is private; refreshes every 12 s.
final onlineDriverCountsProvider =
    StreamProvider.autoDispose<Map<VehicleType, int>>((ref) {
  final out = StreamController<Map<VehicleType, int>>();
  final db = Supabase.instance.client;

  Future<void> check() async {
    try {
      final rows = await db.rpc('online_driver_counts') as List;
      final counts = <VehicleType, int>{
        VehicleType.bajaj: 0,
        VehicleType.taxi: 0,
      };
      for (final r in rows) {
        final type = r['vehicle_type'] == 'taxi' ? VehicleType.taxi : VehicleType.bajaj;
        counts[type] = (r['online_count'] as num?)?.toInt() ?? 0;
      }
      if (!out.isClosed) out.add(counts);
    } catch (_) {} // offline — keep showing the last known counts
  }

  check();
  final timer = Timer.periodic(const Duration(seconds: 12), (_) => check());
  ref.onDispose(() {
    timer.cancel();
    out.close();
  });
  return out.stream;
});
