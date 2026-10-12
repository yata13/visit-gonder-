import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/language_provider.dart';
import '../providers/weather_provider.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

// ── Weather card — today + the next 7 days (free for everyone) ──
class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = isAm(ref.watch(languageProvider));
    final async = ref.watch(weatherProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [BoxShadow(color: AppColors.charcoal.withAlpha(10),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(
              color: AppColors.gold, strokeWidth: 2)),
        ),
        error: (_, _) => Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(
              am ? 'የአየር ሁኔታ መረጃ አሁን አይገኝም' : 'Weather is unavailable right now',
              style: const TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () => ref.invalidate(weatherProvider),
            child: Text(am ? 'እንደገና' : 'Retry'),
          ),
        ]),
        data: (w) => _content(w, am),
      ),
    );
  }

  Widget _content(GondarWeather w, bool am) {
    final today = w.days.isNotEmpty ? w.days.first : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(WeatherService.icon(w.currentCode), color: AppColors.gold, size: 38),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(am ? 'ጎንደር ዛሬ' : 'Gondar weather today',
              style: const TextStyle(fontSize: 11, letterSpacing: 1.1,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text('${w.currentTemp.round()}°C · ${WeatherService.label(w.currentCode, am)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.charcoal)),
        ])),
        if (today != null)
          Text('${today.min.round()}° / ${today.max.round()}°',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
      ]),
      if (today != null) ...[
        const SizedBox(height: 8),
        Text(WeatherService.tip(today, am),
            style: const TextStyle(fontSize: 12.5, height: 1.35,
                color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final d in w.days) _day(d, am, d == today)],
      ),
    ]);
  }

  Widget _day(WeatherDay d, bool am, bool isToday) {
    final name = isToday
        ? (am ? 'ዛሬ' : 'Today')
        : DateFormat.E().format(d.date);
    return Column(children: [
      Text(name, style: TextStyle(fontSize: 11,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
          color: isToday ? AppColors.goldDark : AppColors.textMuted)),
      const SizedBox(height: 4),
      Icon(WeatherService.icon(d.code), size: 20, color: AppColors.rust),
      const SizedBox(height: 4),
      Text('${d.max.round()}°', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
      if (d.rainChance >= 30)
        Text('${d.rainChance}%', style: const TextStyle(
            fontSize: 9.5, color: Color(0xFF3D6DA8))),
    ]);
  }
}

/// Small pill for a plan day: icon + max temp + rain chance.
class WeatherChip extends StatelessWidget {
  final WeatherDay day;
  final bool am;
  const WeatherChip({super.key, required this.day, required this.am});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(WeatherService.icon(day.code), size: 15, color: AppColors.gold),
      const SizedBox(width: 4),
      Text(
        '${day.max.round()}° · ${WeatherService.label(day.code, am)}'
        '${day.rainChance >= 30 ? ' ${day.rainChance}%' : ''}',
        style: const TextStyle(color: Color(0xFFB3A899), fontSize: 11.5),
      ),
    ]);
  }
}
