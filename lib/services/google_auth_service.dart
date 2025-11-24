import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignIn? _googleSignIn;
  String? _cachedClientId;
  bool _isInitializing = false;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  // Initialize Google Sign In with client ID from app-assets API
  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignIn != null && _cachedClientId != null) {
      return; // Already initialized
    }

    if (_isInitializing) {
      // Wait for ongoing initialization
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;

    try {
      // Fetch app assets to get Google client ID
      final apiService = ApiService();
      // Ensure ApiService is initialized
      apiService.initialize();
      final response = await apiService.getAppAssets();

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        String? clientId;

        // Extract Google client_id from response
        if (data is Map<String, dynamic>) {
          final appData = data['data'];
          if (appData is Map<String, dynamic>) {
            final socialiteLogin = appData['socialite_login'];
            if (socialiteLogin is Map<String, dynamic>) {
              final google = socialiteLogin['google'];
              if (google is Map<String, dynamic>) {
                clientId = google['client_id'] as String?;
              }
            }
          }
        }

        if (clientId != null && clientId.isNotEmpty) {
          _cachedClientId = clientId;
          
          // Note: serverClientId is the Web Client ID used for server-side token verification
          // For Android to work, you must also configure an Android OAuth Client ID in Google Cloud Console
          // with your package name (com.example.derick247) and SHA-1 fingerprint
          _googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
            serverClientId: clientId, // Web client ID for ID token (server verification)
            // Android client ID should be configured in Google Cloud Console
            // The package name must match: com.example.derick247
          );

          if (kDebugMode) {
            print('✅ Google Sign-In initialized with client ID from API');
            print('   → Web Client ID: $clientId');
            print('   → Note: Android OAuth Client must be configured in Google Cloud Console');
            print('   → Package name: com.example.derick247');
            print('   → SHA-1 fingerprint must be registered');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Google client_id not found in app-assets response');
            print('   → Using default Google Sign-In (requires Android OAuth Client in Google Cloud Console)');
          }
          // Fallback to default initialization
          // This requires Android OAuth Client to be configured in Google Cloud Console
          _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Failed to fetch app-assets, using default Google Sign-In');
        }
        // Fallback to default initialization
        _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Google Sign-In: $e');
        print('   → Falling back to default initialization');
      }
      // Fallback to default initialization
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    } finally {
      _isInitializing = false;
    }
  }

  // Get GoogleSignIn instance, initializing if needed
  Future<GoogleSignIn> _getGoogleSignIn() async {
    if (_googleSignIn == null) {
      await _initializeGoogleSignIn();
    }
    return _googleSignIn!;
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        print('🔐 Starting Google Sign-In...');
      }

      // Ensure GoogleSignIn is initialized
      final googleSignIn = await _getGoogleSignIn();

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          print('❌ User cancelled Google Sign-In');
        }
        return {'success': false, 'message': 'Sign-in cancelled'};
      }

      _currentUser = googleUser;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        print('✅ Google Sign-In successful');
        print('   → Email: ${googleUser.email}');
        print('   → Name: ${googleUser.displayName}');
        print('   → ID: ${googleUser.id}');
        print('   → Has idToken: ${googleAuth.idToken != null}');
        print('   → Has accessToken: ${googleAuth.accessToken != null}');
      }

      return {
        'success': true,
        'user': googleUser,
        'idToken': googleAuth.idToken,
        'accessToken': googleAuth.accessToken,
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'id': googleUser.id,
      };
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error signing in with Google: $error');
        
        // Check for specific error codes
        final errorString = error.toString();
        if (errorString.contains('ApiException: 10')) {
          print('');
          print('⚠️ DEVELOPER_ERROR (Code 10) - Configuration Issue:');
          print('   This error means the Android OAuth Client is not properly configured.');
          print('   To fix this:');
          print('   1. Go to Google Cloud Console: https://console.cloud.google.com/');
          print('   2. Select your project');
          print('   3. Go to APIs & Services > Credentials');
          print('   4. Create OAuth 2.0 Client ID for Android');
          print('   5. Package name: com.example.derick247');
          print('   6. Add your SHA-1 fingerprint (run: cd android && ./gradlew signingReport)');
          print('   7. Save the Android Client ID');
          print('');
        }
      }
      
      String errorMessage = 'Failed to sign in with Google';
      final errorString = error.toString();
      if (errorString.contains('ApiException: 10')) {
        errorMessage = 'Google Sign-In configuration error. Please contact support or check Google Cloud Console settings.';
      } else if (errorString.contains('network') || errorString.contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('cancelled') || errorString.contains('CANCELLED')) {
        errorMessage = 'Sign-in was cancelled.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      _currentUser = null;
      if (kDebugMode) {
        print('✅ Google Sign-Out successful');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error signing out from Google: $error');
      }
    }
  }

  // Check if user is currently signed in with Google
  Future<bool> isSignedIn() async {
    try {
      if (_googleSignIn == null) {
        await _initializeGoogleSignIn();
      }
      return await _googleSignIn!.isSignedIn();
    } catch (e) {
      return false;
    }
  }

  // Silent sign-in (if previously signed in)
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final googleSignIn = await _getGoogleSignIn();
      _currentUser = await googleSignIn.signInSilently();
      return _currentUser;
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error during silent sign-in: $error');
      }
      return null;
    }
  }
}
