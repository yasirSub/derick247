import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/responsive.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _resending = false;
  bool _loggingOut = false;

  void _navigateHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<AuthProvider>().logout();
    } catch (_) {
      // ignore logout errors here
    } finally {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resending) return;
    setState(() => _resending = true);
    final messenger = ScaffoldMessenger.of(context);
    debugPrint('📧 [VERIFY EMAIL] Resending verification to ${widget.email}');
    try {
      final response = await ApiService().resendVerification(
        email: widget.email,
      );
      debugPrint(
        '📧 [VERIFY EMAIL] resend response: ${response.statusCode} ${response.data}',
      );
      final status = response.statusCode ?? 500;
      if (status >= 200 && status < 300) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent again. Please check your inbox.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              response.data?['message']?.toString() ??
                  'Unable to resend verification email.',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _navigateHome,
          ),
        ),
        body: ResponsiveScaffoldBody(
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppTheme.secondaryColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeXXLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    'We sent a verification link to:',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: AppTheme.secondaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.email,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _InstructionRow(
                        text:
                            'Open your inbox and find the email from Derick247.',
                      ),
                      SizedBox(height: 12),
                      _InstructionRow(
                        text:
                            'Tap the verification button to activate your account.',
                      ),
                      SizedBox(height: 12),
                      _InstructionRow(
                        text:
                            'Come back here and log in once verification is complete.',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  _PrimaryButton(
                    label: 'Resend verification email',
                    icon: Icons.refresh,
                    loading: _resending,
                    onPressed: _resending ? null : _resendVerificationEmail,
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  _PrimaryButton(
                    label: 'Log out',
                    icon: Icons.logout,
                    outlined: true,
                    loading: _loggingOut,
                    onPressed: _loggingOut ? null : _handleLogout,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    "Didn't get the email yet? Check your spam folder or try again in a few minutes.",
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeSmall,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
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

class _InstructionRow extends StatelessWidget {
  final String text;

  const _InstructionRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 20,
          color: AppTheme.secondaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = outlined ? AppTheme.secondaryColor : Colors.white;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: loading
          ? SizedBox(
              key: ValueKey('loader'),
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spinnerColor,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: outlined
                        ? AppTheme.secondaryColor.withOpacity(0.12)
                        : Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: outlined ? AppTheme.secondaryColor : Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: outlined ? AppTheme.secondaryColor : Colors.white,
                  ),
                ),
              ],
            ),
    );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            side: BorderSide(
              color: AppTheme.secondaryColor.withOpacity(0.5),
              width: 1.4,
            ),
            foregroundColor: AppTheme.secondaryColor,
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          gradient: LinearGradient(
            colors: [
              AppTheme.secondaryColor,
              Color.lerp(AppTheme.secondaryColor, Colors.white, 0.2)!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
