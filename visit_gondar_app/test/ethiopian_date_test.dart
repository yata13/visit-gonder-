import 'package:flutter_test/flutter_test.dart';
import 'package:visit_gondar/core/utils/ethiopian_date.dart';

void main() {
  test('Timket 2027 is Ter 11, 2019 E.C.', () {
    final e = EthDate.fromGregorian(DateTime(2027, 1, 19));
    expect([e.year, e.month, e.day], [2019, 5, 11]);
    expect(e.format(false), 'Ter 11, 2019 E.C.');
    expect(e.format(true), 'ጥር 11 ቀን 2019 ዓ.ም.');
  });

  test('Ethiopian new year and Pagume 6 in a leap year', () {
    final newYear = EthDate.fromGregorian(DateTime(2026, 9, 11));
    expect([newYear.year, newYear.month, newYear.day], [2019, 1, 1]);
    final pagume6 = EthDate.fromGregorian(DateTime(2027, 9, 11));
    expect([pagume6.year, pagume6.month, pagume6.day], [2019, 13, 6]);
  });

  test('dualDate puts the app language calendar first', () {
    final d = DateTime(2027, 1, 19);
    expect(dualDate(d, false), ('Jan 19, 2027', 'Ter 11, 2019 E.C.'));
    expect(dualDate(d, true), ('ጥር 11 ቀን 2019 ዓ.ም.', 'Jan 19, 2027'));
  });
}
