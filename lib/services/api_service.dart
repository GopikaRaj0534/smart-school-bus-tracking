import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000";

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "full_name": fullName,
        "email": email,
        "phone": phone,
        "password": password,
        "role": role,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "role": role,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getBuses() async {
    final response = await http.get(Uri.parse("$baseUrl/buses"));
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addBus({
    required String busNumber,
    required String route,
    String? driverName,
    int? capacity,
    String status = "Active",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/buses"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "bus_number": busNumber,
        "route": route,
        "driver_name": driverName,
        "capacity": capacity,
        "status": status,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateBus({
    required int busId,
    required String busNumber,
    required String route,
    String? driverName,
    int? capacity,
    String status = "Active",
  }) async {
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
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteBus(int busId) async {
    final response = await http.delete(Uri.parse("$baseUrl/buses/$busId"));
    return jsonDecode(response.body);
  }
}