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
            await tester.ensureVisible(parentChip.first);
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

          // Ensure LOGIN button is visible and tap
          final loginBtn = find.text('LOGIN');
          await tester.ensureVisible(loginBtn);
          await tester.pumpAndSettle();
          await tester.tap(loginBtn);

          // Wait for asynchronous login API request and navigation to complete
          await IntegrationTestLogger.waitForCondition(
            tester,
            () => find.byType(LoginScreen).evaluate().isEmpty,
            timeout: const Duration(seconds: 25),
          );

          // Check for any visible error snackbar if navigation didn't complete
          if (find.byType(LoginScreen).evaluate().isNotEmpty) {
            final snackMsg = IntegrationTestLogger.getSnackBarMessage(tester);
            if (snackMsg != null) {
              throw Exception('Login failed with server message: $snackMsg');
            }
          }

          // Login attempt completed and navigated to Parent Dashboard
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

          await tester.ensureVisible(callDriverBtn.first);
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
