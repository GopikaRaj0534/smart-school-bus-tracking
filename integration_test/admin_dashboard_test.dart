import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/admin/admin_dashboard.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testTitle = 'Admin Dashboard Test';

  setUpAll(() {
    IntegrationTestLogger.startTest(testTitle);
  });

  tearDownAll(() {
    IntegrationTestLogger.completeTest(testTitle);
  });

  group('Admin Dashboard Integration Tests', () {
    testWidgets(
      'Verify Admin Dashboard loads with driver, bus, assignment, and analytics management sections',
      (tester) async {
        try {
          await tester.pumpWidget(
            const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: AdminDashboard(
                userName: 'Admin User',
              ),
            ),
          );

          await tester.pumpAndSettle();

          // 1. Verify Admin Header & Welcome Banner
          expect(find.textContaining('Admin Dashboard'), findsOneWidget);
          expect(find.textContaining('Welcome, Admin User'), findsOneWidget);
          IntegrationTestLogger.logStep('Admin Dashboard Opened Successfully');

          // 2. Verify Management & Approvals Sections
          expect(find.text('Pending Driver Approvals'), findsOneWidget);
          expect(find.text('Manage Drivers'), findsOneWidget);
          expect(find.text('Manage Buses'), findsOneWidget);
          expect(find.text('Manage Routes & Pickup Stops'), findsOneWidget);
          expect(find.text('Link Parent & Student / Assign Bus'), findsOneWidget);
          expect(find.text('Manage Parents'), findsOneWidget);
          IntegrationTestLogger.logStep('Admin Dashboard UI Loaded Successfully');

          // 3. Verify Fleet Overview Stat Cards Grid & Analytics
          expect(find.text('Total Buses'), findsOneWidget);
          expect(find.text('Drivers'), findsOneWidget);
          expect(find.text('Parents'), findsOneWidget);
          expect(find.text('Students'), findsOneWidget);
          expect(find.text('Active Trips'), findsOneWidget);
          expect(find.text('Analytics & Fleet Metrics'), findsOneWidget);
          expect(find.text('Interactive Fleet Analytics & Charts'), findsOneWidget);
          IntegrationTestLogger.logStep('Admin Statistics Displayed Successfully');
        } catch (e, st) {
          IntegrationTestLogger.logFailure(testTitle, e, st);
          rethrow;
        }
      },
    );

    testWidgets(
      'Verify Admin Login flow navigates to Admin Dashboard',
      (tester) async {
        try {
          await tester.pumpWidget(
            const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: LoginScreen(),
            ),
          );

          await tester.pumpAndSettle();

          // Select Admin Role Chip
          final adminChip = find.text('Admin');
          if (adminChip.evaluate().isNotEmpty) {
            await tester.ensureVisible(adminChip.first);
            await tester.tap(adminChip.first);
            await tester.pumpAndSettle();
          }

          // Enter Admin Credentials
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'admin@gmail.com',
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'admin123',
          );

          // Tap LOGIN
          final loginBtn = find.text('LOGIN');
          await tester.ensureVisible(loginBtn);
          await tester.pumpAndSettle();
          await tester.tap(loginBtn);

          // Wait for asynchronous login network response and navigation to complete
          await IntegrationTestLogger.waitForCondition(
            tester,
            () => find.byType(LoginScreen).evaluate().isEmpty,
            timeout: const Duration(seconds: 25),
          );

          // Check for any visible error snackbar if navigation didn't complete
          if (find.byType(LoginScreen).evaluate().isNotEmpty) {
            final snackMsg = IntegrationTestLogger.getSnackBarMessage(tester);
            if (snackMsg != null) {
              throw Exception('Admin login failed with server message: $snackMsg');
            }
          }

          // Login attempt completed and navigated away from LoginScreen
          expect(find.byType(LoginScreen), findsNothing);
          IntegrationTestLogger.logStep('Navigation Tested Successfully');
        } catch (e, st) {
          IntegrationTestLogger.logFailure(testTitle, e, st);
          rethrow;
        }
      },
    );
  });
}
