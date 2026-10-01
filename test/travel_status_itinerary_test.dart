import 'package:flutter_test/flutter_test.dart';
import 'package:routesafe/services/api_service.dart';

void main() {
  group('Travel Status & Dynamic Itinerary Suite (TC01 - TC06)', () {
    const parentId = 15; // Parent Anju
    const childId = 4;   // Child Anjali
    const driverId = 40; // Driver Benit (Assigned to Bus 1 / Route 1)
    const otherDriverId = 8; // Driver Anil (Assigned to Bus 12 / Route Pala)

    test('TC01: Parent opens Travel Status & loads initial status', () async {
      final res = await ApiService.getChildAbsenceStatus(
        parentId: parentId,
        childId: childId,
      );
      expect(res['success'], equals(true));
      expect(res.containsKey('is_absent'), equals(true));
    });

    test('TC02: Parent marks existing child as Not Riding Today', () async {
      final markRes = await ApiService.markChildAbsent(
        parentId: parentId,
        childId: childId,
      );
      expect(markRes['success'], equals(true));
      expect(markRes['is_absent'], equals(true));

      // Verify DB persistence
      final checkRes = await ApiService.getChildAbsenceStatus(
        parentId: parentId,
        childId: childId,
      );
      expect(checkRes['is_absent'], equals(true));
    });

    test('TC03: Driver opens Students Not Riding & sees absent child', () async {
      final boardingRes = await ApiService.getDriverBoarding(driverId);
      expect(boardingRes['success'], equals(true));
      
      final students = List<Map<String, dynamic>>.from(
        boardingRes['boarding'] ?? boardingRes['students'] ?? [],
      );
      expect(students.isNotEmpty, equals(true));

      final absentChild = students.firstWhere(
        (s) => s['child_id'] == childId,
        orElse: () => <String, dynamic>{},
      );
      expect(absentChild.isNotEmpty, equals(true));
      expect(absentChild['child_name'], equals('Anjali'));
      expect(absentChild['is_absent'] == 1 || absentChild['is_absent'] == true || absentChild['boarding_status'] == 'SKIP', equals(true));
    });

    test('TC04: Driver itinerary calculates skipped stop', () async {
      final itinRes = await ApiService.getDriverItinerary(driverId);
      expect(itinRes['success'], equals(true));
      expect(itinRes['stops'], isA<List>());

      final stops = List<Map<String, dynamic>>.from(itinRes['stops']);
      expect(stops.isNotEmpty, equals(true));

      // Stop 1 (Chengannur Town) has child Anjali who is Not Riding Today
      final chengannurStop = stops.firstWhere(
        (st) => st['stop_id'] == 1,
        orElse: () => <String, dynamic>{},
      );
      expect(chengannurStop.isNotEmpty, equals(true));
      expect(chengannurStop['is_skipped'] == true || chengannurStop['status'] == 'SKIPPED', equals(true));
    });

    test('TC05: Parent reverts status to Riding Today & verifies sync', () async {
      final cancelRes = await ApiService.cancelChildAbsence(
        parentId: parentId,
        childId: childId,
      );
      expect(cancelRes['success'], equals(true));
      expect(cancelRes['is_absent'], equals(false));

      // Verify DB persistence
      final checkRes = await ApiService.getChildAbsenceStatus(
        parentId: parentId,
        childId: childId,
      );
      expect(checkRes['is_absent'], equals(false));
    });

    test('TC06: Another driver does NOT see students from other routes', () async {
      final otherDriverRes = await ApiService.getDriverBoarding(otherDriverId);
      expect(otherDriverRes['success'], equals(true));

      final otherStudents = List<Map<String, dynamic>>.from(
        otherDriverRes['boarding'] ?? otherDriverRes['students'] ?? [],
      );

      // Verify Child Anjali (childId 4) is NOT in other driver's student list
      final hasAnjali = otherStudents.any((s) => s['child_id'] == childId);
      expect(hasAnjali, equals(false));
    });
  });
}
