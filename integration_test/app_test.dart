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
      final loginBtn = find.text('LOGIN');
      await tester.ensureVisible(loginBtn);
      await tester.pumpAndSettle();
      await tester.tap(loginBtn);

      // Wait for asynchronous login API response and navigation to complete
      await IntegrationTestLogger.waitForCondition(
        tester,
        () => find.byType(LoginScreen).evaluate().isEmpty,
        timeout: const Duration(seconds: 25),
      );

      // Check for visible error snackbar if navigation didn't complete
      if (find.byType(LoginScreen).evaluate().isNotEmpty) {
        final snackMsg = IntegrationTestLogger.getSnackBarMessage(tester);
        if (snackMsg != null) {
          throw Exception('Parent login failed with server message: $snackMsg');
        }
      }

      // Login should proceed without crashing
      expect(find.byType(LoginScreen), findsNothing);
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
      final loginBtn = find.text('LOGIN');
      await tester.ensureVisible(loginBtn);
      await tester.pumpAndSettle();
      await tester.tap(loginBtn);

      // Wait for invalid login response (remains on LoginScreen or shows SnackBar)
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

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