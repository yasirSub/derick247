import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class EmailVerifiedSuccessScreen extends StatefulWidget {
  final String? email;
  final Uri? verificationLink;

  const EmailVerifiedSuccessScreen({
    super.key,
    this.email,
    this.verificationLink,
  });

  @override
  State<EmailVerifiedSuccessScreen> createState() =>
      _EmailVerifiedSuccessScreenState();
}

class _EmailVerifiedSuccessScreenState
    extends State<EmailVerifiedSuccessScreen> {
  bool _refreshing = true;
  bool _navigating = false;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _verifyAndRefresh();
  }

  Future<void> _verifyAndRefresh() async {
    try {
      if (widget.verificationLink != null) {
        await ApiService().confirmEmailVerification(widget.verificationLink!);
      }
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) {
        await auth.initialize();
      }
      await auth.refreshUser();
    } catch (e) {
      _verificationError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _goToLogin() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailText = widget.email ?? 'Your email';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: ResponsiveScaffoldBody(
          maxContentWidth: 420,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  const Text(
                    'Email verified!',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeXXLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    _verificationError == null
                        ? '$emailText has been verified successfully.'
                        : 'We attempted to verify your email, but encountered an issue.',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: (_verificationError == null
                              ? AppTheme.successColor
                              : AppTheme.errorColor)
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _verificationError == null
                              ? Icons.lock_open
                              : Icons.error_outline,
                          color: _verificationError == null
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _verificationError == null
                                ? 'Your account is now ready. Tap continue to start exploring.'
                                : 'Please tap continue to proceed once your email link succeeds, or try again later.',
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  _PrimaryButton(
                    label: _refreshing
                        ? 'Syncing account...'
                        : 'Back to login',
                    icon: Icons.login,
                    loading: _refreshing || _navigating,
                    onPressed: _refreshing ? null : _goToLogin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

