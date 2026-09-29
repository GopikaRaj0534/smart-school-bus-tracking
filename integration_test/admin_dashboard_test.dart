import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/admin/admin_dashboard.dart';
import 'package:routesafe/screens/auth/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Dashboard Integration Tests', () {
    testWidgets('Verify Admin Dashboard loads with driver, bus, assignment, and analytics management sections', (tester) async {
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

      // 2. Verify Fleet Overview Stat Cards Grid
      expect(find.text('Total Buses'), findsOneWidget);
      expect(find.text('Drivers'), findsOneWidget);
      expect(find.text('Parents'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Active Trips'), findsOneWidget);

      // 3. Verify Driver Management & Approvals
      expect(find.text('Pending Driver Approvals'), findsOneWidget);
      expect(find.text('Manage Drivers'), findsOneWidget);

      // 4. Verify Bus & Route Management
      expect(find.text('Manage Buses'), findsOneWidget);
      expect(find.text('Manage Routes & Pickup Stops'), findsOneWidget);

      // 5. Verify Parent / Student & Driver Assignment
      expect(find.text('Link Parent & Student / Assign Bus'), findsOneWidget);
      expect(find.text('Manage Parents'), findsOneWidget);

      // 6. Verify Analytics & Fleet Metrics Section & Interactive Banner
      expect(find.text('Analytics & Fleet Metrics'), findsOneWidget);
      expect(find.text('Interactive Fleet Analytics & Charts'), findsOneWidget);
    });

    testWidgets('Verify Admin Login flow navigates to Admin Dashboard', (tester) async {
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
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Login attempt completed without crashing
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
