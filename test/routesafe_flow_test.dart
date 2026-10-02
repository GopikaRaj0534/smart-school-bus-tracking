import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  group('RouteSafe Full End-to-End Suite (TC01 - TC08)', () {
    test('TC01: Valid Parent Login', () async {
      final res = await ApiService.login(email: 'anju@gmail.com', password: 'anju123', role: 'parent');
      expect(res['success'], equals(true));
      expect(res['user']['user_id'], equals(15));
      expect(res['user']['email'], equals('anju@gmail.com'));
    });

    test('TC02: Invalid Parent Login', () async {
      expect(
        () async => await ApiService.login(email: 'anju@gmail.com', password: 'wrongpassword', role: 'parent'),
        throwsException,
      );
    });

    test('TC03: Valid Driver Login', () async {
      final res = await ApiService.login(email: 'benit@gmail.com', password: 'benit123', role: 'driver');
      expect(res['success'], equals(true));
      expect(res['user']['user_id'], equals(40));
    });

    test('TC04: Admin Driver Approval & Bus List Audit', () async {
      final res = await ApiService.getBuses();
      expect(res['success'], equals(true));
      expect(res['buses'], isA<List>());
      final buses = List<Map<String, dynamic>>.from(res['buses']);
      expect(buses.isNotEmpty, equals(true));
      for (var b in buses) {
        expect(b.containsKey('bus_number'), equals(true));
        expect(b.containsKey('route'), equals(true));
      }
    });

    test('TC05: Parent My Children & Student Details', () async {
      final res = await ApiService.getParentDashboard(15);
      expect(res['success'], equals(true));
      expect(res['children'], isA<List>());
      final children = List<Map<String, dynamic>>.from(res['children']);
      expect(children.isNotEmpty, equals(true));
      expect(children[0]['child_name'], equals('Anjali'));
      expect(children[0]['driver_name'], equals('Benit'));
    });

    test('TC06: Driver Security & 2FA Endpoint Verification', () async {
      final res = await ApiService.getDriver2FAStatus(40);
      expect(res['success'], equals(true));
      expect(res.containsKey('is_enabled'), equals(true));
    });

    test('TC07: Parent Route and Pickup Stop Information', () async {
      final res = await ApiService.getChildLocation(parentId: 15, childId: 4);
      expect(res['success'], equals(true));
      expect(res.containsKey('stops'), equals(true));
    });

    test('TC08: Student Boarding Status Synchronization', () async {
      final res = await ApiService.getDriverBoarding(40);
      expect(res['success'], equals(true));
      final boardingList = res['boarding'] ?? res['students'];
      expect(boardingList, isA<List>());
    });
  });
}
