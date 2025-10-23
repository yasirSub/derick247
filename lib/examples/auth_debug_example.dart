import 'package:flutter/material.dart';
import '../utils/auth_debug.dart';

/// Example usage of AuthDebug utility
class AuthDebugExample {
  /// Example 1: Basic token info
  static void printBasicInfo(BuildContext context) {
    AuthDebug.printAuthToken(context);
  }

  /// Example 2: Detailed user info
  static void printUserDetails(BuildContext context) {
    AuthDebug.printDetailedInfo(context);
  }

  /// Example 3: API headers for testing
  static void printHeaders(BuildContext context) {
    AuthDebug.printApiHeaders(context);
  }

  /// Example 4: Curl command for API testing
  static void printCurlExample(BuildContext context) {
    AuthDebug.printCurlCommand(context, 'https://derick247.com/api/cart');
  }

  /// Example 5: Get token programmatically
  static void useTokenProgrammatically(BuildContext context) {
    String? token = AuthDebug.getToken(context);
    if (token != null) {
      print('Token retrieved: ${token.substring(0, 20)}...');
      // Use token in your API calls
    } else {
      print('No token available');
    }
  }

  /// Example 6: Check login status
  static void checkLoginStatus(BuildContext context) {
    bool loggedIn = AuthDebug.isLoggedIn(context);
    print('User is logged in: $loggedIn');
  }

  /// Example 7: Complete debug session
  static void runCompleteDebugSession(BuildContext context) {
    print('\n🔍 COMPLETE DEBUG SESSION');
    print('=' * 60);

    AuthDebug.printAuthToken(context);
    AuthDebug.printDetailedInfo(context);
    AuthDebug.printApiHeaders(context);
    AuthDebug.printCurlCommand(context, 'https://derick247.com/api/cart');

    print('\n✅ Debug session complete!');
    print('=' * 60);
  }
}

/// Widget example showing how to use AuthDebug in a Flutter widget
class DebugButton extends StatelessWidget {
  const DebugButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => AuthDebug.printAuthToken(context),
          child: const Text('Print Auth Token'),
        ),
        ElevatedButton(
          onPressed: () => AuthDebug.printDetailedInfo(context),
          child: const Text('Print Detailed Info'),
        ),
        ElevatedButton(
          onPressed: () => AuthDebug.printApiHeaders(context),
          child: const Text('Print API Headers'),
        ),
        ElevatedButton(
          onPressed: () => AuthDebug.printCurlCommand(
            context,
            'https://derick247.com/api/cart',
          ),
          child: const Text('Print Curl Command'),
        ),
      ],
    );
  }
}
