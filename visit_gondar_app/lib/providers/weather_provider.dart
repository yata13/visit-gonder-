import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/weather_service.dart';

/// Gondar forecast. Kept for the session; pull-to-refresh or
/// `ref.invalidate(weatherProvider)` fetches it again.
final weatherProvider = FutureProvider<GondarWeather>((ref) {
  return WeatherService.fetch();
});
