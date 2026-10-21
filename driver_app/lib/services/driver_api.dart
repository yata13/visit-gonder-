import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════
//  The driver side of the shared Visit Gondar rides service
//  (supabase/migrations/0017). Every change is a server function:
//  the server decides who gets a ride, the price and the steps.
// ═══════════════════════════════════════════════════════════════

const activeRideStatuses = ['accepted', 'arrived', 'in_progress'];

class DriverApi {
  static SupabaseClient get db => Supabase.instance.client;
  static String? get uid => db.auth.currentUser?.id;

  // ── Profile ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> myProfile() async {
    final id = uid;
    if (id == null) return null;
    final row = await db.from('drivers').select().eq('user_id', id).maybeSingle();
    return row;
  }

  static Future<Map<String, dynamic>> apply({
    required String fullName,
    required String phone,
    required String vehicleType,
    required String plate,
    String? vehicleDesc,
  }) async {
    final res = await db.rpc('driver_apply', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_vehicle_type': vehicleType,
      'p_plate': plate,
      'p_vehicle_desc': vehicleDesc,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> setOnline(bool online, {LatLng? at}) async {
    final res = await db.rpc('driver_set_online', params: {
      'p_online': online,
      'p_lat': at?.latitude,
      'p_lng': at?.longitude,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> updateLocation(LatLng at) => db.rpc('driver_update_location',
      params: {'p_lat': at.latitude, 'p_lng': at.longitude});

  // ── Rides ─────────────────────────────────────────────────
  /// Open requests for my vehicle type, newest first. The server
  /// picks them on its own clock and expires old ones (0019).
  static Future<List<Map<String, dynamic>>> openRequests() async {
    final rows = await db.rpc('driver_open_requests', params: const {});
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<Map<String, dynamic>?> ride(String id) =>
      db.from('rides').select().eq('id', id).maybeSingle();

  /// My ride in progress, if any.
  static Future<Map<String, dynamic>?> myActiveRide() async {
    final id = uid;
    if (id == null) return null;
    final rows = await db
        .from('rides')
        .select()
        .eq('driver_id', id)
        .inFilter('status', activeRideStatuses)
        .order('accepted_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  static Future<List<Map<String, dynamic>>> myCompletedRides({int limit = 50}) async {
    final id = uid;
    if (id == null) return [];
    final rows = await db
        .from('rides')
        .select()
        .eq('driver_id', id)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> accept(String rideId) async {
    final res = await db.rpc('driver_accept_ride', params: {'p_ride_id': rideId});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> advance(String rideId, String status) async {
    final res = await db.rpc('driver_advance_ride',
        params: {'p_ride_id': rideId, 'p_status': status});
    return Map<String, dynamic>.from(res as Map);
  }

  /// Hands the ride back to other drivers.
  static Future<void> handBack(String rideId, {String? reason}) =>
      db.rpc('cancel_ride', params: {'p_ride_id': rideId, 'p_reason': reason});

  /// Fires when rows I may see change in [table] (new requests, my
  /// ride, my profile) — screens then re-check. Polling backs it up.
  static Stream<void> changes(String table, {PostgresChangeFilter? filter}) {
    final out = StreamController<void>.broadcast();
    final channel = db
        .channel('driver-$table-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) {
            if (!out.isClosed) out.add(null);
          },
        )
      ..subscribe();
    out.onCancel = () {
      db.removeChannel(channel);
      out.close();
    };
    return out.stream;
  }

  static Stream<void> profileChanges() => changes('drivers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid ?? '',
      ));
}

/// Distance in km between two points.
double kmBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b) / 1000;

LatLng? pointOf(Map<String, dynamic> row, String lat, String lng) {
  final a = row[lat], b = row[lng];
  if (a is! num || b is! num) return null;
  return LatLng(a.toDouble(), b.toDouble());
}

/// Friendly message from a server error.
String errorText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return 'No connection. Please try again.';
}
