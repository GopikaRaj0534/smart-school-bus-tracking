import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================
  // TIMEOUT & BASE URL
  // ============================================================

  static const Duration _timeoutDuration = Duration(seconds: 60);

  static const String defaultProductionUrl =
      'https://smart-school-bus-tracking.onrender.com';

  static String? _cachedBaseUrl;
  static String? _manualBaseUrl;

  /// Global state cache for active demo driver locations (Alappuzha simulation)
  static final Map<int, Map<String, dynamic>> activeDemoDriverLocations = {};

  /// Configure production API URL dynamically (e.g. `ApiService.overrideBaseUrl = 'https://smart-school-bus-tracking.onrender.com'`)
  static set overrideBaseUrl(String? url) {
    _manualBaseUrl = url;
  }

  static String get baseUrl {
    if (_manualBaseUrl != null && _manualBaseUrl!.trim().isNotEmpty) {
      return _manualBaseUrl!.trim();
    }

    const envBaseUrl = String.fromEnvironment(
      'ROUTESAFE_API_BASE_URL',
      defaultValue: '',
    );

    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }

    return defaultProductionUrl;
  }

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  static Future<Map<String, dynamic>> healthCheck() async {
    return _get('/');
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

  static Future<Map<String, dynamic>> getAvailableBuses() async {
    return _get('/buses/available');
  }

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

  static Future<Map<String, dynamic>> updateBus({
    required int busId,
    required String busNumber,
    required String route,
    String? driverName,
    String status = 'Active',
  }) async {
    return _put(
      '/buses/$busId',
      {
        'bus_number': busNumber.trim(),
        'route': route.trim(),
        'driver_name': driverName?.trim(),
        'status': status.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> deleteBus(
    int busId,
  ) async {
    return _delete('/buses/$busId');
  }

  // ============================================================
  // ROUTES
  // ============================================================

  static Future<Map<String, dynamic>> getRoutes() async {
    return _get('/routes');
  }

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

  static Future<Map<String, dynamic>> deleteRoute(
    int routeId,
  ) async {
    return _delete('/admin/routes/$routeId');
  }

  // ============================================================
  // STOPS
  // ============================================================

  static Future<Map<String, dynamic>> getStops({
    int? routeId,
  }) async {
    final path = routeId == null ? '/admin/stops' : '/admin/stops?route_id=$routeId';
    return _get(path);
  }

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

  static Future<Map<String, dynamic>> deleteStop(
    int stopId,
  ) async {
    return _delete('/admin/stops/$stopId');
  }

  // ============================================================
  // DRIVERS
  // ============================================================

  static Future<Map<String, dynamic>> getDriversCount() async {
    return _get('/drivers/count');
  }

  static Future<Map<String, dynamic>> getDrivers() async {
    return _get('/drivers');
  }

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

  static Future<Map<String, dynamic>> updateDriver({
    required int driverId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
  }) async {
    return _put(
      '/drivers/$driverId',
      {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteDriver(
    int driverId,
  ) async {
    return _delete('/drivers/$driverId');
  }

  // ============================================================
  // PARENTS
  // ============================================================

  static Future<Map<String, dynamic>> getParentsCount() async {
    return _get('/parents/count');
  }

  static Future<Map<String, dynamic>> getParents() async {
    return _get('/parents');
  }

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

  static Future<Map<String, dynamic>> updateParent({
    required int parentId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
  }) async {
    return _put(
      '/parents/$parentId',
      {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteParent(
    int parentId,
  ) async {
    return _delete('/parents/$parentId');
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
    return _put('/admin/parents/$parentId/approve');
  }

  static Future<Map<String, dynamic>> rejectParent(int parentId) async {
    return _put('/admin/parents/$parentId/reject');
  }

  // ============================================================
  // CHILDREN & TRANSPORT ASSIGNMENT
  // ============================================================

  static Future<Map<String, dynamic>> getChildren() async {
    return _get('/admin/children');
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

  static Future<Map<String, dynamic>> getStopsForRoute(int routeId) async {
    return _get('/routes/$routeId/stops');
  }

  static Future<Map<String, dynamic>> updateChildPickupStop({
    required int parentId,
    required int childId,
    required int stopId,
    int? routeId,
  }) async {
    return _post(
      '/parent/$parentId/child/$childId/stop',
      {
        'parent_id': parentId,
        'child_id': childId,
        'stop_id': stopId,
        'route_id': routeId,
      }..removeWhere((key, value) => value == null),
    );
  }

  static Future<Map<String, dynamic>> assignDriverToBus({
    required int busId,
    int? driverId,
    String? driverName,
  }) async {
    return _put(
      '/admin/buses/$busId/assign-driver',
      {
        'driver_id': driverId,
        'driver_name': driverName,
      }..removeWhere((key, value) => value == null),
    );
  }

  static Future<Map<String, dynamic>> assignChildTransport({
    required int childId,
    required int busId,
    int? routeId,
    int? pickupStopId,
  }) async {
    return _put(
      '/admin/children/$childId/assign',
      {
        'bus_id': busId,
        'route_id': routeId,
        'pickup_stop_id': pickupStopId,
      }..removeWhere((key, value) => value == null),
    );
  }

  // ============================================================
  // DASHBOARDS & TRIPS
  // ============================================================

  static Future<Map<String, dynamic>> getParentDashboard(
    int parentId,
  ) async {
    return _get('/parent/$parentId/dashboard');
  }

  static Future<Map<String, dynamic>> getDriverDashboard(
    int driverId,
  ) async {
    return _get('/driver/$driverId/dashboard');
  }

  static Future<Map<String, dynamic>> getDriverBus(
    int driverId,
  ) async {
    return _get('/driver/$driverId/bus');
  }

  static Future<Map<String, dynamic>> startTrip(
    int driverId,
  ) async {
    return _post(
      '/driver/$driverId/trip/start',
      {},
    );
  }

  static Future<Map<String, dynamic>> endTrip(
    int driverId,
  ) async {
    return _post(
      '/driver/$driverId/trip/end',
      {},
    );
  }

  static Future<Map<String, dynamic>> updateDriverLocation({
    required int driverId,
    required double latitude,
    required double longitude,
    bool isDemo = false,
  }) async {
    if (isDemo) {
      activeDemoDriverLocations[driverId] = {
        'latitude': latitude,
        'longitude': longitude,
        'is_demo': true,
        'updated_at': DateTime.now().toIso8601String(),
      };
    } else {
      activeDemoDriverLocations.remove(driverId);
    }
    return _post(
      '/driver/$driverId/location',
      {
        'latitude': latitude,
        'longitude': longitude,
        'is_demo': isDemo,
      },
    );
  }

  static Future<Map<String, dynamic>> getDriverLocation(
    int driverId,
  ) async {
    if (activeDemoDriverLocations.containsKey(driverId)) {
      final demoData = activeDemoDriverLocations[driverId]!;
      return {
        'success': true,
        'location': demoData,
        'is_demo': true,
        'is_trip_active': true,
      };
    }
    return _get('/driver/$driverId/location');
  }

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

  static Future<Map<String, dynamic>> getChildLocation({
    required int parentId,
    required int childId,
  }) async {
    final res = await _get('/parent/$parentId/child/$childId/location');
    if (res['success'] == true && activeDemoDriverLocations.isNotEmpty) {
      if (res['is_demo'] == true) return res;
      final demoLoc = activeDemoDriverLocations.values.first;
      return {
        ...res,
        'is_trip_active': true,
        'is_demo': true,
        'location': demoLoc,
      };
    }
    return res;
  }

  static Future<Map<String, dynamic>> getAdminEmergencies() async {
    return _get('/admin/emergencies');
  }

  // ============================================================
  // PENDING DRIVER REQUESTS
  // ============================================================

  static Future<Map<String, dynamic>> getPendingDriverRequests() async {
    return _get('/admin/driver-requests');
  }

  static Future<Map<String, dynamic>> getPendingDriverCount() async {
    return _get('/admin/driver-requests/count');
  }

  static Future<Map<String, dynamic>> approveDriver({
    required int driverId,
    int? busId,
  }) async {
    return _put(
      '/admin/drivers/$driverId/approve',
      {
        'bus_id': busId,
      }..removeWhere((key, value) => value == null),
    );
  }

  static Future<Map<String, dynamic>> rejectDriver(int driverId, [String? reason]) async {
    return _put(
      '/admin/drivers/$driverId/reject',
      {
        if (reason != null && reason.trim().isNotEmpty) 'rejection_reason': reason.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> getAdminDashboardMetrics() async {
    return _get('/admin/dashboard/metrics');
  }

  static Future<Map<String, dynamic>> getAdminAnalytics() async {
    return _get('/admin/analytics');
  }

  static Future<Map<String, dynamic>> addAdminRoute(String routeName) async {
    return _post('/admin/routes', {'route_name': routeName.trim()});
  }

  static Future<Map<String, dynamic>> updateAdminRoute(int routeId, String routeName) async {
    return _put('/admin/routes/$routeId', {'route_name': routeName.trim()});
  }

  static Future<Map<String, dynamic>> deleteAdminRoute(int routeId) async {
    return _delete('/admin/routes/$routeId');
  }

  static Future<Map<String, dynamic>> addAdminStop({
    required int routeId,
    required String stopName,
    int? stopOrder,
    double? latitude,
    double? longitude,
  }) async {
    return _post(
      '/admin/routes/$routeId/stops',
      {
        'stop_name': stopName.trim(),
        'stop_order': stopOrder ?? 1,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
  }

  static Future<Map<String, dynamic>> updateAdminStop({
    required int stopId,
    String? stopName,
    int? stopOrder,
    double? latitude,
    double? longitude,
  }) async {
    return _put(
      '/admin/stops/$stopId',
      {
        'stop_name': ?stopName?.trim(),
        'stop_order': ?stopOrder,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteAdminStop(int stopId) async {
    return _delete('/admin/stops/$stopId');
  }

  static Future<Map<String, dynamic>> getAdminStops() async {
    return _get('/admin/stops');
  }

  static Future<Map<String, dynamic>> getAdminChildren() async {
    return _get('/admin/children');
  }

  static Future<Map<String, dynamic>> assignChild({
    int? parentId,
    required String childName,
    String? className,
    int? busId,
    int? pickupStopId,
  }) async {
    return _post(
      '/admin/children',
      {
        'parent_id': ?parentId,
        'child_name': childName.trim(),
        if (className != null && className.trim().isNotEmpty)
          'class_name': className.trim(),
        'bus_id': ?busId,
        'pickup_stop_id': ?pickupStopId,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteChild(int childId) async {
    return _delete('/admin/children/$childId');
  }

  static Future<Map<String, dynamic>> getAdminHistory([String type = 'trips']) async {
    return _get('/admin/history?type=$type');
  }

  // ============================================================
  // DRIVER MODULE METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getDriverStatus(int driverId) async {
    return _get('/driver/$driverId/status');
  }

  static Future<Map<String, dynamic>> getDriverBusDetails(int driverId) async {
    return _get('/driver/$driverId/bus');
  }

  static Future<Map<String, dynamic>> getDriverStudents(int driverId) async {
    return _get('/driver/$driverId/students');
  }

  static Future<Map<String, dynamic>> getDriverBoarding(int driverId) async {
    return _get('/driver/$driverId/boarding');
  }

  static Future<Map<String, dynamic>> updateStudentBoarding({
    required int driverId,
    required int childId,
    required String boardingStatus,
    int? stopId,
  }) async {
    return _post(
      '/driver/$driverId/boarding/update',
      {
        'child_id': childId,
        'boarding_status': boardingStatus,
        'stop_id': ?stopId,
      },
    );
  }

  static Future<Map<String, dynamic>> getDriverTrips(int driverId) async {
    return _get('/driver/$driverId/trips');
  }

  static Future<Map<String, dynamic>> getDriverEmergencies(int driverId) async {
    return _get('/driver/$driverId/emergencies');
  }

  static Future<Map<String, dynamic>> reportDriverEmergency({
    required int driverId,
    required String emergencyType,
    required String message,
    double? latitude,
    double? longitude,
    int? busId,
  }) async {
    return _post(
      '/driver/$driverId/emergency',
      {
        'emergency_type': emergencyType,
        'message': message,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'bus_id': ?busId,
      },
    );
  }

  static Future<Map<String, dynamic>> startDriverTrip(int driverId) async {
    return _post('/driver/$driverId/trip/start', {});
  }

  static Future<Map<String, dynamic>> endDriverTrip(int driverId) async {
    return _post('/driver/$driverId/trip/end', {});
  }

  // ============================================================
  // SCHOOL SETTINGS
  // ============================================================

  static Future<Map<String, dynamic>> getSchoolSettings() async {
    return _get('/school-settings');
  }

  static Future<Map<String, dynamic>> updateSchoolSettings({
    required String schoolName,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    return _put(
      '/school-settings',
      {
        'school_name': schoolName.trim(),
        'address': address.trim(),
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  static Future<Map<String, dynamic>> getParentNotifications(int parentId) async {
    return _get('/parent/$parentId/notifications');
  }

  // ============================================================
  // HTTP HELPERS WITH TIMEOUT & DYNAMIC FALLBACK
  // ============================================================

  static Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String currentBaseUrl) makeRequest,
  ) async {
    final primaryBase = baseUrl;
    try {
      final response = await makeRequest(primaryBase).timeout(_timeoutDuration);
      _cachedBaseUrl = primaryBase;
      return response;
    } catch (e) {
      const envBaseUrl = String.fromEnvironment('ROUTESAFE_API_BASE_URL', defaultValue: '');
      if (envBaseUrl.isEmpty && _isConnectionError(e)) {
        final List<String> fallbackBases = [];
        if (primaryBase != defaultProductionUrl && defaultProductionUrl.isNotEmpty) {
          fallbackBases.add(defaultProductionUrl);
        }
        if (primaryBase != 'http://10.0.2.2:5000') fallbackBases.add('http://10.0.2.2:5000');
        if (primaryBase != 'http://127.0.0.1:5000') fallbackBases.add('http://127.0.0.1:5000');

        for (final fallbackBase in fallbackBases) {
          try {
            final response = await makeRequest(fallbackBase).timeout(_timeoutDuration);
            _cachedBaseUrl = fallbackBase;
            debugPrint('RouteSafe ApiService auto-detected backend URL: $fallbackBase');
            return response;
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  static bool _isConnectionError(Object e) {
    if (e is SocketException || e is http.ClientException || e is TimeoutException) {
      return true;
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('clientexception') ||
        msg.contains('failed to connect') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection timed out');
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _sendWithFallback((base) {
        final url = Uri.parse('$base$path');
        debugPrint('========================================');
        debugPrint('GET REQUEST: $url');
        debugPrint('========================================');
        return http.get(
          url,
          headers: {
            'Accept': 'application/json',
          },
        );
      });

      debugPrint('GET STATUS: ${response.statusCode}');
      debugPrint('GET RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on TimeoutException {
      throw Exception(
        'Connection timed out reaching RouteSafe server ($baseUrl). '
        'Please check if the backend server is running and accessible.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server ($baseUrl). '
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network connection error ($baseUrl): ${e.message}',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON response format.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _sendWithFallback((base) {
        final url = Uri.parse('$base$path');
        debugPrint('========================================');
        debugPrint('POST REQUEST: $url');
        debugPrint('BODY: ${jsonEncode(body)}');
        debugPrint('========================================');
        return http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        );
      });

      debugPrint('POST STATUS: ${response.statusCode}');
      debugPrint('POST RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on TimeoutException {
      throw Exception(
        'Connection timed out reaching RouteSafe server ($baseUrl). '
        'Please check if the backend server is running and accessible.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server ($baseUrl). '
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network connection error ($baseUrl): ${e.message}',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON response format.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<Map<String, dynamic>> _put(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final response = await _sendWithFallback((base) {
        final url = Uri.parse('$base$path');
        debugPrint('========================================');
        debugPrint('PUT REQUEST: $url');
        if (body != null) {
          debugPrint('BODY: ${jsonEncode(body)}');
        }
        debugPrint('========================================');
        return http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        );
      });

      debugPrint('PUT STATUS: ${response.statusCode}');
      debugPrint('PUT RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on TimeoutException {
      throw Exception(
        'Connection timed out reaching RouteSafe server ($baseUrl). '
        'Please check if the backend server is running and accessible.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server ($baseUrl). '
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network connection error ($baseUrl): ${e.message}',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON response format.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await _sendWithFallback((base) {
        final url = Uri.parse('$base$path');
        debugPrint('========================================');
        debugPrint('DELETE REQUEST: $url');
        debugPrint('========================================');
        return http.delete(
          url,
          headers: {
            'Accept': 'application/json',
          },
        );
      });

      debugPrint('DELETE STATUS: ${response.statusCode}');
      debugPrint('DELETE RESPONSE: ${response.body}');

      return _decodeBody(response);
    } on TimeoutException {
      throw Exception(
        'Connection timed out reaching RouteSafe server ($baseUrl). '
        'Please check if the backend server is running and accessible.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to RouteSafe server ($baseUrl). '
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network connection error ($baseUrl): ${e.message}',
      );
    } on FormatException {
      throw Exception(
        'Server returned invalid JSON response format.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // DRIVER 2FA SECURITY API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getDriver2FAStatus(int driverId) async {
    return _get('/api/driver/2fa/status?driver_id=$driverId');
  }

  static Future<Map<String, dynamic>> verifyDriver2FALogin({
    required String tempToken,
    required String otp,
  }) async {
    return _post('/api/driver/2fa/verify-login', {
      'temp_token': tempToken.trim(),
      'otp': otp.trim(),
    });
  }

  static Future<Map<String, dynamic>> resendDriver2FAOTP({
    required String tempToken,
    String purpose = 'LOGIN',
  }) async {
    return _post('/api/driver/2fa/resend-otp', {
      'temp_token': tempToken.trim(),
      'purpose': purpose,
    });
  }

  static Future<Map<String, dynamic>> requestEnable2FA(int driverId) async {
    return _post('/api/driver/2fa/request-enable', {
      'driver_id': driverId,
    });
  }

  static Future<Map<String, dynamic>> verifyEnable2FA({
    required int driverId,
    required String tempToken,
    required String otp,
  }) async {
    return _post('/api/driver/2fa/verify-enable', {
      'driver_id': driverId,
      'temp_token': tempToken.trim(),
      'otp': otp.trim(),
    });
  }

  static Future<Map<String, dynamic>> requestDisable2FA({
    required int driverId,
    required String password,
  }) async {
    return _post('/api/driver/2fa/request-disable', {
      'driver_id': driverId,
      'password': password.trim(),
    });
  }

  static Future<Map<String, dynamic>> verifyDisable2FA({
    required int driverId,
    required String otp,
  }) async {
    return _post('/api/driver/2fa/verify-disable', {
      'driver_id': driverId,
      'otp': otp.trim(),
    });
  }

  static Future<Map<String, dynamic>> requestDriver2FARecovery({
    required String email,
    String? phone,
  }) async {
    return _post('/api/driver/2fa/request-recovery', {
      'email': email.trim().toLowerCase(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
  }

  static Future<Map<String, dynamic>> verifyDriver2FARecovery({
    required String tempToken,
    required String otp,
  }) async {
    return _post('/api/driver/2fa/verify-recovery', {
      'temp_token': tempToken.trim(),
      'otp': otp.trim(),
    });
  }

  static Future<Map<String, dynamic>> adminResetDriver2FA(int driverId) async {
    return _post('/api/admin/driver/reset-2fa', {
      'driver_id': driverId,
    });
  }

  // ============================================================
  // PARENT ABSENCE & DYNAMIC ITINERARY
  // ============================================================

  static Future<Map<String, dynamic>> markChildAbsent({
    required int parentId,
    required int childId,
    String? absenceDate,
  }) async {
    return _post(
      '/parent/$parentId/child/$childId/absence',
      {
        if (absenceDate != null && absenceDate.isNotEmpty)
          'absence_date': absenceDate,
      },
    );
  }

  static Future<Map<String, dynamic>> cancelChildAbsence({
    required int parentId,
    required int childId,
    String? absenceDate,
  }) async {
    return _post(
      '/parent/$parentId/child/$childId/absence/cancel',
      {
        if (absenceDate != null && absenceDate.isNotEmpty)
          'absence_date': absenceDate,
      },
    );
  }

  static Future<Map<String, dynamic>> getChildAbsenceStatus({
    required int parentId,
    required int childId,
  }) async {
    return _get('/parent/$parentId/child/$childId/absence');
  }

  static Future<Map<String, dynamic>> getDriverItinerary(int driverId) async {
    return _get('/driver/$driverId/itinerary');
  }

  // ============================================================
  // RESPONSE DECODER
  // ============================================================

  static Map<String, dynamic> _decodeBody(
    http.Response response,
  ) {
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      final bodyText = response.body.trim();
      final preview = bodyText.length > 120 ? '${bodyText.substring(0, 120)}...' : bodyText;
      throw Exception(
        'Server error (${response.statusCode}): ${preview.isNotEmpty ? preview : "Invalid response format"}',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid server response format',
      );
    }

    if (response.statusCode == 403 && data['status'] != null) {
      return data;
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