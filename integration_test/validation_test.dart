import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testTitle = 'Login Form Validation Test';

  setUpAll(() {
    IntegrationTestLogger.startTest(testTitle);
  });

  tearDownAll(() {
    IntegrationTestLogger.completeTest(testTitle);
  });

  // ============================================================
  // TC03 - Login Form Validation
  // ============================================================

  testWidgets('TC03 - Login Form Validation', (tester) async {
    try {
      // Open Login Screen directly
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();
      IntegrationTestLogger.logStep('Login Screen Opened Successfully');

      // Click LOGIN without entering email or password
      await tester.tap(find.text('LOGIN'));

      await tester.pumpAndSettle();

      // Verify validation messages
      expect(
        find.text('Email is required'),
        findsOneWidget,
      );
      IntegrationTestLogger.logStep('Email Validation Rule Enforced Successfully');

      expect(
        find.text('Password is required'),
        findsOneWidget,
      );
      IntegrationTestLogger.logStep('Password Validation Rule Enforced Successfully');
      IntegrationTestLogger.logStep('Form Validation Rules Verified Successfully');
    } catch (e, st) {
      IntegrationTestLogger.logFailure(testTitle, e, st);
      rethrow;
    }
  });
}