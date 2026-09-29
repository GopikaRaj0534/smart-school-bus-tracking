import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/screens/parent/parent_dashboard.dart';
import 'package:routesafe/screens/parent/parent_transport_info_screen.dart';

void main() {
  testWidgets('ParentDashboard builds and renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ParentDashboard(
          userName: 'Anju',
          parentId: 15,
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(ParentDashboard), findsOneWidget);
  });

  testWidgets('ParentTransportInfoScreen builds and renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ParentTransportInfoScreen(
          parentId: 15,
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(ParentTransportInfoScreen), findsOneWidget);
  });
}
