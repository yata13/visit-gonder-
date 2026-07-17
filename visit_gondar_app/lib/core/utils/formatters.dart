import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class Formatters {
  /// "2m ago", "1h ago", "3 days ago"
  static String timeAgo(DateTime date) => timeago.format(date);

  /// "$120 / night"
  static String pricePerNight(double price) =>
      '\$${price.toStringAsFixed(0)} / night';

  /// "1,200 ETB / day"
  static String priceETB(double price) =>
      '${NumberFormat('#,###').format(price)} ETB / day';

  /// "Jan 19, 2027"
  static String fullDate(DateTime date) =>
      DateFormat('MMM d, y').format(date);

  /// "4.8 (120 reviews)"
  static String ratingWithCount(double rating, int count) =>
      '${rating.toStringAsFixed(1)} ($count reviews)';

  /// Countdown: returns {"days": 142, "hours": 3, "mins": 45}
  static Map<String, int> countdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return {'days': 0, 'hours': 0, 'mins': 0};
    return {
      'days': diff.inDays,
      'hours': diff.inHours % 24,
      'mins': diff.inMinutes % 60,
    };
  }
}
