import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  group('Admin Available Buses & Driver Assignment Test Suite', () {
    test('TC1: Verify /buses/available returns only unassigned buses', () async {
      final res = await ApiService.getAvailableBuses();
      expect(res['success'], equals(true));
      expect(res['buses'], isA<List>());
      final buses = List<Map<String, dynamic>>.from(res['buses']);
      for (var b in buses) {
        final isAvailable = b['is_available'] == 1 || b['is_available'] == true;
        expect(isAvailable, equals(true));
      }
    });

    test('TC2: Assigning a bus to an approved driver updates assignment successfully', () async {
      final res = await ApiService.approveDriver(driverId: 40, busId: 6);
      expect(res['success'], equals(true));
      expect(res['bus_id'], equals(6));
    });
  });
}
