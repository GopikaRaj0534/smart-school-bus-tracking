import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/screens/parent/parent_dashboard.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testTitle = 'Parent Dashboard Test';

  setUpAll(() {
    IntegrationTestLogger.startTest(testTitle);
  });

  tearDownAll(() {
    IntegrationTestLogger.completeTest(testTitle);
  });

  group('Parent Dashboard Integration Tests', () {
    testWidgets(
      'Verify Parent Dashboard loads and displays child, route, driver, and map sections',
      (tester) async {
        try {
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

          // 1. Verify Parent Portal Header & Welcome banner
          expect(find.textContaining('Parent Portal'), findsWidgets);
          expect(find.textContaining('Welcome'), findsWidgets);
          IntegrationTestLogger.logStep('Parent Dashboard Opened Successfully');

          // 2. Verify Child Information & Transport / Driver Details Section
          expect(find.textContaining('Transport'), findsWidgets);
          IntegrationTestLogger.logStep('Child Transport & Driver Information Displayed Successfully');

          // 3. Verify Bus Tracking / Map Section & ETA / Trip Status indicators
          expect(find.textContaining('ETA'), findsWidgets);
          IntegrationTestLogger.logStep('Live Bus Tracking & Map Section Initialized Successfully');

          // 4. Verify Route & Pickup Stop Request Section
          expect(find.textContaining('Route'), findsWidgets);
          IntegrationTestLogger.logStep('Route Details & Pickup Stop Information Displayed Successfully');
        } catch (e, st) {
          IntegrationTestLogger.logFailure(testTitle, e, st);
          rethrow;
        }
      },
    );

    testWidgets(
      'Verify Parent Login flow navigates to Parent Dashboard',
      (tester) async {
        try {
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
          IntegrationTestLogger.logStep('Parent Login & Navigation Tested Successfully');
        } catch (e, st) {
          IntegrationTestLogger.logFailure(testTitle, e, st);
          rethrow;
        }
      },
    );

    testWidgets(
      'Verify Call Driver button exists and responds to user tap',
      (tester) async {
        try {
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
          IntegrationTestLogger.logStep('Call Driver Action Response Verified Successfully');
        } catch (e, st) {
          IntegrationTestLogger.logFailure(testTitle, e, st);
          rethrow;
        }
      },
    );
  });
}
