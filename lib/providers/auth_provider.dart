import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  // Toggle to enable/disable verbose console logging
  static bool debugLogging = false;
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get authToken => _authService.authToken;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.initialize();
      _user = _authService.currentUser;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (debugLogging) {
        print('👤 [AUTH] login called with email: ${email.replaceAll(RegExp(r"(^.).*(@.*$)"), r"$1***$2")}');
      }
      final result = await _authService.login(email, password);

      if (result['success'] == true) {
        if (debugLogging) {
          print('✅ [AUTH] login success. Token present: ${_authService.authToken != null}');
        }
        _user = result['user'];
        _error = null;
        notifyListeners();
        return true;
      } else {
        if (debugLogging) {
          print('⚠️ [AUTH] login failed: ${result['message']}');
        }
        _error = result['message'] ?? 'Login failed. Please try again.';
        notifyListeners();
        return false;
      }
    } on Exception catch (e) {
      if (debugLogging) {
        print('❌ [AUTH] login exception: $e');
      }
      String errorMessage = 'An error occurred during login.';
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        errorMessage = 'Connection timeout. Please check your internet.';
      } else if (errorString.contains('socket')) {
        errorMessage = 'Unable to connect. Please check your internet.';
      }
      _error = errorMessage;
      notifyListeners();
      return false;
    } catch (e) {
      if (debugLogging) {
        print('❌ [AUTH] unexpected error: $e');
      }
      _error = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(userData);

      if (result['success'] == true) {
        _user = result['user'];
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = result['message'] ?? 'Registration failed. Please try again.';
        notifyListeners();
        return false;
      }
    } on Exception catch (e) {
      String errorMessage = 'An error occurred during registration.';
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        errorMessage = 'Connection timeout. Please check your internet.';
      } else if (errorString.contains('socket')) {
        errorMessage = 'Unable to connect. Please check your internet.';
      }
      _error = errorMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // If user is already null, there's nothing to logout
    if (_user == null) {
      print('ℹ️ Logout called but user is already null - no action needed');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _error = null;
      print('✅ User logged out successfully');
    } catch (e) {
      print('⚠️ Error during logout: $e');
      // Even if logout API call fails, clear local user data
      _user = null;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      _user = await _authService.refreshUserData();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String? get userRole => _user?.role;
  bool get isVendor => _user?.isVendor ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isCallCenter => _user?.isCallCenter ?? false;

  // Debug method to print auth token info
  void printAuthTokenInfo() {
    if (!debugLogging) return;
    print('🔑 Auth Token Debug Info:');
    print('   Available: ${authToken != null}');
    print('   Length: ${authToken?.length ?? 0}');
    print('   Preview: ${authToken?.substring(0, 20) ?? 'null'}...');
    print('   User Logged In: $isLoggedIn');
    print('   User ID: ${user?.id}');
    print('   User Email: ${user?.email}');
  }

  // Quick method to print just the token
  void printToken() {
    if (!debugLogging) return;
    if (authToken != null) {
      print('🔑 FULL AUTH TOKEN: $authToken');
    } else {
      print('❌ No auth token available');
    }
  }
}
