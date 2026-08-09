import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment(
      'ROUTESAFE_API_BASE_URL',
      defaultValue: '',
    );

    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    // Android Emulator -> computer localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }

    // Chrome / Windows
    return 'http://127.0.0.1:5000';
  }

  // =========================
  // REGISTER
  // =========================

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    return await _post(
      '/register',
      {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      },
    );
  }

  // =========================
  // LOGIN
  // =========================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    return await _post(
      '/login',
      {
        'email': email,
        'password': password,
        'role': role,
      },
    );
  }

  // =========================
  // GET BUSES
  // =========================

  static Future<Map<String, dynamic>> getBuses() async {
    final response = await http
        .get(Uri.parse('$baseUrl/buses'))
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // DRIVER COUNT
  // =========================

  static Future<Map<String, dynamic>> getDriversCount() async {
    final response = await http
        .get(Uri.parse('$baseUrl/drivers/count'))
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // PARENT COUNT
  // =========================

  static Future<Map<String, dynamic>> getParentsCount() async {
    final response = await http
        .get(Uri.parse('$baseUrl/parents/count'))
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // ADD BUS
  // =========================

  static Future<Map<String, dynamic>> addBus({
    required String busNumber,
    required String route,
    String? driverName,
    String status = 'Active',
  }) async {
    return await _post(
      '/buses',
      {
        'bus_number': busNumber,
        'route': route,
        'driver_name': driverName,
        'status': status,
      },
    );
  }

  // =========================
  // UPDATE BUS
  // =========================

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
          },
          body: jsonEncode({
            'bus_number': busNumber,
            'route': route,
            'driver_name': driverName,
            'status': status,
          }),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // DELETE BUS
  // =========================

  static Future<Map<String, dynamic>> deleteBus(int busId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/buses/$busId'),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // POST HELPER
  // =========================

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeBody(response);
  }

  // =========================
  // RESPONSE HANDLER
  // =========================

  static Map<String, dynamic> _decodeBody(http.Response response) {
    Map<String, dynamic> decoded;

    try {
      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid server response');
      }

      decoded = data;
    } catch (_) {
      throw Exception(
        'Server returned an invalid response (${response.statusCode})',
      );
    }

    if (response.statusCode >= 400) {
      throw Exception(
        decoded['message']?.toString() ?? 'Request failed',
      );
    }

    return decoded;
  }
}