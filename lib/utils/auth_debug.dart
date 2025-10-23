import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Utility class for debugging authentication tokens
class AuthDebug {
  /// Print auth token info to console
  static void printAuthToken(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('\n🔑 AUTH TOKEN DEBUG UTILITY');
    print('=' * 60);
    authProvider.printAuthTokenInfo();
    authProvider.printToken();
    print('=' * 60);
  }

  /// Print just the token
  static void printTokenOnly(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.printToken();
  }

  /// Print detailed auth info
  static void printDetailedInfo(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('\n📊 DETAILED AUTH INFO');
    print('=' * 50);
    print('👤 Full Name: ${authProvider.user?.fullName ?? 'null'}');
    print('👤 Username: ${authProvider.user?.username ?? 'null'}');
    print('📧 Email: ${authProvider.user?.email ?? 'null'}');
    print('📱 Phone: ${authProvider.user?.phone ?? 'null'}');
    print('🆔 User ID: ${authProvider.user?.id ?? 'null'}');
    print('🔑 Token Available: ${authProvider.authToken != null}');
    print('📏 Token Length: ${authProvider.authToken?.length ?? 0}');
    print('🔐 Logged In: ${authProvider.isLoggedIn}');
    print('👑 Role: ${authProvider.userRole ?? 'null'}');
    print('🏪 Is Vendor: ${authProvider.isVendor}');
    print('👨‍💼 Is Admin: ${authProvider.isAdmin}');
    print('📞 Is Call Center: ${authProvider.isCallCenter}');
    print('💰 Currency: ${authProvider.user?.currency ?? 'null'}');
    print('📍 Address: ${authProvider.user?.address ?? 'null'}');
    print('📅 Created: ${authProvider.user?.createdAt ?? 'null'}');
    print('=' * 50);
  }

  /// Get the auth token as a string
  static String? getToken(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.authToken;
  }

  /// Check if user is logged in
  static bool isLoggedIn(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.isLoggedIn;
  }

  /// Print token in API-ready format
  static void printApiHeaders(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('\n🌐 API HEADERS FOR TESTING');
    print('=' * 50);
    print('Authorization: Bearer ${authProvider.authToken ?? 'null'}');
    print('x-api-key: gcs##2022##');
    print('Content-Type: application/json');
    print('Accept: application/json');
    print('=' * 50);
  }

  /// Print curl command for testing
  static void printCurlCommand(BuildContext context, String url) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    print('\n🐚 CURL COMMAND FOR TESTING');
    print('=' * 60);
    print('curl -X GET "$url" \\');
    print(
      '  -H "Authorization: Bearer ${authProvider.authToken ?? 'null'}" \\',
    );
    print('  -H "x-api-key: gcs##2022##" \\');
    print('  -H "Content-Type: application/json" \\');
    print('  -H "Accept: application/json"');
    print('=' * 60);
  }
}
