import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'driver_api.dart';

// ═══════════════════════════════════════════════════════════════
//  Driver location: asks permission, then sends the position to the
//  server while online (at most every 8 s, and a heartbeat every
//  minute while parked, so the office sees who is really online).
//  During a trip the rider sees it move on their map.
// ═══════════════════════════════════════════════════════════════
class DriverLocation {
  static StreamSubscription<Position>? _sub;
  static Timer? _heartbeat;
  static DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  static LatLng? last;

  /// Null when allowed; otherwise a message for the driver.
  static Future<String?> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on your phone location (GPS) to go online.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return 'Allow location for VG Driver in your phone Settings to go online.';
      }
      return null;
    } catch (_) {
      return 'Location is not available on this device.';
    }
  }

  static Future<LatLng?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return last = LatLng(p.latitude, p.longitude);
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) return last = LatLng(p.latitude, p.longitude);
      } catch (_) {}
      return last;
    }
  }

  static void _send({required Duration ifOlderThan}) {
    final at = last, now = DateTime.now();
    if (at == null || now.difference(_lastSent) < ifOlderThan) return;
    _lastSent = now;
    DriverApi.updateLocation(at).catchError((_) {});
  }

  static void start() {
    stop();
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((p) {
        last = LatLng(p.latitude, p.longitude);
        _send(ifOlderThan: const Duration(seconds: 8));
      }, onError: (_) {});
    } catch (_) {}
    _heartbeat = Timer.periodic(const Duration(seconds: 60),
        (_) => _send(ifOlderThan: const Duration(seconds: 50)));
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
