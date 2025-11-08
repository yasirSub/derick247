import 'dart:convert';
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
        final userData = jsonDecode(userJson);
        _currentUser = User.fromJson(userData);
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
          // Extract error message from response
          String errorMessage = 'Login failed';
          if (data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
          } else if (data['errors'] != null) {
            if (data['errors'] is Map) {
              final errors = data['errors'] as Map;
              errorMessage = errors.values.first.toString();
            } else if (data['errors'] is List) {
              errorMessage = data['errors'].first.toString();
            }
          }
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid email or password. Please try again.',
        };
      } else if (response.statusCode == 422) {
        final data = response.data;
        String errorMessage = 'Invalid input. Please check your credentials.';
        if (data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data['errors'] != null) {
          if (data['errors'] is Map) {
            final errors = data['errors'] as Map;
            errorMessage = errors.values.first.toString();
          }
        }
        return {'success': false, 'message': errorMessage};
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed. Please check your connection and try again.',
        };
      }
    } on FormatException {
      return {
        'success': false,
        'message': 'Invalid response from server. Please try again.',
      };
    } on Exception catch (e) {
      String errorMessage = 'Network error. Please check your connection.';
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        errorMessage = 'Connection timeout. Please check your internet and try again.';
      } else if (errorString.contains('socket')) {
        errorMessage = 'Unable to connect. Please check your internet connection.';
      } else if (errorString.contains('failed host lookup')) {
        errorMessage = 'Unable to reach server. Please check your internet connection.';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
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
          // Extract error message from response
          String errorMessage = 'Registration failed';
          if (data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
          } else if (data['errors'] != null) {
            if (data['errors'] is Map) {
              final errors = data['errors'] as Map;
              errorMessage = errors.values.first.toString();
            } else if (data['errors'] is List) {
              errorMessage = data['errors'].first.toString();
            }
          }
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } else if (response.statusCode == 422) {
        final data = response.data;
        String errorMessage = 'Invalid input. Please check your information.';
        if (data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data['errors'] != null) {
          if (data['errors'] is Map) {
            final errors = data['errors'] as Map;
            errorMessage = errors.values.first.toString();
          }
        }
        return {'success': false, 'message': errorMessage};
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'message': 'Email already exists. Please use a different email.',
        };
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        return {
          'success': false,
          'message': 'Registration failed. Please check your connection and try again.',
        };
      }
    } on FormatException {
      return {
        'success': false,
        'message': 'Invalid response from server. Please try again.',
      };
    } on Exception catch (e) {
      String errorMessage = 'Network error. Please check your connection.';
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        errorMessage = 'Connection timeout. Please check your internet and try again.';
      } else if (errorString.contains('socket')) {
        errorMessage = 'Unable to connect. Please check your internet connection.';
      } else if (errorString.contains('failed host lookup')) {
        errorMessage = 'Unable to reach server. Please check your internet connection.';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
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
      await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
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
