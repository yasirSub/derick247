import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const String _callCenterPermissionCode =
      'refer_friend_to_call_center';
  static const String _callCenterPermissionPrefKey =
      'session_can_refer_call_center';

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
          
          // Extract user data and merge permissions from root level
          final userData = Map<String, dynamic>.from(data['user'] ?? data['data'] ?? {});
          
          // Extract permissions from root level if available
          if (data['permissions'] != null && data['permissions'] is List) {
            final permissions = List<String>.from(data['permissions']);
            final role = data['role'] ?? userData['role'] ?? 'user';
            
            // Assign permissions based on role
            if (role == 'vendor') {
              userData['vendor_permission'] = permissions;
            } else {
              userData['user_permissions'] = permissions;
            }
          }
          
          // Also ensure role is set from root level if available
          if (data['role'] != null) {
            userData['role'] = data['role'];
          }
          
          _currentUser = User.fromJson(userData);

          print('✅ [AUTH_SERVICE] Login successful:');
          print('   → Token stored: ${_authToken != null}');
          print('   → User ID: ${_currentUser!.id}');
          print('   → Email: ${_currentUser!.email}');
          print('   → email_verified_at: ${_currentUser!.emailVerifiedAt ?? "NULL"}');
          print('   → google_id: ${_currentUser!.googleId ?? "NULL"}');
          print('   → role: ${_currentUser!.role}');
          print('   → permissions: ${data['permissions'] ?? "N/A"}');

          // Store auth data
          await _storeAuthData();

          return {'success': true, 'user': _currentUser, 'token': _authToken, 'mail_verified_at': _currentUser!.emailVerifiedAt != null};
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
          return {'success': false, 'message': errorMessage};
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
          'message':
              'Login failed. Please check your connection and try again.',
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
        errorMessage =
            'Connection timeout. Please check your internet and try again.';
      } else if (errorString.contains('socket')) {
        errorMessage =
            'Unable to connect. Please check your internet connection.';
      } else if (errorString.contains('failed host lookup')) {
        errorMessage =
            'Unable to reach server. Please check your internet connection.';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final response = await _apiService.googleLogin(
        idToken: idToken,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == true || data['success'] == true) {
          _authToken = data['access_token'] ?? data['token'];
          
          // Extract user data and merge permissions from root level
          final userData = Map<String, dynamic>.from(data['user'] ?? data['data'] ?? {});
          
          // Extract permissions from root level if available
          if (data['permissions'] != null && data['permissions'] is List) {
            final permissions = List<String>.from(data['permissions']);
            final role = data['role'] ?? userData['role'] ?? 'user';
            
            // Assign permissions based on role
            if (role == 'vendor') {
              userData['vendor_permission'] = permissions;
            } else {
              userData['user_permissions'] = permissions;
            }
          }
          
          // Also ensure role is set from root level if available
          if (data['role'] != null) {
            userData['role'] = data['role'];
          }
          
          _currentUser = User.fromJson(userData);

          print('✅ [AUTH_SERVICE] Google login successful:');
          print('   → Token stored: ${_authToken != null}');
          print('   → User ID: ${_currentUser!.id}');
          print('   → Email: ${_currentUser!.email}');
          print('   → email_verified_at: ${_currentUser!.emailVerifiedAt ?? "NULL"}');
          print('   → google_id: ${_currentUser!.googleId ?? "NULL"}');
          print('   → role: ${_currentUser!.role}');
          print('   → permissions: ${data['permissions'] ?? "N/A"}');

          // Store auth data
          await _storeAuthData();

          return {'success': true, 'user': _currentUser, 'token': _authToken, 'mail_verified_at': _currentUser!.emailVerifiedAt != null || _currentUser!.googleId != null};
        } else {
          // Extract error message from response
          String errorMessage = 'Google login failed';
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
          return {'success': false, 'message': errorMessage};
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Google authentication failed. Please try again.',
        };
      } else if (response.statusCode == 422) {
        final data = response.data;
        String errorMessage = 'Invalid Google account.';
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
          'message': 'Google login failed. Please try again.',
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
        errorMessage =
            'Connection timeout. Please check your internet and try again.';
      } else if (errorString.contains('socket')) {
        errorMessage =
            'Unable to connect. Please check your internet connection.';
      } else if (errorString.contains('failed host lookup')) {
        errorMessage =
            'Unable to reach server. Please check your internet connection.';
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
          return {'success': false, 'message': errorMessage};
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
          'message':
              'Registration failed. Please check your connection and try again.',
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
        errorMessage =
            'Connection timeout. Please check your internet and try again.';
      } else if (errorString.contains('socket')) {
        errorMessage =
            'Unable to connect. Please check your internet connection.';
      } else if (errorString.contains('failed host lookup')) {
        errorMessage =
            'Unable to reach server. Please check your internet connection.';
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
    print('💾 [AUTH_SERVICE] Storing auth data...');
    
    if (_authToken != null) {
      print('   → Storing auth_token in SecureStorage');
      await _secureStorage.write(key: 'auth_token', value: _authToken);
      _apiService.setAuthToken(_authToken!);
    } else {
      print('   ⚠️ No auth_token to store');
    }

    if (_currentUser != null) {
      print('   → Storing user_data in SharedPreferences');
      print('      • User ID: ${_currentUser!.id}');
      print('      • Email: ${_currentUser!.email}');
      print('      • email_verified_at: ${_currentUser!.emailVerifiedAt ?? "NULL"}');
      print('      • google_id: ${_currentUser!.googleId ?? "NULL"}');
      print('      • role: ${_currentUser!.role}');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));

      final hasCallCenterPermission =
          _currentUser!.userPermissions.contains(_callCenterPermissionCode) ||
              _currentUser!.vendorPermissions
                  .contains(_callCenterPermissionCode);
      await prefs.setBool(
        _callCenterPermissionPrefKey,
        hasCallCenterPermission,
      );
      
      // Also store email_verified_at separately in session storage for backup
      if (_currentUser!.emailVerifiedAt != null && _currentUser!.emailVerifiedAt!.isNotEmpty) {
        print('   → Storing email_verified_at in session storage: ${_currentUser!.emailVerifiedAt}');
        await prefs.setString('session_email_verified_at', _currentUser!.emailVerifiedAt!);
      }
      
      // Store google_id separately for email verification check
      if (_currentUser!.googleId != null && _currentUser!.googleId!.isNotEmpty) {
        print('   → Storing google_id in session storage: ${_currentUser!.googleId}');
        await prefs.setString('session_google_id', _currentUser!.googleId!);
      }
      
      print('   ✅ Auth data stored successfully');
    } else {
      print('   ⚠️ No user data to store');
    }
  }

  Future<void> _clearAuthData() async {
    _authToken = null;
    _currentUser = null;

    await _secureStorage.delete(key: 'auth_token');
    _apiService.clearAuthToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove(_callCenterPermissionPrefKey);
  }

  Future<User?> refreshUserData() async {
    try {
      if (_authToken == null) {
        print('⚠️ [AUTH_SERVICE] Cannot refresh user data - no auth token');
        return null;
      }

      print('🔄 [AUTH_SERVICE] Refreshing user data from API...');
      print('   → Current user email_verified_at: ${_currentUser?.emailVerifiedAt ?? "NULL"}');
      print('   → Current user google_id: ${_currentUser?.googleId ?? "NULL"}');

      final response = await _apiService.getProfile();
      if (response.statusCode == 200) {
        final data = response.data;
        // Handle both nested 'data' and direct response formats
        final profileData = data is Map<String, dynamic> && data['data'] != null
            ? data['data']
            : data;
        
        print('📥 [AUTH_SERVICE] Profile API Response received:');
        print('   → Country: ${profileData['country']}');
        print('   → State: ${profileData['state']}');
        print('   → City: ${profileData['city']}');
        print('   → email_verified_at in response: ${profileData['email_verified_at'] ?? "NULL"}');
        print('   → google_id in response: ${profileData['google_id'] ?? "NULL"}');
        
        // Preserve email_verified_at from current user if API doesn't return it
        final oldEmailVerifiedAt = _currentUser?.emailVerifiedAt;
        final oldGoogleId = _currentUser?.googleId;
        
        // Also check session storage as backup
        final prefs = await SharedPreferences.getInstance();
        final sessionEmailVerifiedAt = prefs.getString('session_email_verified_at');
        final sessionGoogleId = prefs.getString('session_google_id');
        
        // Merge preserved values into profileData BEFORE creating User object
        if ((profileData['email_verified_at'] == null || profileData['email_verified_at'].toString().isEmpty)) {
          // Try to get from old user first, then session storage
          final preservedEmailVerifiedAt = oldEmailVerifiedAt ?? sessionEmailVerifiedAt;
          if (preservedEmailVerifiedAt != null && preservedEmailVerifiedAt.isNotEmpty) {
            print('   ⚠️ API response missing email_verified_at, merging preserved value: $preservedEmailVerifiedAt');
            profileData['email_verified_at'] = preservedEmailVerifiedAt;
            // Also update session storage
            await prefs.setString('session_email_verified_at', preservedEmailVerifiedAt);
          }
        }
        
        // Merge preserved google_id if API doesn't return it
        if ((profileData['google_id'] == null || profileData['google_id'].toString().isEmpty)) {
          final preservedGoogleId = oldGoogleId ?? sessionGoogleId;
          if (preservedGoogleId != null && preservedGoogleId.isNotEmpty) {
            print('   ⚠️ API response missing google_id, merging preserved value: $preservedGoogleId');
            profileData['google_id'] = preservedGoogleId;
            // Also update session storage
            await prefs.setString('session_google_id', preservedGoogleId);
          }
        }
        
        // Now create User object with merged data
        _currentUser = User.fromJson(profileData);
        
        print('   → After refresh - email_verified_at: ${_currentUser!.emailVerifiedAt ?? "NULL"}');
        print('   → After refresh - google_id: ${_currentUser!.googleId ?? "NULL"}');
        
        await _storeAuthData();
        return _currentUser;
      } else {
        print('❌ [AUTH_SERVICE] Profile API returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AUTH_SERVICE] Error refreshing user data: $e');
    }
    return null;
  }
}
