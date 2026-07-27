import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment('ROUTESAFE_API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:5000";
    }
    return "http://127.0.0.1:5000";
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      return await _post(
        "/register",
        {
          "full_name": fullName,
          "email": email,
          "phone": phone,
          "password": password,
          "role": role,
        },
      );
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      return await _post(
        "/login",
        {
          "email": email,
          "password": password,
          "role": role,
        },
      );
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> getBuses() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/buses")).timeout(
        const Duration(seconds: 8),
      );
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> getDriversCount() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/drivers/count")).timeout(
        const Duration(seconds: 8),
      );
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> getParentsCount() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/parents/count")).timeout(
        const Duration(seconds: 8),
      );
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> addBus({
    required String busNumber,
    required String route,
    String? driverName,
    int? capacity,
    String status = "Active",
  }) async {
    try {
      return await _post(
        "/buses",
        {
          "bus_number": busNumber,
          "route": route,
          "driver_name": driverName,
          "capacity": capacity,
          "status": status,
        },
      );
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> updateBus({
    required int busId,
    required String busNumber,
    required String route,
    String? driverName,
    int? capacity,
    String status = "Active",
  }) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/buses/$busId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "bus_number": busNumber,
          "route": route,
          "driver_name": driverName,
          "capacity": capacity,
          "status": status,
        }),
      ).timeout(const Duration(seconds: 8));
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> deleteBus(int busId) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/buses/$busId")).timeout(
        const Duration(seconds: 8),
      );
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl$path"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      return _decodeBody(response);
    } on SocketException {
      throw Exception('Could not reach server. Please check your connection and server URL.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please try again.');
    }
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid server response format');
      }

      if (response.statusCode >= 400) {
        final message = decoded['message'] ?? 'Request failed';
        throw Exception(message);
      }

      return decoded;
    } catch (e) {
      if (response.statusCode >= 400) {
        final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Request failed';
        throw Exception(message);
      }
      throw Exception('Invalid server response: $e');
    }
  }
}