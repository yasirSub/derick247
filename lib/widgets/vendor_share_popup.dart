import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme_config.dart';
import '../services/api_service.dart';

class VendorSharePopup extends StatefulWidget {
  final String type; // 'vendor' or 'referrer'

  const VendorSharePopup({Key? key, required this.type}) : super(key: key);

  static void show(BuildContext context, {String type = 'vendor'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return VendorSharePopup(type: type);
      },
    );
  }

  @override
  State<VendorSharePopup> createState() => _VendorSharePopupState();
}

class _VendorSharePopupState extends State<VendorSharePopup> {
  String? _shareLink;
  bool _isLoading = true;
  String? _error;
  bool _linkCopied = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPointerLink();
  }

  Future<void> _loadPointerLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getPointerLink();
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          // Get the appropriate link based on type
          if (widget.type == 'referrer') {
            _shareLink = data['point_a_referer'] as String?;
          } else {
            _shareLink = data['point_a_vendor'] as String?;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              response.data['message']?.toString() ?? 'Failed to load link';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading link: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String get _shareText {
    if (widget.type == 'referrer') {
      return 'Join and start earning! Register here: $_shareLink';
    } else {
      return 'Join as a vendor and start earning! Register here: $_shareLink';
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_shareLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link not available'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final shareText = _shareText;

    try {
      // Try multiple WhatsApp URL schemes
      // First try the direct WhatsApp scheme
      final whatsappUrl =
          'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback to wa.me URL (works on web and opens app on mobile)
      final waMeUrl = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';
      final waMeUri = Uri.parse(waMeUrl);

      if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Final fallback to general share
      await Share.share(shareText);
    } catch (e) {
      // Fallback to general share
      await Share.share(shareText);
    }
  }

  Future<void> _shareViaFacebook() async {
    if (_shareLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link not available'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final shareText = _shareText;

    try {
      // Try to open Facebook app first (iOS: fb://, Android: fb:// or intent)
      // iOS Facebook app scheme
      final fbAppUrl =
          'fb://share?href=${Uri.encodeComponent(_shareLink!)}&quote=${Uri.encodeComponent(shareText)}';
      final fbAppUri = Uri.parse(fbAppUrl);

      if (await canLaunchUrl(fbAppUri)) {
        await launchUrl(fbAppUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback to Facebook web share (will open app on mobile if available)
      final facebookUrl =
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareLink!)}&quote=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(facebookUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Final fallback to general share
        await Share.share(shareText);
      }
    } catch (e) {
      // Fallback to general share
      await Share.share(shareText);
    }
  }

  Future<void> _copyLink() async {
    if (_shareLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link not available'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _shareLink!));
      if (mounted) {
        setState(() {
          _linkCopied = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _linkCopied = false;
            });
          }
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy link'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildShareButton({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
    double? iconSize,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: iconSize ?? 52),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: iconColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F), // Dark bluish-grey background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: bottomPadding + 100.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.type == 'referrer'
                        ? 'Share Referrer Link'
                        : 'Share Vendor Link',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPointerLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                // Share buttons row
                Row(
                  children: [
                    // WhatsApp Button
                    _buildShareButton(
                      title: 'WhatsApp',
                      subtitle: 'Share via WhatsApp',
                      backgroundColor: const Color(
                        0xFF25D366,
                      ), // WhatsApp green
                      iconColor: Colors.white,
                      icon: Icons.message,
                      onTap: _shareViaWhatsApp,
                      iconSize: 56,
                    ),

                    // Facebook Button
                    _buildShareButton(
                      title: 'Facebook',
                      subtitle: 'Share on Facebook',
                      backgroundColor: const Color(0xFF1877F2), // Facebook blue
                      iconColor: Colors.white,
                      icon: Icons.facebook,
                      onTap: _shareViaFacebook,
                      iconSize: 56,
                    ),

                    // Copy Link Button
                    _buildShareButton(
                      title: 'Copy Link',
                      subtitle: 'Copy referral link',
                      backgroundColor: const Color(0xFF2D2D2D), // Dark grey
                      iconColor: Colors.white,
                      icon: _linkCopied
                          ? Icons.check_circle
                          : Icons.content_copy,
                      onTap: _copyLink,
                      iconSize:
                          60, // Slightly larger to compensate for visual weight
                    ),
                  ],
                ),

              SizedBox(height: 40 + bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}
