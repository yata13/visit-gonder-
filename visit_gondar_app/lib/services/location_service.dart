import 'package:geolocator/geolocator.dart';

// ═══════════════════════════════════════════════════════════════
//  LocationService — gets the real device GPS location, handling
//  the permission dance. Returns a small result so the UI can show
//  a clear message instead of just failing silently.
// ═══════════════════════════════════════════════════════════════
class LocationResult {
  final Position? position;   // null when we couldn't get a fix
  final String? error;        // human-readable reason when position is null
  const LocationResult({this.position, this.error});

  bool get ok => position != null;
}

class LocationService {
  // Ask permission (if needed) and return the current position.
  static Future<LocationResult> current() async {
    // 1. Is the phone's location (GPS) switched on at all?
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      return const LocationResult(
          error: 'Location is turned off. Please turn on your phone\'s GPS.');
    }

    // 2. Do we have permission? Ask if not.
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return const LocationResult(
          error: 'Location permission denied. We need it to send help to you.');
    }
    if (perm == LocationPermission.deniedForever) {
      return const LocationResult(
          error:
              'Location permission is blocked. Enable it in your phone Settings.');
    }

    // 3. Get the fix.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(position: pos);
    } catch (_) {
      // Fall back to the last known position if the live fix times out.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationResult(position: last);
      return const LocationResult(
          error: 'Could not get your location. Try again in an open area.');
    }
  }
}
