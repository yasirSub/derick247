import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme_config.dart';
import '../models/product_model.dart';
import '../models/referral_info_model.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'referral_form_popup.dart';
import 'share_link_popup.dart';

class ReferralPopup extends StatefulWidget {
  final Product product;
  final VoidCallback? onClose;

  const ReferralPopup({Key? key, required this.product, this.onClose})
    : super(key: key);

  @override
  State<ReferralPopup> createState() => _ReferralPopupState();
}

class _ReferralPopupState extends State<ReferralPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  ReferralInfo? _referralInfo;
  bool _isLoading = false;
  String? _error;

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
    _loadReferralInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final response = await apiService.getReferralInfo(widget.product.id);

      if (response.statusCode == 200 && response.data['status'] == true) {
        setState(() {
          _referralInfo = ReferralInfo.fromJson(response.data['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load referral information';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading referral info: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                size: 40,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingLarge),

                            // Invite Friends Title
                            const Text(
                              'Invite Friends',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeXLarge,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingMedium),

                            // Reward Information
                            if (_referralInfo != null)
                              Text(
                                'Choose your preferred way to invite friends and earn rewards ${_referralInfo!.formattedEarnAmount}',
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeMedium,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),

                            const SizedBox(height: AppTheme.spacingLarge),

                            // Login Warning
                            if (!authProvider.isLoggedIn) ...[
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingMedium,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.warning,
                                          color: Colors.yellow,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingSmall,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Please log in to start earning ${_referralInfo?.formattedEarnAmount ?? '\$45'} per referral.',
                                            style: const TextStyle(
                                              fontSize: AppTheme.fontSizeSmall,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: AppTheme.spacingSmall,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // Navigate to login screen
                                        Navigator.of(context).pop();
                                        // You can add navigation to login screen here
                                      },
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: AppTheme.fontSizeMedium,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingLarge),
                            ],

                            // Loading State
                            if (_isLoading)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.yellow,
                                ),
                              )
                            else if (_error != null)
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingMedium,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: AppTheme.fontSizeSmall,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else if (_referralInfo != null) ...[
                              // Referral Options
                              Row(
                                children: [
                                  // Refer via Form Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        // Close current popup and show form popup
                                        Navigator.of(context).pop();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (BuildContext context) {
                                            return ReferralFormPopup(
                                              product: widget.product,
                                              onClose: () {
                                                Navigator.of(context).pop();
                                              },
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.yellow,
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMedium,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.person_add,
                                              color: Colors.black,
                                              size: 24,
                                            ),
                                            const SizedBox(
                                              height: AppTheme.spacingSmall,
                                            ),
                                            const Text(
                                              'Refer via Form',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.fontSizeMedium,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Fill out details and we\'ll contact them',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.fontSizeSmall,
                                                color: Colors.black.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMedium),
                                  // Share a Link Button
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        // Close current popup and show share popup
                                        Navigator.of(context).pop();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (BuildContext context) {
                                            return ShareLinkPopup(
                                              product: widget.product,
                                              referralInfo: _referralInfo!,
                                              onClose: () {
                                                Navigator.of(context).pop();
                                              },
                                            );
                                          },
                                        );
                                      },
                                      child: Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2C3E50),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMedium,
                                          ),
                                          border: Border.all(
                                            color: Colors.yellow,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.share,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            const SizedBox(
                                              height: AppTheme.spacingSmall,
                                            ),
                                            const Text(
                                              'Share a Link',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.fontSizeMedium,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Send your unique referral link',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.fontSizeSmall,
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
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
                            ],

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
