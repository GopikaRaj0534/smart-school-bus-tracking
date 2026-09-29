import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/screens/parent/parent_dashboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Parent Dashboard Integration Tests', () {
    testWidgets('Verify Parent Dashboard loads and displays child, route, driver, and map sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ParentDashboard(
            userName: 'Anju',
            parentId: 15,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 1. Verify Parent Portal Header
      expect(find.textContaining('Parent Portal'), findsWidgets);

      // 2. Verify Welcome banner
      expect(find.textContaining('Welcome'), findsWidgets);

      // 3. Verify Child Information & Transport / Driver Details Section
      expect(find.textContaining('Transport'), findsWidgets);

      // 4. Verify Bus Tracking / Map Section & ETA / Trip Status indicators
      expect(find.textContaining('ETA'), findsWidgets);

      // 5. Verify Route & Pickup Stop Request Section
      expect(find.textContaining('Route'), findsWidgets);
    });

    testWidgets('Verify Parent Login flow navigates to Parent Dashboard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Select Parent Role if choice chip is present
      final parentChip = find.text('Parent');
      if (parentChip.evaluate().isNotEmpty) {
        await tester.tap(parentChip.first);
        await tester.pumpAndSettle();
      }

      // Enter Parent Credentials
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'anju@gmail.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'anju123',
      );

      // Tap LOGIN
      await tester.tap(find.text('LOGIN'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 2));

      // Login attempt completed
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Verify Call Driver button exists and responds to user tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ParentDashboard(
            userName: 'Anju',
            parentId: 15,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      final callDriverBtn = find.textContaining('Call Driver');
      expect(callDriverBtn, findsWidgets);

      await tester.tap(callDriverBtn.first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(ParentDashboard), findsOneWidget);
    });
  });
}
