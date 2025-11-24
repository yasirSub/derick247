import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../config/theme_config.dart';
import '../utils/deep_link_utils.dart';
import '../utils/share_utils.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../screens/auth/login_screen.dart';
import '../services/translation_service.dart';
import 'translated_text.dart';

String _formatPriceWithSpace(String value) {
  if (value.isEmpty) return value;
  // If starts with any non-digit run directly followed by digit, insert a space
  final mGeneric = RegExp(r'^(\D+)(\d)').firstMatch(value);
  if (mGeneric != null) {
    final prefix = mGeneric.group(1)!;
    if (!prefix.endsWith(' ')) {
      return value.replaceFirst(prefix, '$prefix ');
    }
    return value;
  }
  return value;
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRefer;
  final VoidCallback? onAddToCart;
  final bool showEarnButton;
  final bool priceAsPill;

  const ProductCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onShare,
    this.onRefer,
    this.onAddToCart,
    this.showEarnButton = true,
    this.priceAsPill = false,
  }) : super(key: key);

  Future<void> _addToCart(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showLoginPrompt(context);
      return;
    }

    // Check if user is verified
    if (!authProvider.isEmailVerified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are not verified. Please verify your email to add items to cart.'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      // Add to local cart first
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(product, quantity: 1);

      // Also add to backend cart via API
      try {
        final apiService = ApiService();
        await apiService.addToCart(product.id, 1);
      } catch (apiError) {
        // If API fails, still keep it in local cart
        print('API cart sync failed: $apiError');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate(
                'cart.added',
                params: {'name': product.name},
              ),
            ),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: TranslationService().translate('cart.viewCart'),
              textColor: Colors.white,
              onPressed: () {
                // Navigate to cart screen
                // This would need to be handled by the parent widget
                if (onAddToCart != null) {
                  onAddToCart!();
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate(
                'cart.failedToAdd',
                params: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _shareProduct(BuildContext context) async {
    // Generate product link
    final productLink = DeepLinkUtils.generateProductLink(
      productId: product.slug.isEmpty ? product.id : null,
      productSlug: product.slug.isNotEmpty ? product.slug : null,
      productName: product.name,
    );

    // Generate share text with product title (link will be hidden when sharing with image)
    final shareText = DeepLinkUtils.generateProductShareText(
      productName: product.name,
      price: product.formattedPrice,
      productId: product.slug.isEmpty ? product.id : null,
      productSlug: product.slug.isNotEmpty ? product.slug : null,
      description: product.shortDescription,
      hideLink: true, // Hide link when sharing with image
    );

    // Get product image URL if available
    final productImageUrl = product.firstImage;

    await ShareUtils.shareLinkWithImage(
      link: productLink,
      shareText: shareText, // Product title only (link hidden)
      subject: product.name, // Use product name as subject
      productImageUrl: productImageUrl,
      context: context,
    );

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product link shared!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLoginPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const TranslatedText(
                'auth.loginRequired',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const TranslatedText(
                'auth.loginRequiredAddToCart',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const TranslatedText('app.cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const TranslatedText('app.login'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCommission =
        product.referrerCommission != null && product.referrerCommission! > 0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall,
            vertical: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[100],
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      product.firstImage != null
                          ? CachedNetworkImage(
                              imageUrl: product.firstImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                      // Flag overlay
                      if (product.flag != null && product.flag!.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              product.flag!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      // Shopping cart icon overlay (bottom-right)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _addToCart(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Price - plain orange text (first)
                    Text(
                      _formatPriceWithSpace(product.formattedPrice),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Refer & Earn text
                    if (hasCommission && showEarnButton) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Refer & Earn ${product.formattedCommission}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // White button with "Refer & Earn"
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onRefer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: Colors.grey.shade600,
                                width: 1,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Refer & Earn',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRefer;
  final VoidCallback? onAddToCart;
  final bool showEarnButton;

  const ProductGridCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onShare,
    this.onRefer,
    this.onAddToCart,
    this.showEarnButton = true,
  }) : super(key: key);

  Future<void> _addToCart(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showLoginPrompt(context);
      return;
    }

    // Check if user is verified
    if (!authProvider.isEmailVerified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are not verified. Please verify your email to add items to cart.'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      // Add to local cart first
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(product, quantity: 1);

      // Also add to backend cart via API
      try {
        final apiService = ApiService();
        await apiService.addToCart(product.id, 1);
      } catch (apiError) {
        // If API fails, still keep it in local cart
        print('API cart sync failed: $apiError');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService().translate(
                'cart.added',
                params: {'name': product.name},
              ),
            ),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: TranslationService().translate('cart.viewCart'),
              textColor: Colors.white,
              onPressed: () {
                // Navigate to cart screen
                // This would need to be handled by the parent widget
                if (onAddToCart != null) {
                  onAddToCart!();
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${TranslationService().translate('app.error')}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showLoginPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const TranslatedText(
                'auth.loginRequired',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const TranslatedText(
                'auth.loginRequiredAddToCart',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const TranslatedText('app.cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const TranslatedText('app.login'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCommission =
        product.referrerCommission != null && product.referrerCommission! > 0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 5,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: Theme.of(context).primaryColorLight.withOpacity(0.18),
        highlightColor: Colors.orange.withOpacity(0.06),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // IMAGE + overlay
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: product.firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: product.firstImage!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 28,
                                ),
                              ),
                      ),
                      // Flag overlay (top-left)
                      if (product.flag != null && product.flag!.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              product.flag!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      // Fade for overlay icon
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 55,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black26,
                                  Colors.black12.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _addToCart(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Price - plain orange text
                          Text(
                            _formatPriceWithSpace(product.formattedPrice),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Product name
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Refer & Earn text
                          if (hasCommission && showEarnButton) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Refer & Earn ${product.formattedCommission}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // White button with "Refer & Earn"
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: onRefer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  minimumSize: const Size(0, 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: BorderSide(
                                      color: Colors.grey.shade600,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Refer & Earn',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
