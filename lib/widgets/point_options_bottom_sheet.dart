import 'package:flutter/material.dart';
import '../screens/profile/add_web_dropshipping_product_screen.dart';
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

  void _handleOptionTap(
    BuildContext context,
    String option,
  ) {
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
          child: Icon(
            icon,
            color: Colors.black,
            size: 24,
          ),
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
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white,
        ),
        onTap: () => _handleOptionTap(context, option),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F), // Dark bluish-grey background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point Options',
                    style: TextStyle(
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
            ),

            // Options List
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Point a Vendor
                  _buildOptionTile(
                    context: context,
                    title: 'Point a Vendor',
                    subtitle: 'Create and manage vendor products',
                    icon: Icons.store,
                    option: 'vendor',
                  ),

                  // Point a Referrer
                  _buildOptionTile(
                    context: context,
                    title: 'Point a Referrer',
                    subtitle: 'Refer friends and earn rewards',
                    icon: Icons.person_add,
                    option: 'referrer',
                  ),

                  // Point A Web Product
                  _buildOptionTile(
                    context: context,
                    title: 'Point A Web Product',
                    subtitle: 'Add web product with link',
                    icon: Icons.link,
                    option: 'web_product',
                  ),

                  // Point A Regular Product
                  _buildOptionTile(
                    context: context,
                    title: 'Point A Regular Product',
                    subtitle: 'Add normal product (dropshipping)',
                    icon: Icons.shopping_bag,
                    option: 'regular_product',
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

