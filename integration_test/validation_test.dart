import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:routesafe/screens/auth/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // TC03 - Login Form Validation
  // ============================================================

  testWidgets('TC03 - Login Form Validation', (tester) async {
    // Open Login Screen directly
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Click LOGIN without entering email or password
    await tester.tap(find.text('LOGIN'));

    await tester.pumpAndSettle();

    // Verify validation messages
    expect(
      find.text('Email is required'),
      findsOneWidget,
    );

    expect(
      find.text('Password is required'),
      findsOneWidget,
    );
  });
}