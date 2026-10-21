import 'package:flutter_test/flutter_test.dart';
import 'package:visit_gondar_driver/main.dart';

void main() {
  testWidgets('shows the setup screen when the keys are missing', (tester) async {
    await tester.pumpWidget(const DriverApp(ready: false));
    expect(find.text('Almost ready'), findsOneWidget);
  });
}
