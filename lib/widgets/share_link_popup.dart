import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme_config.dart';
import '../models/product_model.dart';
import '../models/referral_info_model.dart';

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
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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

  Future<void> _shareViaWhatsApp() async {
    final shareText =
        '''
Check out this amazing product: ${widget.product.name}

🎁 Get it for ${widget.product.formattedPrice}
💰 Earn ${widget.referralInfo.formattedEarnAmount} commission when someone buys through your link!

${widget.referralInfo.shareLink}
    ''';

    try {
      // Try to open WhatsApp directly
      final whatsappUrl =
          'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to general share if WhatsApp is not installed
        await Share.share(shareText);
      }
    } catch (e) {
      // Fallback to general share
      await Share.share(shareText);
    }
  }

  Future<void> _shareViaFacebook() async {
    final shareText =
        '''
Check out this amazing product: ${widget.product.name}

🎁 Get it for ${widget.product.formattedPrice}
💰 Earn ${widget.referralInfo.formattedEarnAmount} commission when someone buys through your link!

${widget.referralInfo.shareLink}
    ''';

    try {
      // Try to open Facebook directly
      final facebookUrl =
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(widget.referralInfo.shareLink)}&quote=${Uri.encodeComponent(shareText)}';
      final uri = Uri.parse(facebookUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to general share if Facebook app is not available
        await Share.share(shareText);
      }
    } catch (e) {
      // Fallback to general share
      await Share.share(shareText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(AppTheme.spacingLarge),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50), // Dark blue-grey background
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                              child: Text(
                                'Refer and Earn',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeXLarge,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
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
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                size: 40,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingLarge),

                            // Title
                            const Text(
                              'Share Your Link',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeXLarge,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingMedium),

                            // Instructions
                            const Text(
                              'Complete the step below to invite your friend',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeMedium,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: AppTheme.spacingLarge),

                            // Sharing Options
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
                                          const Text(
                                            'Share via WhatsApp',
                                            style: TextStyle(
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
                                          const Text(
                                            'Share on Facebook',
                                            style: TextStyle(
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
        ),
      ),
    );
  }
}
