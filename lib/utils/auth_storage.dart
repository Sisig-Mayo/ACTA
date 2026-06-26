/// ACTA Frontend — Auth Storage Helper
/// ======================================
/// Persists and retrieves the Supabase access token using
/// SharedPreferences (localStorage on web) so that the user
/// session survives page refreshes.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Simple wrapper around SharedPreferences for auth token persistence.
class AuthStorage {
  static const _tokenKey = 'acta_access_token';

  /// Persist the access token.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Retrieve the stored access token, or null if none exists.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Remove the stored access token (logout).
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
