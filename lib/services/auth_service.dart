import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

  User? _currentUser;
  String? _authToken;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isLoggedIn => _authToken != null && _currentUser != null;

  Future<void> initialize() async {
    await _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    try {
      _authToken = await _secureStorage.read(key: 'auth_token');
      if (_authToken != null) {
        _apiService.setAuthToken(_authToken!);
        await _loadUserData();
      }
    } catch (e) {
      print('Error loading auth data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        // Parse user data if needed
        _currentUser = null; // Will be loaded from API
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == true || data['success'] == true) {
          _authToken = data['access_token'] ?? data['token'];
          _currentUser = User.fromJson(data['user'] ?? data['data']);

          // Store auth data
          await _storeAuthData();

          return {'success': true, 'user': _currentUser, 'token': _authToken};
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login failed',
          };
        }
      } else {
        return {'success': false, 'message': 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await _apiService.register(userData);

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          _authToken = data['data']['token'];
          _currentUser = User.fromJson(data['data']);

          // Store auth data
          await _storeAuthData();

          return {'success': true, 'user': _currentUser, 'token': _authToken};
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Registration failed',
          };
        }
      } else {
        return {'success': false, 'message': 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<void> logout() async {
    try {
      if (_authToken != null) {
        await _apiService.logout();
      }
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      await _clearAuthData();
    }
  }

  Future<void> _storeAuthData() async {
    if (_authToken != null) {
      await _secureStorage.write(key: 'auth_token', value: _authToken);
      _apiService.setAuthToken(_authToken!);
    }

    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', _currentUser!.toJson().toString());
    }
  }

  Future<void> _clearAuthData() async {
    _authToken = null;
    _currentUser = null;

    await _secureStorage.delete(key: 'auth_token');
    _apiService.clearAuthToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  Future<User?> refreshUserData() async {
    try {
      if (_authToken == null) return null;

      final response = await _apiService.getProfile();
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['data'] != null) {
          _currentUser = User.fromJson(data['data']);
          await _storeAuthData();
          return _currentUser;
        }
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
    return null;
  }
}
