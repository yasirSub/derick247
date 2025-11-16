import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../models/product_model.dart';
import '../models/referral_info_model.dart';
import '../providers/auth_provider.dart';
import '../services/translation_service.dart';
import '../utils/share_utils.dart';
import 'translated_text.dart';
import '../screens/auth/login_screen.dart';

class ShareLinkPopup extends StatefulWidget {
  final Product product;
  final ReferralInfo referralInfo;
  final VoidCallback? onClose;

  const ShareLinkPopup({
    Key? key,
    required this.product,
    required this.referralInfo,
    this.onClose,
  }) : super(key: key);

  @override
  State<ShareLinkPopup> createState() => _ShareLinkPopupState();
}

class _ShareLinkPopupState extends State<ShareLinkPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isProductLink = true; // true for product link, false for checkout link
  bool _linkCopied = false;
  bool _checkoutRequiresLogin = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _productLink {
    final link = widget.referralInfo.shareLink;
    final code = widget.referralInfo.referralCode;
    if (code != null && code.isNotEmpty && !link.contains('ref=')) {
      final separator = link.contains('?') ? '&' : '?';
      return '$link${separator}ref=$code';
    }
    return link;
  }

  String get _checkoutLink {
    final checkout = widget.referralInfo.checkoutLink;
    if (checkout != null && checkout.isNotEmpty) {
      return checkout;
    }
    // Fallback: append referral code to checkout path
    final code = widget.referralInfo.referralCode;
    if (code != null && code.isNotEmpty) {
      return 'https://comisionista247.com/checkout-guest/$code';
    }
    return 'https://comisionista247.com/checkout-guest';
  }

  String get _currentLink {
    return _isProductLink ? _productLink : _checkoutLink;
  }

  Future<void> _shareViaWhatsApp() async {
    // Share only the link without product name
    final shareText = _currentLink;

    try {
      // Try to open WhatsApp directly
      final whatsappUrl =
          'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to general share if WhatsApp is not installed
        await ShareUtils.shareLinkWithImage(
          link: shareText,
          productImageUrl: widget.product.firstImage,
          context: context,
        );
      }
    } catch (e) {
      // Fallback to general share
      await ShareUtils.shareLinkWithImage(
        link: shareText,
        productImageUrl: widget.product.firstImage,
        context: context,
      );
    }
  }

  Future<void> _shareViaFacebook() async {
    // Share only the link without product name
    final shareText = _currentLink;

    try {
      // Try to open Facebook directly
      final facebookUrl =
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_currentLink)}&quote=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(facebookUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to general share if Facebook app is not available
        await ShareUtils.shareLinkWithImage(
          link: shareText,
          productImageUrl: widget.product.firstImage,
          context: context,
        );
      }
    } catch (e) {
      // Fallback to general share
      await ShareUtils.shareLinkWithImage(
        link: shareText,
        productImageUrl: widget.product.firstImage,
        context: context,
      );
    }
  }

  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: _currentLink));
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
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _linkCopied = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy link'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(
                  0xFF2C3E50,
                ), // Dark blue-grey background (preferred)
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusLarge),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: TranslatedText(
                            'refer.referAndEarn',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeXLarge,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLarge),
                    child: Column(
                      children: [
                        // Gift Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.yellow,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.card_giftcard,
                            size: 40,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        // Title
                        const TranslatedText(
                          'refer.shareYourLink',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeXLarge,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacingMedium),

                        // Instructions
                        const TranslatedText(
                          'refer.completeStep',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeMedium,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        // Tab Buttons
                        Row(
                          children: [
                            // Share Product Link Tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isProductLink = true;
                                    _linkCopied = false;
                                    _checkoutRequiresLogin = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingMedium,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isProductLink
                                        ? Colors.yellow
                                        : const Color(0xFF2D323E),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                  ),
                                  child: Text(
                                    TranslationService().translate('refer.shareProductLink'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSizeMedium,
                                      fontWeight: FontWeight.bold,
                                      color: _isProductLink
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingMedium),
                            // Share Checkout Link Tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  final isLoggedIn = Provider.of<AuthProvider>(
                                    context,
                                    listen: false,
                                  ).isLoggedIn;
                                  setState(() {
                                    _isProductLink = false;
                                    _linkCopied = false;
                                    _checkoutRequiresLogin = !isLoggedIn;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingMedium,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isProductLink
                                        ? Colors.yellow
                                        : const Color(0xFF2D323E),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                  ),
                                  child: Text(
                                    TranslationService().translate('refer.shareCheckoutLink'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSizeMedium,
                                      fontWeight: FontWeight.bold,
                                      color: !_isProductLink
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        if (_checkoutRequiresLogin && !_isProductLink)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D323E),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFFFFC107,
                                    ).withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFFFFC107),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingLarge),
                                const TranslatedText(
                                  'auth.loginRequired',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeLarge,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSmall),
                                const TranslatedText(
                                  'auth.loginRequiredShare',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeSmall,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingLarge),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onClose?.call();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC107),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.spacingMedium,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium,
                                        ),
                                      ),
                                    ),
                                    child: const TranslatedText(
                                      'auth.loginNow',
                                      style: TextStyle(
                                        fontSize: AppTheme.fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              // WhatsApp Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _shareViaWhatsApp,
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF25D366,
                                      ), // WhatsApp green
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingSmall,
                                        ),
                                        const Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            fontSize: AppTheme.fontSizeMedium,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          TranslationService().translate('refer.shareViaWhatsApp'),
                                          style: const TextStyle(
                                            fontSize: AppTheme.fontSizeSmall,
                                            color: Colors.white70,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMedium),
                              // Facebook Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _shareViaFacebook,
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1877F2,
                                      ), // Facebook blue
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'f',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'Arial',
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingSmall,
                                        ),
                                        const Text(
                                          'Facebook',
                                          style: TextStyle(
                                            fontSize: AppTheme.fontSizeMedium,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          TranslationService().translate('refer.shareOnFacebook'),
                                          style: const TextStyle(
                                            fontSize: AppTheme.fontSizeSmall,
                                            color: Colors.white70,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMedium),
                              // Copy Link Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _copyLink,
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: _linkCopied
                                          ? const Color(
                                              0xFF25D366,
                                            ) // Green highlight
                                          : const Color(
                                              0xFF2D323E,
                                            ), // Dark grey
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _linkCopied
                                              ? Icons.check
                                              : Icons.copy,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingSmall,
                                        ),
                                        Text(
                                          _linkCopied 
                                              ? TranslationService().translate('refer.copied')
                                              : TranslationService().translate('refer.copyLink'),
                                          style: const TextStyle(
                                            fontSize: AppTheme.fontSizeMedium,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _linkCopied
                                              ? TranslationService().translate('refer.linkCopiedSuccessfully')
                                              : TranslationService().translate('refer.copyReferralLink'),
                                          style: const TextStyle(
                                            fontSize: AppTheme.fontSizeSmall,
                                            color: Colors.white70,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.onClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingMedium,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeMedium,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
