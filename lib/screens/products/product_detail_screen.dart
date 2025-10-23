import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/referral_popup.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final Product? product; // Optional pre-loaded product

  const ProductDetailScreen({Key? key, required this.productId, this.product})
    : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _isLoading = true;
  String? _error;
  int _selectedImageIndex = 0;
  int _currentTabIndex = 0;
  int _quantity = 1; // Add quantity selector
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  Future<void> _loadProductDetail() async {
    if (widget.product != null) {
      setState(() {
        _product = widget.product;
        _isLoading = false;
      });
      return;
    }

    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      await productProvider.loadProductDetail(widget.productId);

      if (mounted) {
        setState(() {
          _product = productProvider.selectedProduct;
          _isLoading = false;
          _error = productProvider.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showReferralPopup() {
    if (_product == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ReferralPopup(
          product: _product!,
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'Please log in to access referral features and earn commissions.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareViaFacebook() async {
    if (_product?.shareLink == null) return;

    final shareText =
        '''
Check out this amazing product: ${_product!.name}

🎁 Get it for ${_product!.formattedPrice}
${_product!.shareLink}
    ''';

    try {
      // Try to open Facebook directly
      final facebookUrl =
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_product!.shareLink!)}&quote=${Uri.encodeComponent(shareText)}';
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

  Future<void> _shareViaWhatsApp() async {
    if (_product?.shareLink == null) return;

    final shareText =
        '''
Check out this amazing product: ${_product!.name}

🎁 Get it for ${_product!.formattedPrice}
${_product!.shareLink}
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

  Future<void> _copyLinkToClipboard() async {
    if (_product?.shareLink == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _product!.shareLink!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addToCart() async {
    if (_product == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showLoginPrompt();
      return;
    }

    try {
      // Add to local cart first
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(_product!, quantity: _quantity);

      // Also add to backend cart via API
      try {
        await _apiService.addToCart(_product!.id, _quantity);
      } catch (apiError) {
        // If API fails, still keep it in local cart
        print('API cart sync failed: $apiError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${_quantity}x ${_product!.name} to cart'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'VIEW CART',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to cart screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  List<String> _getProductImages() {
    if (_product == null) return [];

    final images = <String>[];

    // Add media images first (these are the main product images from API)
    images.addAll(_product!.medias.values);

    // Add thumbnail if available and not already included
    if (_product!.thumbnail != null &&
        _product!.thumbnail!.isNotEmpty &&
        !images.contains(_product!.thumbnail)) {
      images.insert(0, _product!.thumbnail!);
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DERICK247',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.shopping_cart, color: AppTheme.primaryColor),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load product details',
                    style: TextStyle(fontSize: 18, color: AppTheme.errorColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProductDetail,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _product == null
          ? const Center(child: Text('Product not found'))
          : _buildProductContent(),
    );
  }

  Widget _buildProductContent() {
    final images = _getProductImages();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          _buildBreadcrumb(),

          // Product Images
          if (images.isNotEmpty) _buildImageSection(images),

          // Product Info
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  _product!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),

                // Price
                Text(
                  '${_product!.currencySymbol}${_product!.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Short Description
                if (_product!.shortDescription != null) ...[
                  Text(
                    _product!.shortDescription!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 20),

                // Share Section
                _buildShareSection(),
                const SizedBox(height: 20),

                // Delivery Information
                _buildDeliverySection(),
                const SizedBox(height: 20),

                // Tabs
                _buildTabs(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Home / ${_product!.categoryName ?? 'Products'} / ${_product!.name}',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
      ),
    );
  }

  Widget _buildImageSection(List<String> images) {
    return Container(
      height: 300,
      child: Column(
        children: [
          // Main Image
          Expanded(
            child: PageView.builder(
              onPageChanged: (index) {
                setState(() {
                  _selectedImageIndex = index;
                });
              },
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  width: double.infinity,
                  child: Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Image Thumbnails
          if (images.length > 1)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedImageIndex == index
                            ? AppTheme.secondaryColor
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Quantity Selector
        Row(
          children: [
            const Text(
              'Quantity:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _quantity.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quantity++;
                      });
                    },
                    icon: const Icon(Icons.add, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          children: [
            // Add to Cart Button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                label: const Text(
                  'ADD TO CART',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Refer & Earn Button
            Expanded(
              flex: 2,
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return OutlinedButton.icon(
                    onPressed: authProvider.isLoggedIn
                        ? _showReferralPopup
                        : _showLoginPrompt,
                    icon: Icon(Icons.favorite, color: AppTheme.secondaryColor),
                    label: Text(
                      'REFER & EARN ${_product!.currencySymbol}${_product!.referrerCommission?.toStringAsFixed(0) ?? '0'}',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.secondaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHARE THIS PRODUCT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Facebook
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareViaFacebook,
                icon: const Icon(Icons.facebook, color: Colors.white),
                label: const Text(
                  'Facebook',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // WhatsApp
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareViaWhatsApp,
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  'WhatsApp',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Copy Link
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyLinkToClipboard,
                icon: const Icon(Icons.link, color: Colors.grey),
                label: const Text(
                  'Copy Link',
                  style: TextStyle(color: Colors.grey),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'DELIVERY INFORMATION',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_product!.shippingAvailable.isNotEmpty)
          ...(_product!.shippingAvailable.map(
            (shipping) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(shipping.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shipping.countryName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${shipping.shippingTime} ${shipping.timeType}',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ))
        else
          const Text(
            'Delivery information not available',
            style: TextStyle(color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildTabs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _currentTabIndex == 0
                            ? AppTheme.secondaryColor
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'FULL DETAILS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentTabIndex == 0
                          ? AppTheme.secondaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _currentTabIndex == 1
                            ? AppTheme.secondaryColor
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'SHIPPING POLICY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentTabIndex == 1
                          ? AppTheme.secondaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tab Content
        if (_currentTabIndex == 0) _buildFullDetailsTab(),
        if (_currentTabIndex == 1) _buildShippingPolicyTab(),
      ],
    );
  }

  Widget _buildFullDetailsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRODUCT DESCRIPTION',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _product!.description ??
              _product!.shortDescription ??
              'No description available',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // Additional Details
        if (_product!.minBuyingQty > 1) ...[
          const Text(
            'MINIMUM QUANTITY',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum buying quantity: ${_product!.minBuyingQty}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ],
    );
  }

  Widget _buildShippingPolicyTab() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHIPPING POLICY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'We offer shipping to multiple countries. Please check the delivery information above for specific shipping times to your location.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
      ],
    );
  }
}
