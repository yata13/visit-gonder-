// Ethiopian (Ge'ez) calendar — the design shows every date in BOTH
// calendars. The app language decides which one comes first.
import 'package:intl/intl.dart';

class EthDate {
  final int year, month, day; // month 1–13 (13 = Pagume)
  const EthDate(this.year, this.month, this.day);

  static const _monthsEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Ter', 'Yekatit', 'Megabit',
    'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
  ];
  static const _monthsAm = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
    'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ',
  ];

  /// Gregorian → Ethiopian via the Julian Day Number.
  factory EthDate.fromGregorian(DateTime g) {
    final a = (14 - g.month) ~/ 12;
    final y = g.year + 4800 - a;
    final m = g.month + 12 * a - 3;
    final jdn = g.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 +
        y ~/ 400 - 32045;
    final r = (jdn - 1723856) % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - 1723856) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    return EthDate(year, n ~/ 30 + 1, n % 30 + 1);
  }

  String monthName(bool am) => (am ? _monthsAm : _monthsEn)[month - 1];

  /// "Ter 11, 2019 E.C."  /  "ጥር 11 ቀን 2019 ዓ.ም."
  String format(bool am) => am
      ? '${monthName(true)} $day ቀን $year ዓ.ም.'
      : '${monthName(false)} $day, $year E.C.';

  /// Short form without the year: "Ter 11" / "ጥር 11".
  String short(bool am) => '${monthName(am)} $day';
}

/// Both calendars for one date: (first line, second line).
(String, String) dualDate(DateTime d, bool am) {
  final eth = EthDate.fromGregorian(d).format(am);
  final greg = DateFormat('MMM d, y').format(d);
  return am ? (eth, greg) : (greg, eth);
}
