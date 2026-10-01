import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  group('Add Bus Lifecycle & Assertion Test Suite', () {
    test('TC1: Successfully add a new bus and handle duplicate bus creation gracefully', () async {
      final busNumber = 'TEST-BUS-${DateTime.now().millisecondsSinceEpoch % 10000}';
      const route = 'Chengannur';

      // 1. Add Bus
      final res = await ApiService.addBus(
        busNumber: busNumber,
        route: route,
        driverName: 'Not Assigned',
        status: 'Active',
      );
      expect(res['success'], equals(true));
      expect(res.containsKey('bus_id'), equals(true));
      final int busId = res['bus_id'] as int;

      // 2. Duplicate Add Bus -> Expect 409 Conflict error without crash
      try {
        final dupRes = await ApiService.addBus(
          busNumber: busNumber,
          route: route,
          driverName: 'Not Assigned',
          status: 'Active',
        );
        expect(dupRes['success'], equals(false));
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('already exists'));
      }

      // 3. Clean up created bus
      final delRes = await ApiService.deleteBus(busId);
      expect(delRes['success'], equals(true));
    });
  });
}
