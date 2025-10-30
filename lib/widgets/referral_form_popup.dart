import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme_config.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class ReferralFormPopup extends StatefulWidget {
  final Product product;
  final VoidCallback? onClose;

  const ReferralFormPopup({Key? key, required this.product, this.onClose})
    : super(key: key);

  @override
  State<ReferralFormPopup> createState() => _ReferralFormPopupState();
}

class _ReferralFormPopupState extends State<ReferralFormPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
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
    _friendNameController.dispose();
    _friendPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_friendStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select friend status'),
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

      final response = await apiService.referFriend(formData);

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
                              const Text(
                                'Complete the step below to invite your friend',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeMedium,
                                  color: Colors.white70,
                                ),
                              ),

                              const SizedBox(height: AppTheme.spacingLarge),

                              // Friend's Name Field
                              const Text(
                                'Friend\'s Name',
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
                                    return 'Please enter friend\'s name';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: AppTheme.spacingLarge),

                              // Friend's Phone Field
                              const Text(
                                'Friend\'s Phone',
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
                                    return 'Please enter friend\'s phone';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: AppTheme.spacingLarge),

                              // How Ready Are You? Dropdown
                              const Text(
                                'How Ready Are You?',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSizeMedium,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black, // Changed from Colors.white
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
                                    hint: const Text(
                                      'Select One',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white70,
                                    ),
                                    items: _statusOptions.map((String status) {
                                      return DropdownMenuItem<String>(
                                        value: status,
                                        child: Text(
                                          _statusLabels[status] ?? status,
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
                              const Text(
                                'Notes',
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
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitForm,
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
                                          : const Text(
                                              'Send Invitation',
                                              style: TextStyle(
                                                fontSize:
                                                    AppTheme.fontSizeMedium,
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
        ),
      ),
    );
  }
}
