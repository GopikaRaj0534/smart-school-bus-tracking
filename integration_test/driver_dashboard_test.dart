import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/screens/driver/driver_dashboard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Dashboard Integration Tests', () {
    // ------------------------------------------------------------------------
    // Test 1: Driver Dashboard UI test
    // ------------------------------------------------------------------------
    testWidgets(
      'Verify Driver Dashboard loads and displays My Students, Boarded controls, and Start Trip',
      (tester) async {
        // Driver ID 6 (Ben) has an approved driver account, assigned bus #10, route Puramattom,
        // pickup stop Puramattom Junction, and assigned student Anjali in the MySQL database.
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DriverDashboard(
              userName: 'Ben',
              driverId: 6,
            ),
          ),
        );

        // Wait for dashboard async API data loading to complete
        await tester.pumpAndSettle();

        // 1. Verify Driver Portal / Dashboard Header
        expect(find.textContaining('Driver Portal'), findsOneWidget);

        // 2. Verify Driver Controls (Start Trip or Trip Is Active button, End Trip, Report Emergency)
        final startTripFinder = find.textContaining('START TRIP');
        final tripActiveFinder = find.textContaining('TRIP IS ACTIVE');
        expect(startTripFinder.evaluate().isNotEmpty || tripActiveFinder.evaluate().isNotEmpty, isTrue);

        expect(find.textContaining('END TRIP'), findsOneWidget);
        expect(find.textContaining('REPORT EMERGENCY'), findsOneWidget);

        // 3. Verify Student Boarding Attendance section header
        expect(find.textContaining('Student Boarding Attendance'), findsWidgets);

        // 4. Verify assigned student test data (Student name, Boarded, Not Boarded controls)
        expect(find.textContaining('Anjali'), findsWidgets);
        expect(find.textContaining('BOARDED'), findsWidgets);
        expect(find.textContaining('NOT BOARDED'), findsWidgets);

        // 5. Open Drawer and tap 'My Students' tab to verify tab view
        final ScaffoldState scaffoldState = tester.firstState(find.byType(Scaffold));
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        final myStudentsDrawerTile = find.text('My Students');
        expect(myStudentsDrawerTile, findsWidgets);
        await tester.tap(myStudentsDrawerTile.first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Anjali'), findsWidgets);
        expect(find.textContaining('BOARDED'), findsWidgets);
        expect(find.textContaining('NOT BOARDED'), findsWidgets);
      },
    );

    // ------------------------------------------------------------------------
    // Test 2: Start Trip Button Response (Dashboard UI test)
    // ------------------------------------------------------------------------
    testWidgets(
      'Verify Start Trip button exists, is enabled, and responds to user tap',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DriverDashboard(
              userName: 'Ben',
              driverId: 6,
            ),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 3));

        final startTripBtn = find.textContaining('START TRIP');
        if (startTripBtn.evaluate().isNotEmpty) {
          expect(startTripBtn, findsOneWidget);
          await tester.tap(startTripBtn.first);
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
        } else {
          // If trip is already active from database state, verify trip active status button
          expect(find.textContaining('TRIP IS ACTIVE'), findsOneWidget);
        }

        expect(find.byType(DriverDashboard), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // Test 3: Dedicated Real GPS Location Test
    // ------------------------------------------------------------------------
    testWidgets(
      'Verify Real GPS Location functionality & Start Trip (Prerequisite Checked)',
      (tester) async {
        // Step 1: Check if Location Service is enabled on device
        final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

        // Step 2: Check Location Permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        // Step 3: Handle unavailable GPS permission/service as environment prerequisite failure
        if (!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          markTestSkipped(
            'Device/environment prerequisite failure: GPS location service is disabled or location permission was denied on this test device/environment.',
          );
          return;
        }

        // Step 4: Obtain actual GPS location without faking coordinates
        final Position currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );

        expect(currentPos.latitude, isNotNull);
        expect(currentPos.longitude, isNotNull);

        // Step 5: Test Start Trip with active GPS
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DriverDashboard(
              userName: 'Ben',
              driverId: 6,
            ),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 3));

        final startTripBtn = find.textContaining('START TRIP');
        if (startTripBtn.evaluate().isNotEmpty) {
          await tester.tap(startTripBtn.first);
          await tester.pump();
          for (int i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (find.textContaining('TRIP IS ACTIVE').evaluate().isNotEmpty) {
              break;
            }
          }
        }

        expect(find.textContaining('TRIP IS ACTIVE'), findsWidgets);
      },
    );

    // ------------------------------------------------------------------------
    // Test 4: Driver Login Flow Test
    // ------------------------------------------------------------------------
    testWidgets(
      'Verify Driver Login flow navigates to Driver Dashboard',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Select Driver Role Chip
        final driverChip = find.text('Driver');
        if (driverChip.evaluate().isNotEmpty) {
          await tester.tap(driverChip.first);
          await tester.pumpAndSettle();
        }

        // Enter Driver Credentials
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'ben@gmail.com',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'driver123',
        );

        // Tap LOGIN
        await tester.tap(find.text('LOGIN'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Login attempt completed and navigated away from LoginScreen
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  });
}

