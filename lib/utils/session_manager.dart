import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyIsLoggedIn = "is_logged_in";
  static const _keyUserId = "user_id";
  static const _keyFullName = "full_name";
  static const _keyEmail = "email";
  static const _keyRole = "role";
  static const _keyPhone = "phone";

  static Future<void> saveSession({
    required String fullName,
    required String email,
    required String role,
    int? userId,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyRole, role);
    if (userId != null) {
      await prefs.setInt(_keyUserId, userId);
    }
    if (phone != null) {
      await prefs.setString(_keyPhone, phone);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!loggedIn) return null;

    final userIdInt = prefs.getInt(_keyUserId);

    return {
      "user_id": userIdInt != null ? userIdInt.toString() : "",
      "full_name": prefs.getString(_keyFullName) ?? "",
      "email": prefs.getString(_keyEmail) ?? "",
      "role": prefs.getString(_keyRole) ?? "",
      "phone": prefs.getString(_keyPhone) ?? "",
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyPhone);
  }
}