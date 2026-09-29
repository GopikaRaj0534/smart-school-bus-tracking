import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/main.dart';

void main() {
  testWidgets('RouteSafe app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RouteSafeApp());
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect(find.byType(RouteSafeApp), findsOneWidget);
  });
}
