import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../auth/login_screen.dart';
import '../products/product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Print auth token info immediately when cart screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('\n🚀 CART SCREEN LOADED - AUTH TOKEN INFO:');
      print('=' * 60);
      authProvider.printAuthTokenInfo();
      print('=' * 60);
    });

    _loadCartFromAPI();
  }

  Future<void> _loadCartFromAPI() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Debug: Print detailed auth token information
    print('=' * 50);
    print('🔑 AUTH TOKEN DEBUG INFO');
    print('=' * 50);
    authProvider.printAuthTokenInfo();
    print('=' * 50);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCart();

      if (response.statusCode == 200) {
        final cartData = response.data;

        // Debug: Print cart API response
        print('🛒 CART API RESPONSE:');
        print('Success: ${cartData['success']}');
        print(
          'Cart Items Count: ${(cartData['cart_items'] as List?)?.length ?? 0}',
        );
        print('Cart Items: ${cartData['cart_items']}');

        // Parse cart data and update CartProvider
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        // Clear existing cart items
        await cartProvider.clearCart();

        // Add items from API response
        if (cartData['cart_items'] != null) {
          final items = cartData['cart_items'] as List;
          print('🛒 Processing ${items.length} cart items...');

          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            print(
              '📦 Processing item ${i + 1}: ${item['product_name']} (Product ID: ${item['product_id']}, Cart Item ID: ${item['id']})',
            );

            // Create a Product object from cart item data
            final productData = {
              'id': item['product_id'],
              'name': item['product_name'],
              'slug':
                  'product-${item['product_id']}', // Add required slug field
              'price': item['price'],
              'currency_symbol': '\$', // Default currency
              'thumbnail': item['thumbnail'], // Use thumbnail from API
              'medias': {},
              'min_buying_qty': 1,
              'shipping_available': [],
            };

            print('🔧 Product data: $productData');

            // Add to cart provider with cart item ID
            await cartProvider.addToCartWithId(
              Product.fromJson(productData),
              quantity: item['quantity'],
              cartItemId: item['id'], // Store the cart item ID from API
            );

            print(
              '✅ Added to cart: ${item['product_name']} (Qty: ${item['quantity']})',
            );
            print(
              '🛒 Current cart items count: ${cartProvider.cartItems.length}',
            );
          }
        }

        print('🛒 Cart Provider Items Count: ${cartProvider.cartItems.length}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCartItemQuantity(
    CartItem cartItem,
    int newQuantity,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    try {
      print(
        '🔄 Updating cart item: ${cartItem.product.name} (Product ID: ${cartItem.product.id}, New Qty: $newQuantity)',
      );

      // Update local state first for instant UI feedback
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      if (newQuantity <= 0) {
        // Remove item
        print('🗑️ Removing item from cart');
        // Update local state first
        await cartProvider.removeFromCart(cartItem.product);

        // Then sync with API in background
        if (cartItem.cartItemId != null) {
          print('🌐 Removing from API with cartItemId: ${cartItem.cartItemId}');
          _apiService.removeFromCart(cartItem.cartItemId!).catchError((error) {
            print('Error syncing with API: $error');
            // Silently handle error
            return null as dynamic;
          });
        } else {
          print('📱 Removing local-only item (no cartItemId)');
        }
      } else {
        // Update quantity
        print(
          '📝 Updating quantity to $newQuantity (CartItemId: ${cartItem.cartItemId})',
        );
        // Update local state first
        await cartProvider.updateQuantity(cartItem.product, newQuantity);

        // Then sync with API in background
        if (cartItem.cartItemId != null) {
          print('🌐 Updating API with cartItemId: ${cartItem.cartItemId}');
          _apiService
              .updateCartItem(cartItem.cartItemId!, newQuantity)
              .catchError((error) {
                print('Error syncing with API: $error');
                // Silently handle error
                return null as dynamic;
              });
        } else {
          print('📱 Updating local-only item (no cartItemId)');
        }
      }

      // No full reload - just update local state and sync in background
    } catch (e) {
      print('Error updating cart item quantity: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cart: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(CartItem cartItem) async {
    final result = await showModalBottomSheet<bool>(
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
              const Text(
                'Remove Item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to remove "${cartItem.product.name}" from your cart?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Remove'),
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

    if (result == true) {
      await _removeCartItem(cartItem);
    }
  }

  Future<void> _removeCartItem(CartItem cartItem) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    try {
      print(
        '🗑️ Removing cart item: ${cartItem.product.name} (CartItemId: ${cartItem.cartItemId})',
      );

      // Remove from API only if cartItemId exists (item was synced with API)
      if (cartItem.cartItemId != null) {
        print('🌐 Removing from API with cartItemId: ${cartItem.cartItemId}');
        await _apiService.removeFromCart(cartItem.cartItemId!);
      } else {
        print('📱 Removing local-only item (no cartItemId)');
      }

      // Remove from local cart
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.removeFromCart(cartItem.product);

      // Reload cart from API to ensure consistency (only if user is logged in)
      if (authProvider.isLoggedIn) {
        await _loadCartFromAPI();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cartItem.product.name} removed from cart'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error removing cart item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove item: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showClearAllConfirmation() async {
    final result = await showModalBottomSheet<bool>(
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
              const Text(
                'Clear All Items',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to remove all items from your cart?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clear All'),
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

    if (result == true) {
      await _clearAllCartItems();
    }
  }

  Future<void> _clearAllCartItems() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    try {
      print('🗑️ Clearing all cart items');

      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Remove each item from API (only items with cartItemId)
      for (final cartItem in cartProvider.cartItems) {
        if (cartItem.cartItemId != null) {
          print('🌐 Removing from API with cartItemId: ${cartItem.cartItemId}');
          await _apiService.removeFromCart(cartItem.cartItemId!);
        } else {
          print('📱 Skipping local-only item (no cartItemId)');
        }
      }

      // Clear local cart
      await cartProvider.clearCart();

      // Reload cart from API to ensure consistency
      await _loadCartFromAPI();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All items removed from cart'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error clearing all cart items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cart: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isLoggedIn) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Shopping Cart'),
            backgroundColor: AppTheme.darkAppBarColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                Text(
                  'Please log in to view your cart',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: CustomAppBar(
          title: 'Shopping Cart',
          isDark: true,
          actions: [
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                if (cartProvider.isEmpty) return const SizedBox.shrink();

                return IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.white),
                  onPressed: () {
                    _showClearAllConfirmation();
                  },
                  tooltip: 'Clear all items',
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  if (cartProvider.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _loadCartFromAPI,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildEmptyCart(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Cart Items List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadCartFromAPI,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(
                              AppTheme.spacingMedium,
                            ),
                            itemCount: cartProvider.cartItems.length,
                            itemBuilder: (context, index) {
                              final cartItem = cartProvider.cartItems[index];
                              return _buildCartItem(cartItem);
                            },
                          ),
                        ),
                      ),

                      // Cart Summary
                      _buildCartSummary(cartProvider),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Failed to load cart',
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
            onPressed: _loadCartFromAPI,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Add some products to get started',
            style: TextStyle(
              fontSize: AppTheme.fontSizeMedium,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem cartItem) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: cartItem.product.id),
          ),
        );
      },
      child: AppTheme.buildCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              color: Colors.grey[200],
            ),
            child: cartItem.product.firstImage != null
                ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    child: Image.network(
                      cartItem.product.firstImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: AppTheme.spacingMedium),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.product.name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                Text(
                  cartItem.formattedTotal,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Quantity Controls and Delete Button
          Column(
            children: [
              // Quantity Controls Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      _updateCartItemQuantity(cartItem, cartItem.quantity - 1);
                    },
                    icon: const Icon(Icons.remove),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Text(
                    cartItem.quantity.toString(),
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _updateCartItemQuantity(cartItem, cartItem.quantity + 1);
                    },
                    icon: const Icon(Icons.add),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              // Delete Button
              IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                    _removeCartItem(cartItem);
                },
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                cartProvider.formattedTotalAmount,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement checkout
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checkout functionality coming soon!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'PROCEED TO CHECKOUT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.fontSizeMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
