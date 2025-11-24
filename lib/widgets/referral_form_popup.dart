import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../providers/auth_provider.dart';
import '../utils/referral_access_helper.dart';
import 'translated_text.dart';

class ReferralFormPopup extends StatefulWidget {
  final Product product;
  final VoidCallback? onClose;
  final bool isFromCart;

  const ReferralFormPopup({
    Key? key,
    required this.product,
    this.onClose,
    this.isFromCart = false,
  }) : super(key: key);

  @override
  State<ReferralFormPopup> createState() => _ReferralFormPopupState();
}

class _ReferralFormPopupState extends State<ReferralFormPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final _friendNameController = TextEditingController();
  final _friendPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _friendStatus = '';
  bool _isSubmitting = false;

  final List<String> _statusOptions = [
    'not_ready',
    'need_significant_work',
    'almost_ready',
    'ready',
  ];

  final Map<String, String> _statusLabels = {
    'not_ready': 'Not Ready',
    'need_significant_work': 'Need Significant Work',
    'almost_ready': 'Almost Ready',
    'ready': 'Ready',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    
    // Check permission when form opens (safety check)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn && 
          ReferralAccessHelper.blockIfNoPermission(
            context: context,
            authProvider: authProvider,
          )) {
        // Close the form if blocked
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && widget.onClose != null) {
            widget.onClose!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _friendNameController.dispose();
    _friendPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_friendStatus.isEmpty) {
      final translationService = TranslationService();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translationService.translate('refer.selectFriendStatus'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final apiService = ApiService();
      final formData = {
        'friend_name': _friendNameController.text.trim(),
        'friend_phone': _friendPhoneController.text.trim(),
        'friend_status': _friendStatus,
        'notes': _notesController.text.trim(),
        'productId': widget.product.id.toString(),
      };

      final response = widget.isFromCart
          ? await apiService.referFriendFromCart(formData)
          : await apiService.referFriend(formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data['message'] ?? 'Referral sent successfully!',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        widget.onClose?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data['message'] ?? 'Failed to send referral',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending referral: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOut,
                ),
              ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50), // Dark blue-grey background
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
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
                    padding: EdgeInsets.only(
                      left: AppTheme.spacingLarge,
                      right: AppTheme.spacingLarge,
                      top: AppTheme.spacingLarge,
                      bottom:
                          MediaQuery.of(context).padding.bottom +
                          AppTheme.spacingLarge,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with point reward
                          Row(
                            children: [
                              const Text(
                                'Refer by Form By Spending',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingSmall),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingSmall,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.diamond,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '1 Point',
                                      style: TextStyle(
                                        fontSize: AppTheme.fontSizeSmall,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppTheme.spacingMedium),

                          // Instructions
                          const TranslatedText(
                            'refer.completeStep',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMedium,
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingLarge),

                          // Friend's Name Field
                          const TranslatedText(
                            'refer.friendsName',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMedium,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSmall),
                          TextFormField(
                            controller: _friendNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., Jane Doe',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMedium,
                                vertical: AppTheme.spacingSmall,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                final translationService = TranslationService();
                                return translationService.translate(
                                  'refer.friendNameRequired',
                                );
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppTheme.spacingLarge),

                          // Friend's Phone Field
                          const TranslatedText(
                            'refer.friendsPhone',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMedium,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSmall),
                          TextFormField(
                            controller: _friendPhoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., +8801XXXXXXXXX',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMedium,
                                vertical: AppTheme.spacingSmall,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                final translationService = TranslationService();
                                return translationService.translate(
                                  'refer.friendPhoneRequired',
                                );
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppTheme.spacingLarge),

                          // How Ready Are You? Dropdown
                          const TranslatedText(
                            'refer.howReady',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMedium,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSmall),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMedium,
                              vertical: AppTheme.spacingSmall,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _friendStatus.isEmpty
                                    ? null
                                    : _friendStatus,
                                hint: const TranslatedText(
                                  'refer.selectOne',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                style: const TextStyle(color: Colors.white),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                ),
                                dropdownColor: Colors.grey[800],
                                items: _statusOptions.map((String status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(
                                      _statusLabels[status] ?? status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _friendStatus = newValue ?? '';
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingLarge),

                          // Notes Field
                          const TranslatedText(
                            'refer.notes',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMedium,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSmall),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add any extra details',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(
                                AppTheme.spacingMedium,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingLarge),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.yellow,
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
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const TranslatedText(
                                          'refer.sendInvitation',
                                          style: TextStyle(
                                            fontSize: AppTheme.fontSizeMedium,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMedium),
                              Expanded(
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
                        ],
                      ),
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
