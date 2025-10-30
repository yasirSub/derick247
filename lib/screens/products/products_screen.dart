import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/referral_popup.dart';
import '../../widgets/custom_app_bar.dart';
import '../auth/login_screen.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;

  const ProductsScreen({Key? key, this.categoryId, this.categoryName})
    : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    // Load products when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // If coming from search, keep the search query
      // Otherwise, clear any previous search and load all products
      if (widget.categoryName != 'Search Results' && productProvider.searchQuery != null) {
        productProvider.clearFilters();
      }
      
      // Always load products fresh when opening ProductsScreen
      productProvider.loadProducts(refresh: true);
    });
  }

  void _showReferralPopup(BuildContext context, product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ReferralPopup(
          product: product,
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
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
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please log in to access referral features and earn commissions.',
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text('Login'),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.categoryName ?? 'Explore Products',
        isDark: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Open filters
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          // Show error if exists
          if (productProvider.error != null && productProvider.products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      'Error loading products',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeLarge,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      productProvider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: AppTheme.fontSizeMedium,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),
                    ElevatedButton(
                      onPressed: () {
                        productProvider.loadProducts(refresh: true);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (productProvider.isLoading && productProvider.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productProvider.products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeLarge,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      productProvider.searchQuery != null
                          ? 'Try a different search term'
                          : 'Products will appear here',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),
                    ElevatedButton(
                      onPressed: () {
                        productProvider.loadProducts(refresh: true);
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await productProvider.loadProducts(refresh: true);
            },
            child: _isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.60, // Flexible aspect ratio to prevent overflow
                          crossAxisSpacing: AppTheme.spacingSmall,
                          mainAxisSpacing: AppTheme.spacingSmall,
                        ),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return ProductGridCard(
                        product: product,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                productId: product.id,
                                product: product,
                              ),
                            ),
                          );
                        },
                        onShare: () {
                          // TODO: Share product
                        },
                        onRefer: () {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          if (authProvider.isLoggedIn) {
                            _showReferralPopup(context, product);
                          } else {
                            _showLoginPrompt(context);
                          }
                        },
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                productId: product.id,
                                product: product,
                              ),
                            ),
                          );
                        },
                        onShare: () {
                          // TODO: Share product
                        },
                        onRefer: () {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          if (authProvider.isLoggedIn) {
                            _showReferralPopup(context, product);
                          } else {
                            _showLoginPrompt(context);
                          }
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
