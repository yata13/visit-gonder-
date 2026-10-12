import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
//  LIVE WEATHER — today + the next 7 days for Gondar, from
//  Open-Meteo (free, no API key). The same forecast is shown on
//  the City dashboard and given to the Ask Gondar AI.
// ═══════════════════════════════════════════════════════════════
class WeatherDay {
  final DateTime date;
  final int code;
  final double min, max;
  final int rainChance; // %
  const WeatherDay(this.date, this.code, this.min, this.max, this.rainChance);
}

class GondarWeather {
  final double currentTemp;
  final int currentCode;
  final List<WeatherDay> days;
  const GondarWeather(this.currentTemp, this.currentCode, this.days);

  /// Forecast for a calendar day, if it is inside the 7-day window.
  WeatherDay? forDate(DateTime d) {
    for (final w in days) {
      if (w.date.year == d.year && w.date.month == d.month && w.date.day == d.day) {
        return w;
      }
    }
    return null;
  }
}

class WeatherService {
  static const lat = 12.6030, lng = 37.4521; // Gondar

  static final _url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng'
      '&current=temperature_2m,weather_code'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=Africa%2FAddis_Ababa&forecast_days=7');

  static Future<GondarWeather> fetch() async {
    final res = await http.get(_url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Weather unavailable (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final times = (d['time'] as List).cast<String>();
    num at(String key, int i) => ((d[key] as List)[i] ?? 0) as num;
    return GondarWeather(
      (cur['temperature_2m'] as num).toDouble(),
      (cur['weather_code'] as num).toInt(),
      [
        for (int i = 0; i < times.length; i++)
          WeatherDay(
            DateTime.parse(times[i]),
            at('weather_code', i).toInt(),
            at('temperature_2m_min', i).toDouble(),
            at('temperature_2m_max', i).toDouble(),
            at('precipitation_probability_max', i).toInt(),
          ),
      ],
    );
  }

  /// WMO weather code → icon.
  static IconData icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.wb_cloudy_outlined;
    if (code == 3) return Icons.cloud_rounded;
    if (code <= 48) return Icons.foggy;
    if (code <= 67 || (code >= 80 && code <= 82)) return Icons.umbrella_rounded;
    if (code <= 77) return Icons.ac_unit_rounded;
    return Icons.thunderstorm_rounded;
  }

  /// WMO weather code → short label (English / Amharic).
  static String label(int code, bool am) {
    if (code == 0) return am ? 'ፀሐያማ' : 'Sunny';
    if (code <= 2) return am ? 'በከፊል ደመናማ' : 'Partly cloudy';
    if (code == 3) return am ? 'ደመናማ' : 'Cloudy';
    if (code <= 48) return am ? 'ጭጋግ' : 'Fog';
    if (code <= 67 || (code >= 80 && code <= 82)) return am ? 'ዝናብ' : 'Rain';
    if (code <= 77) return am ? 'በረዶ' : 'Snow';
    return am ? 'ነጎድጓድ' : 'Storm';
  }

  /// One practical tip for the day, like the proposal's
  /// "Rain after 3 pm — see the churches first."
  static String tip(WeatherDay d, bool am) {
    if (d.rainChance >= 60 || d.code >= 61) {
      return am
          ? 'ዝናብ ይጠበቃል — በጠዋት ወጥተው ከሰዓት በኋላ ቤተክርስቲያናትና ሙዚየሞችን ይጎብኙ።'
          : 'Rain likely — go out early, keep churches and museums for the afternoon.';
    }
    if (d.max >= 28) {
      return am
          ? 'ሞቃት ቀን — ውሃ ይያዙ፣ ቤተመንግሥቱን በጠዋት ይጎብኙ።'
          : 'Hot day — carry water and visit the castles in the morning.';
    }
    return am
        ? 'ለጉብኝት ጥሩ ቀን — ፋሲል ግቢን እና ፋሲለደስ መታጠቢያን ይጎብኙ።'
        : 'Good day for sightseeing — Fasil Ghebbi and Fasilides Bath.';
  }
}
