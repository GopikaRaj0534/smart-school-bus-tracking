// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ANSI Color formatting constants for integration test output
class TestColor {
  // Yellow for headings
  static const String yellow = '\x1B[33m';
  static const String boldYellow = '\x1B[1;33m';

  // Cyan or blue for test names
  static const String cyan = '\x1B[36m';
  static const String boldCyan = '\x1B[1;36m';

  // Green for successful test steps
  static const String green = '\x1B[32m';
  static const String boldGreen = '\x1B[1;32m';

  // Red for failed tests
  static const String red = '\x1B[31m';
  static const String boldRed = '\x1B[1;31m';

  // Reset formatting
  static const String reset = '\x1B[0m';
}

/// Helper for clean, customized, and colorful RouteSafe integration test terminal output.
class IntegrationTestLogger {
  static const String divider =
      '==================================================';

  static bool _verboseSuppressed = false;
  static final Set<String> _failedTests = <String>{};
  static final Set<String> _completedTests = <String>{};

  /// Suppresses unnecessary terminal output, including verbose logs,
  /// dependency messages, and debug messages wherever possible.
  static void suppressVerboseLogs() {
    if (_verboseSuppressed) return;
    _verboseSuppressed = true;

    // Suppress verbose debugPrint logs across Flutter and ApiService
    debugPrint = (String? message, {int? wrapWidth}) {};

    // Ensure stdout uses UTF-8 so checkmark/cross render properly across platforms
    try {
      stdout.encoding = utf8;
    } catch (_) {}
  }

  /// Displays the yellow heading block and cyan test name.
  static void startTest(String testName) {
    suppressVerboseLogs();
    _failedTests.remove(testName);
    _completedTests.remove(testName);

    print('\n${TestColor.boldYellow}$divider${TestColor.reset}');
    print('${TestColor.boldYellow}       ROOTSAFE INTEGRATION TESTING${TestColor.reset}');
    print('${TestColor.boldYellow}$divider${TestColor.reset}\n');
    print('${TestColor.boldCyan}Running: $testName${TestColor.reset}\n');
  }

  /// Displays a green checkmark step ONLY when the assertion or operation passes.
  static void logStep(String message) {
    print('${TestColor.green}✓ $message${TestColor.reset}');
  }

  /// Displays the green passed message and closing yellow divider.
  static void completeTest(String testName) {
    if (_failedTests.contains(testName)) {
      // Do not log passed if this test already recorded a failure
      return;
    }
    if (_completedTests.contains(testName)) {
      return;
    }
    _completedTests.add(testName);

    print('\n${TestColor.boldGreen}✓ $testName Passed${TestColor.reset}\n');
    print('${TestColor.boldYellow}$divider${TestColor.reset}\n');
  }

  /// Displays the red failure message and error details.
  static void logFailure(String testName, Object error, [StackTrace? stackTrace]) {
    _failedTests.add(testName);

    print('\n${TestColor.boldRed}✗ $testName Failed${TestColor.reset}');
    print('${TestColor.red}  Error details: $error${TestColor.reset}\n');
    print('${TestColor.boldYellow}$divider${TestColor.reset}\n');
  }

  /// Checks if a test has encountered a failure.
  static bool hasFailed(String testName) => _failedTests.contains(testName);

  /// Waits for an async condition to become true while yielding real wall-clock time
  /// to the Dart event loop so background HTTP network requests can complete.
  static Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 25),
    Duration pollInterval = const Duration(milliseconds: 300),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!condition() && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(pollInterval);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Safely extracts the visible SnackBar text if any is present on screen.
  static String? getSnackBarMessage(WidgetTester tester) {
    try {
      final snackBarFinder = find.byType(SnackBar);
      if (snackBarFinder.evaluate().isNotEmpty) {
        final textWidgets = find.descendant(
          of: snackBarFinder,
          matching: find.byType(Text),
        );
        if (textWidgets.evaluate().isNotEmpty) {
          final texts = <String>[];
          for (final elem in textWidgets.evaluate()) {
            final widget = elem.widget;
            if (widget is Text &&
                widget.data != null &&
                widget.data!.trim().isNotEmpty) {
              texts.add(widget.data!.trim());
            }
          }
          if (texts.isNotEmpty) {
            return texts.join(' - ');
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
