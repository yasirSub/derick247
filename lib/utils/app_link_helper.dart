import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class AppLinkHelper {
  /// Check if app can handle deep links automatically
  /// Returns true if app is verified, false otherwise
  static Future<bool> checkAppLinkVerification() async {
    // For now, we'll check this via a test
    // Android doesn't provide a direct API to check verification status
    // This is more of a helper to guide users
    return false; // Assume not verified if verification error occurred
  }

  /// Open Android app settings to allow user to set app as default
  static Future<void> openAppDefaultSettings() async {
    if (!Platform.isAndroid) return;

    try {
      // Open app info page where user can set default handlers
      final packageName = 'com.example.derick247';
      final uri = Uri.parse('package:$packageName');

      // This opens Android Settings → Apps → derick247
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening app settings: $e');
      // Fallback: Try using Intent
      try {
        final intentUri = Uri.parse(
          'android.settings.APPLICATION_DETAILS_SETTINGS'
          '?package=com.example.derick247',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        }
      } catch (e2) {
        print('Error with Intent fallback: $e2');
      }
    }
  }

  /// Show dialog to guide user to set app as default handler
  static Future<void> showSetDefaultDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Deep Links'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To open links directly in the app:\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('1. Tap "Open Settings" below\n'),
              const Text('2. Find "Open by default" or "Set as default"\n'),
              const Text('3. Enable "Open supported links"\n'),
              const Text('4. Enable for:'),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• derick247.com'),
                    const Text('• www.derick247.com'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tip:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Use custom links (derick247://) which always work without setup!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppDefaultSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
