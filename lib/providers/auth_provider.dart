import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  // Toggle to enable/disable verbose console logging
  static bool debugLogging = false;
  static const String _callCenterPermissionCode =
      'refer_friend_to_call_center';
  static const String _callCenterPermissionPrefKey =
      'session_can_refer_call_center';

  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _canReferFriendToCallCenter = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get canReferFriendToCallCenter => _canReferFriendToCallCenter;
  bool get isEmailVerified {
    // Priority 1: Check user object email_verified_at
    if (_user?.emailVerifiedAt != null && _user!.emailVerifiedAt!.isNotEmpty) {
      return true;
    }
    // Priority 2: Check user object google_id (Google sign-in auto-verifies)
    if (_user?.googleId != null && _user!.googleId!.isNotEmpty) {
      return true;
    }
    // Priority 3: Check session storage (synchronous check)
    // Note: This is a synchronous getter, so we can't do async here
    // But we'll check it in the async method below
    return false;
  }
  
  // Async method to check email verification including session storage
  Future<bool> checkEmailVerified() async {
    // Priority 1: Check user object email_verified_at
    if (_user?.emailVerifiedAt != null && _user!.emailVerifiedAt!.isNotEmpty) {
      return true;
    }
    // Priority 2: Check user object google_id
    if (_user?.googleId != null && _user!.googleId!.isNotEmpty) {
      return true;
    }
    // Priority 3: Check session storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionEmailVerified = prefs.getString('session_email_verified_at');
      if (sessionEmailVerified != null && sessionEmailVerified.isNotEmpty) {
        print('✅ [AUTH_PROVIDER] Email verified from session storage: $sessionEmailVerified');
        return true;
      }
      final sessionGoogleId = prefs.getString('session_google_id');
      if (sessionGoogleId != null && sessionGoogleId.isNotEmpty) {
        print('✅ [AUTH_PROVIDER] Google ID found in session storage - email verified');
        return true;
      }
    } catch (e) {
      print('⚠️ [AUTH_PROVIDER] Error checking session storage: $e');
    }
    return false;
  }
  bool _requiresEmailVerification = false;
  bool get requiresEmailVerification => _requiresEmailVerification;
  String? get authToken => _authService.authToken;

  Future<void> initialize() async {
    _isLoading = true;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      await _authService.initialize();
      _user = _authService.currentUser;
      _error = null;
      await _updateCallCenterPermission(_user);
      
      // Check and log email verification status
      _checkEmailVerificationStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check and log email verification status
  void _checkEmailVerificationStatus() {
    if (_user != null) {
      final verified = isEmailVerified;
      final emailVerifiedAt = _user!.emailVerifiedAt;
      final hasGoogleId = _user!.googleId != null && _user!.googleId!.isNotEmpty;
      
      // Always log email verification status for debugging
      print('📧 [EMAIL VERIFICATION CHECK]');
      print('   → Email: ${_user!.email}');
      print('   → Is Verified: $verified');
      print('   → email_verified_at: $emailVerifiedAt');
      print('   → Has Google ID: $hasGoogleId');
      print('   → Requires Verification: $_requiresEmailVerification');
      if (verified) {
        print('   ✅ Email is VERIFIED');
      } else {
        print('   ⚠️ Email is NOT VERIFIED');
      }
    }
  }

  bool _hasCallCenterPermission(User? user) {
    if (user == null) return false;
    return user.userPermissions.contains(_callCenterPermissionCode) ||
        user.vendorPermissions.contains(_callCenterPermissionCode);
  }

  Future<void> _updateCallCenterPermission(User? user) async {
    final hasPermission = _hasCallCenterPermission(user);
    _canReferFriendToCallCenter = hasPermission;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_callCenterPermissionPrefKey, hasPermission);
    } catch (e) {
      if (debugLogging) {
        print('⚠️ [AUTH_PROVIDER] Failed to cache call center permission: $e');
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (debugLogging) {
        print(
          '👤 [AUTH] login called with email: ${email.replaceAll(RegExp(r"(^.).*(@.*$)"), r"$1***$2")}',
        );
      }
      final result = await _authService.login(email, password);

      if (result['success'] == true) {
        if (debugLogging) {
          print(
            '✅ [AUTH] login success. Token present: ${_authService.authToken != null}',
          );
        }
        _user = result['user'];
        _error = null;
        await _updateCallCenterPermission(_user);
        notifyListeners();
        final emailVerified =
            (_user?.emailVerifiedAt != null &&
                _user!.emailVerifiedAt!.isNotEmpty) ||
            (result['mail_verified_at'] == true);
        _requiresEmailVerification = !emailVerified;
        
        // Check and log email verification status
        _checkEmailVerificationStatus();
        
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

  Future<bool> loginWithGoogle({
    required String idToken,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (debugLogging) {
        print(
          '👤 [AUTH] Google login called with email: ${email.replaceAll(RegExp(r"(^.).*(@.*$)"), r"$1***$2")}',
        );
      }
      final result = await _authService.loginWithGoogle(
        idToken: idToken,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );

      if (result['success'] == true) {
        if (debugLogging) {
          print(
            '✅ [AUTH] Google login success. Token present: ${_authService.authToken != null}',
          );
        }
        _user = result['user'];
        _error = null;
        await _updateCallCenterPermission(_user);
        notifyListeners();
        
        // Google sign-in emails are already verified by Google
        // Check if email is verified from user data or result flag
        final emailVerified =
            (_user?.emailVerifiedAt != null &&
                _user!.emailVerifiedAt!.isNotEmpty) ||
            (result['mail_verified_at'] == true);
        
        // If user logged in via Google and email_verified_at is still null,
        // treat as verified (Google emails are pre-verified)
        if (!emailVerified && _user?.googleId != null && _user!.googleId!.isNotEmpty) {
          if (debugLogging) {
            print('✅ [AUTH] Google sign-in detected - treating email as verified');
          }
          _requiresEmailVerification = false;
        } else {
          _requiresEmailVerification = !emailVerified;
        }
        
        // Check and log email verification status
        _checkEmailVerificationStatus();
        
        return true;
      } else {
        if (debugLogging) {
          print('⚠️ [AUTH] Google login failed: ${result['message']}');
        }
        _error = result['message'] ?? 'Google login failed. Please try again.';
        notifyListeners();
        return false;
      }
    } on Exception catch (e) {
      if (debugLogging) {
        print('❌ [AUTH] Google login exception: $e');
      }
      String errorMessage = 'An error occurred during Google login.';
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
        await _updateCallCenterPermission(_user);
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
      await _updateCallCenterPermission(null);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _error = null;
      await _updateCallCenterPermission(null);
      print('✅ User logged out successfully');
    } catch (e) {
      print('⚠️ Error during logout: $e');
      // Even if logout API call fails, clear local user data
      _user = null;
      _error = null;
      await _updateCallCenterPermission(null);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      _user = await _authService.refreshUserData();
      _requiresEmailVerification = !isEmailVerified;
      await _updateCallCenterPermission(_user);
      
      // Check and log email verification status after refresh
      _checkEmailVerificationStatus();
      
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
