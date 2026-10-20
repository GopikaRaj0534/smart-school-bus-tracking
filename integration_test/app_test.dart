import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testTitle = 'App Authentication & Login Test';

  setUpAll(() {
    IntegrationTestLogger.startTest(testTitle);
  });

  tearDownAll(() {
    IntegrationTestLogger.completeTest(testTitle);
  });

  // ============================================================
  // TC01 - Valid Parent Login
  // ============================================================

  testWidgets('TC01 - Valid Parent Login', (tester) async {
    try {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check Login screen
      expect(find.text('Welcome back'), findsOneWidget);
      IntegrationTestLogger.logStep('Login Screen Opened Successfully');

      // Enter email
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'anju@gmail.com',
      );

      // Enter password
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'anju123',
      );

      // Tap LOGIN
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle(
        const Duration(seconds: 5),
      );

      // Login should proceed without crashing
      expect(find.text('LOGIN'), findsNothing);
      IntegrationTestLogger.logStep('Valid Parent Credentials Authenticated Successfully');
    } catch (e, st) {
      IntegrationTestLogger.logFailure(testTitle, e, st);
      rethrow;
    }
  });

  // ============================================================
  // TC02 - Invalid Parent Login
  // ============================================================

  testWidgets('TC02 - Invalid Parent Login', (tester) async {
    try {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check Login screen
      expect(find.text('Welcome back'), findsOneWidget);

      // Enter wrong email
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'wrongparent@gmail.com',
      );

      // Enter wrong password
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrongpassword123',
      );

      // Tap LOGIN
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle(
        const Duration(seconds: 5),
      );

      // Login screen should remain
      expect(find.text('Welcome back'), findsOneWidget);
      IntegrationTestLogger.logStep('Invalid Credentials Rejected Successfully');
      IntegrationTestLogger.logStep('Authentication Security Guard Enforced Successfully');
    } catch (e, st) {
      IntegrationTestLogger.logFailure(testTitle, e, st);
      rethrow;
    }
  });
}