import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/profile/add_web_dropshipping_product_screen.dart';
import '../services/translation_service.dart';
import 'vendor_share_popup.dart';

class PointOptionsBottomSheet extends StatelessWidget {
  const PointOptionsBottomSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return const PointOptionsBottomSheet();
      },
    );
  }

  void _handleOptionTap(BuildContext context, String option) {
    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Navigate based on option
    switch (option) {
      case 'vendor':
        // Show vendor share popup instead of navigating to create screen
        VendorSharePopup.show(context);
        break;
      case 'referrer':
        // Show referrer share popup instead of navigating to dashboard
        VendorSharePopup.show(context, type: 'referrer');
        break;
      case 'web_product':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AddWebDropshippingProductScreen(),
          ),
        );
        break;
      case 'regular_product':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const AddWebDropshippingProductScreen(isNormal: true),
          ),
        );
        break;
    }
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String option,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D), // Dark grey button background
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor ?? const Color(0xFFFFC107), // Yellow background
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: () => _handleOptionTap(context, option),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(
      context,
      listen: true,
    );
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85; // Max 85% of screen height
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F), // Dark bluish-grey background
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      translationService.translate('pointOptions.title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            ),

            // Options List
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Point a Vendor
                      _buildOptionTile(
                        context: context,
                        title: translationService.translate(
                          'pointOptions.pointAVendor.title',
                        ),
                        subtitle: translationService.translate(
                          'pointOptions.pointAVendor.subtitle',
                        ),
                        icon: Icons.store,
                        option: 'vendor',
                      ),

                      // Point a Referrer
                      _buildOptionTile(
                        context: context,
                        title: translationService.translate(
                          'pointOptions.pointAReferrer.title',
                        ),
                        subtitle: translationService.translate(
                          'pointOptions.pointAReferrer.subtitle',
                        ),
                        icon: Icons.person_add,
                        option: 'referrer',
                      ),

                      // Point A Web Product
                      _buildOptionTile(
                        context: context,
                        title: translationService.translate(
                          'pointOptions.pointAWebProduct.title',
                        ),
                        subtitle: translationService.translate(
                          'pointOptions.pointAWebProduct.subtitle',
                        ),
                        icon: Icons.link,
                        option: 'web_product',
                      ),

                      // Point A Regular Product
                      _buildOptionTile(
                        context: context,
                        title: translationService.translate(
                          'pointOptions.pointARegularProduct.title',
                        ),
                        subtitle: translationService.translate(
                          'pointOptions.pointARegularProduct.subtitle',
                        ),
                        icon: Icons.shopping_bag,
                        option: 'regular_product',
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
