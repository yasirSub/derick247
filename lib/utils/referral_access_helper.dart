import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../providers/auth_provider.dart';

class ReferralAccessHelper {
  static const String _blockedMessage =
      'You are blocked from the call center.';

  static bool blockIfNoPermission({
    required BuildContext context,
    required AuthProvider authProvider,
  }) {
    if (authProvider.isLoggedIn &&
        !authProvider.canReferFriendToCallCenter) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(_blockedMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return true;
    }
    return false;
  }
}

