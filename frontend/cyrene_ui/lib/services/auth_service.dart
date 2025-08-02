// services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService with ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  User? _user;
  bool _isLoading = true;
  Timer? _tokenRefreshTimer;

  bool get isAuthenticated => _accessToken != null && _user != null;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  // Add the token getter that your dashboard is looking for
  String? get token => _accessToken;
  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthService() {
    _loadTokens();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');

      if (_accessToken != null && _refreshToken != null) {
        // Validate token and get user info
        await _validateAndRefreshToken();
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
      await _clearTokens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _validateAndRefreshToken() async {
    try {
      // Try to get user info with current token
      final response = await http.get(
        Uri.parse('${AppConfig.fastApiAuthUrl}/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _user = User.fromJson(userData);
        _scheduleTokenRefresh();
      } else if (response.statusCode == 401 && _refreshToken != null) {
        // Try to refresh token
        await _refreshAccessToken();
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('Token validation failed: $e');
      if (_refreshToken != null) {
        await _refreshAccessToken();
      } else {
        await logout();
      }
    }
  }

  Future<void> _refreshAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fastApiAuthUrl}/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        _accessToken = authResponse.accessToken;
        _refreshToken = authResponse.refreshToken;

        await _saveTokens();
        await _getUserInfo();
        _scheduleTokenRefresh();
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await logout();
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fastApiAuthUrl}/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _user = User.fromJson(userData);
      } else {
        throw Exception('Failed to get user info');
      }
    } catch (e) {
      debugPrint('Failed to get user info: $e');
      rethrow;
    }
  }

  void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    // Refresh token 5 minutes before expiry (25 minutes for 30-minute tokens)
    _tokenRefreshTimer = Timer(const Duration(minutes: 25), () {
      _refreshAccessToken();
    });
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refresh_token', _refreshToken!);
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _tokenRefreshTimer?.cancel();
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fastApiAuthUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );

      if (response.statusCode == 201) {
        // Registration successful, can now login
        await login(username, password);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fastApiAuthUrl}/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        _accessToken = authResponse.accessToken;
        _refreshToken = authResponse.refreshToken;

        debugPrint('🔐 Access Token: $_accessToken');
        final decoded = JwtDecoder.decode(_accessToken!);
        debugPrint('📦 Decoded Token Payload: $decoded');

        await _saveTokens();
        await _getUserInfo();
        _scheduleTokenRefresh();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        // Call logout endpoint
        await http.post(
          Uri.parse('${AppConfig.fastApiAuthUrl}/logout'),
          headers: {'Authorization': 'Bearer $_accessToken'},
        );
      }
    } catch (e) {
      debugPrint('Logout API call failed: $e');
    } finally {
      await _clearTokens();
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? fullName,
    String? password,
  }) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> updateData = {};
      if (username != null) updateData['username'] = username;
      if (email != null) updateData['email'] = email;
      if (fullName != null) updateData['full_name'] = fullName;
      if (password != null) updateData['password'] = password;

      final response = await http.put(
        Uri.parse('${AppConfig.fastApiAuthUrl}/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _user = User.fromJson(userData);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Update failed');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (_accessToken == null) {
      throw Exception('Not authenticated');
    }
    return {'Authorization': 'Bearer $_accessToken'};
  }

  Future<bool> validateToken() async {
    if (_accessToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fastApiAuthUrl}/validate_token'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
