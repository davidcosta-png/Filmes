import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthService {
  // Backend base URL comes from lib/config.dart (BACKEND_BASE)
  final String base = BACKEND_BASE;

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$base/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Login failed: ${res.body}');
  }

  Future<Map<String, dynamic>> me(String token) async {
    final url = Uri.parse('$base/auth/me');
    final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to validate token: ${res.body}');
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final url = Uri.parse('$base/auth/refresh');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refreshToken': refreshToken}),
    );
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to refresh token: ${res.body}');
  }

  Future<void> logout(String refreshToken) async {
    final url = Uri.parse('$base/auth/logout');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refreshToken': refreshToken}),
    );
    if (res.statusCode != 200) throw Exception('Failed to logout: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getUsers(String token) async {
    final url = Uri.parse('$base/users');
    final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as List;
      return body.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch users: ${res.body}');
  }

  Future<void> pauseUser(String token, String username, bool paused) async {
    final url = Uri.parse('$base/users/$username/pause');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: json.encode({'paused': paused}),
    );
    if (res.statusCode != 200) throw Exception('Failed to pause user: ${res.body}');
  }

  Future<void> deleteUser(String token, String username) async {
    final url = Uri.parse('$base/users/$username');
    final res = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to delete user: ${res.body}');
  }

  Future<void> createUser(String token, String username, String password, {String role = 'user'}) async {
    final url = Uri.parse('$base/users');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: json.encode({'username': username, 'password': password, 'role': role}),
    );
    if (res.statusCode != 201) throw Exception('Failed to create user: ${res.body}');
  }
}
