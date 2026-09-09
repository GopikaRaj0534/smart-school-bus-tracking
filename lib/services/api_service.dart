import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================

  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment(
      'ROUTESAFE_API_BASE_URL',
      defaultValue: '',
    );

    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    // Android Emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }

    // Windows / other platforms
    return 'http://127.0.0.1:5000';
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
    String? childName,
    String? className,
  }) async {
    return _post(
      '/register',
      {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
        'role': role.trim(),
        if (childName != null && childName.trim().isNotEmpty)
          'child_name': childName.trim(),
        if (className != null && className.trim().isNotEmpty)
          'class_name': className.trim(),
      },
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    debugPrint('================================');
    debugPrint('ROUTESAFE LOGIN');
    debugPrint('URL: $baseUrl/login');
    debugPrint('Email: ${email.trim().toLowerCase()}');
    debugPrint('Role: ${role.trim()}');
    debugPrint('================================');

    return _post(
      '/login',
      {
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role.trim(),
      },
    );
  }

  // ============================================================
  // BUSES
  // ============================================================

  static Future<Map<String, dynamic>> getBuses() async {
    return _get('/buses');
  }

  // ============================================================
  // ADD BUS
  // ============================================================

  static Future<Map<String, dynamic>> addBus({
    required String busNumber,
    required String route,
    String? driverName,
    String status = 'Active',
  }) async {
    return _post(
      '/buses',
      {
        'bus_number': busNumber.trim(),
        'route': route.trim(),
        'driver_name': driverName?.trim(),
        'status': status.trim(),
      },
    );
  }

  // ============================================================
  // UPDATE BUS
  // ============================================================

  static Future<Map<String, dynamic>> updateBus({
    required int busId,
    required String busNumber,
    required String route,
    String? driverName,
    String status = 'Active',
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/buses/$busId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'bus_number': busNumber.trim(),
            'route': route.trim(),
            'driver_name': driverName?.trim(),
            'status': status.trim(),
          }),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DELETE BUS
  // ============================================================

  static Future<Map<String, dynamic>> deleteBus(
    int busId,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/buses/$busId'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // ROUTES
  // ============================================================

  static Future<Map<String, dynamic>> getRoutes() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/routes'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // ADD ROUTE
  // ============================================================

  static Future<Map<String, dynamic>> addRoute({
    required String routeName,
  }) async {
    return _post(
      '/admin/routes',
      {
        'route_name': routeName.trim(),
      },
    );
  }

  // ============================================================
  // DELETE ROUTE
  // ============================================================

  static Future<Map<String, dynamic>> deleteRoute(
    int routeId,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/admin/routes/$routeId'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // GET STOPS
  // ============================================================

  static Future<Map<String, dynamic>> getStops({
    int? routeId,
  }) async {
    final uri = routeId == null
        ? Uri.parse('$baseUrl/admin/stops')
        : Uri.parse(
            '$baseUrl/admin/stops?route_id=$routeId',
          );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // ADD STOP
  // ============================================================

  static Future<Map<String, dynamic>> addStop({
    required int routeId,
    required String stopName,
    required int stopOrder,
    required double latitude,
    required double longitude,
  }) async {
    return _post(
      '/admin/stops',
      {
        'route_id': routeId,
        'stop_name': stopName.trim(),
        'stop_order': stopOrder,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  // ============================================================
  // DELETE STOP
  // ============================================================

  static Future<Map<String, dynamic>> deleteStop(
    int stopId,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/admin/stops/$stopId'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DRIVER COUNT
  // ============================================================

  static Future<Map<String, dynamic>> getDriversCount() async {
    return _get('/drivers/count');
  }

  // ============================================================
  // GET DRIVERS
  // ============================================================

  static Future<Map<String, dynamic>> getDrivers() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/drivers'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // ADD DRIVER
  // ============================================================

  static Future<Map<String, dynamic>> addDriver({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    return _post(
      '/drivers',
      {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
      },
    );
  }

  // ============================================================
  // DRIVER 2FA PHONE CHANGE
  // ============================================================

  static Future<Map<String, dynamic>> requestDriverPhoneChange({
    required int driverId,
    required String newPhone,
  }) async {
    return _post(
      '/driver/$driverId/phone-change/request',
      {
        'new_phone': newPhone.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> verifyDriverPhoneChange({
    required int driverId,
    required String otp,
  }) async {
    return _post(
      '/driver/$driverId/phone-change/verify',
      {
        'otp': otp.trim(),
      },
    );
  }

  // ============================================================
  // UPDATE DRIVER
  // ============================================================

  static Future<Map<String, dynamic>> updateDriver({
    required int driverId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/drivers/$driverId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'full_name': fullName.trim(),
            'email': email.trim().toLowerCase(),
            'phone': phone.trim(),
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DELETE DRIVER
  // ============================================================

  static Future<Map<String, dynamic>> deleteDriver(
    int driverId,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/drivers/$driverId'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // PARENT COUNT
  // ============================================================

  static Future<Map<String, dynamic>> getParentsCount() async {
    return _get('/parents/count');
  }

  // ============================================================
  // GET PARENTS
  // ============================================================

  static Future<Map<String, dynamic>> getParents() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/parents'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // ADD PARENT
  // ============================================================

  static Future<Map<String, dynamic>> addParent({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    return _post(
      '/parents',
      {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
      },
    );
  }

  // ============================================================
  // UPDATE PARENT
  // ============================================================

  static Future<Map<String, dynamic>> updateParent({
    required int parentId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/parents/$parentId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'full_name': fullName.trim(),
            'email': email.trim().toLowerCase(),
            'phone': phone.trim(),
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DELETE PARENT
  // ============================================================

  static Future<Map<String, dynamic>> deleteParent(
    int parentId,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/parents/$parentId'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // PENDING PARENT REQUESTS
  // ============================================================

  static Future<Map<String, dynamic>> getPendingParentRequests() async {
    return _get('/admin/parent-requests');
  }

  static Future<Map<String, dynamic>> getPendingParentCount() async {
    return _get('/admin/parent-requests/count');
  }

  static Future<Map<String, dynamic>> approveParent(int parentId) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/admin/parents/$parentId/approve'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  static Future<Map<String, dynamic>> rejectParent(int parentId) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/admin/parents/$parentId/reject'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // CHILDREN & TRANSPORT ASSIGNMENT
  // ============================================================

  static Future<Map<String, dynamic>> getChildren() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/admin/children'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  static Future<Map<String, dynamic>> linkChild({
    required int parentId,
    required String childName,
    String? className,
  }) async {
    return _post(
      '/admin/children/link',
      {
        'parent_id': parentId,
        'child_name': childName.trim(),
        if (className != null && className.trim().isNotEmpty)
          'class_name': className.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> submitChildDetails({
    required int parentId,
    required String childName,
    String? className,
    int? pickupStopId,
  }) async {
    return _post(
      '/parent/$parentId/child',
      {
        'parent_id': parentId,
        'child_name': childName.trim(),
        'class_name': className?.trim(),
        'pickup_stop_id': pickupStopId,
      }..removeWhere((key, value) => value == null || (value is String && value.isEmpty)),
    );
  }

  static Future<Map<String, dynamic>> assignDriverToBus({
    required int busId,
    int? driverId,
    String? driverName,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/admin/buses/$busId/assign-driver'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'driver_id': driverId,
            'driver_name': driverName,
          }..removeWhere((key, value) => value == null)),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  static Future<Map<String, dynamic>> assignChildTransport({
    required int childId,
    required int busId,
    int? routeId,
    int? pickupStopId,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/admin/children/$childId/assign'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'bus_id': busId,
            'route_id': routeId,
            'pickup_stop_id': pickupStopId,
          }..removeWhere((key, value) => value == null)),
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // PARENT DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> getParentDashboard(
    int parentId,
  ) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/parent/$parentId/dashboard'),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DRIVER DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> getDriverDashboard(
    int driverId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/driver/$driverId/dashboard',
          ),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // DRIVER BUS
  // ============================================================

  static Future<Map<String, dynamic>> getDriverBus(
    int driverId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/driver/$driverId/bus',
          ),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // START TRIP
  // ============================================================

  static Future<Map<String, dynamic>> startTrip(
    int driverId,
  ) async {
    return _post(
      '/driver/$driverId/trip/start',
      {},
    );
  }

  // ============================================================
  // END TRIP
  // ============================================================

  static Future<Map<String, dynamic>> endTrip(
    int driverId,
  ) async {
    return _post(
      '/driver/$driverId/trip/end',
      {},
    );
  }

  // ============================================================
  // UPDATE DRIVER LOCATION
  // ============================================================

  static Future<Map<String, dynamic>> updateDriverLocation({
    required int driverId,
    required double latitude,
    required double longitude,
  }) async {
    return _post(
      '/driver/$driverId/location',
      {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  // ============================================================
  // GET LATEST DRIVER LOCATION
  // ============================================================

  static Future<Map<String, dynamic>> getDriverLocation(
    int driverId,
  ) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/driver/$driverId/location',
          ),
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 8),
        );

    return _decodeBody(response);
  }

  // ============================================================
  // REPORT EMERGENCY
  // ============================================================

  static Future<Map<String, dynamic>> reportEmergency({
    required int driverId,
    required String message,
  }) async {
    return _post(
      '/driver/$driverId/emergency',
      {
        'message': message.trim(),
      },
    );
  }

  // ============================================================
  // GET HELPER
  // ============================================================

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');

      debugPrint('========================================');
      debugPrint('GET REQUEST');
      debugPrint('URL: $url');
      debugPrint('========================================');

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 8),
          );

      debugPrint('GET STATUS: ${response.statusCode}');
      debugPrint('GET RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server. '
        'Make sure Flask is running on port 5000. '
        'Error: $e',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error: $e',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON',
      );
    }
  }

  // ============================================================
  // POST HELPER
  // ============================================================

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('$baseUrl$path');

      debugPrint('========================================');
      debugPrint('POST REQUEST');
      debugPrint('URL: $url');
      debugPrint('BODY: ${jsonEncode(body)}');
      debugPrint('========================================');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 8),
          );

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server. '
        'Make sure Flask is running on port 5000. '
        'Error: $e',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error: $e',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON',
      );
    }
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  static Map<String, dynamic> _decodeBody(
    http.Response response,
  ) {
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Server returned invalid response '
        '(${response.statusCode})',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid server response format',
      );
    }

    if (response.statusCode >= 400) {
      throw Exception(
        data['message']?.toString() ??
            'Request failed (${response.statusCode})',
      );
    }

    return data;
  }
}