import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Load products when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      // If coming from search, keep the search query
      if (widget.categoryName == 'Search Results' &&
          productProvider.searchQuery != null) {
        _searchController.text = productProvider.searchQuery!;
        setState(() {
          _showClearButton = productProvider.searchQuery!.isNotEmpty;
        });
      } else if (widget.categoryName != 'Search Results' &&
          productProvider.searchQuery != null) {
        productProvider.clearFilters();
      }

      // Always load products fresh when opening ProductsScreen
      productProvider.loadProducts(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    setState(() {
      _showClearButton = query.isNotEmpty;
    });
    
    // Debounce search API calls
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      // Clear search when empty
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      if (productProvider.searchQuery != null) {
        productProvider.clearFilters();
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.searchProducts(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showClearButton = false;
    });
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    productProvider.clearFilters();
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
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
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 22,
                ),
                suffixIcon: _showClearButton
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                _searchFocusNode.unfocus();
                if (value.trim().isNotEmpty) {
                  final productProvider = Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  );
                  productProvider.searchProducts(value.trim());
                }
              },
            ),
          ),
          // Products List
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                // Show error if exists
                if (productProvider.error != null &&
                    productProvider.products.isEmpty) {
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
                      style: TextStyle(color: AppTheme.textSecondaryColor),
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
                          childAspectRatio:
                              0.60, // Flexible aspect ratio to prevent overflow
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 10,
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
                          _showReferralPopup(context, product);
                        },
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMedium,
                      AppTheme.spacingSmall,
                      AppTheme.spacingMedium,
                      AppTheme.spacingMedium,
                    ),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ProductCard(
                          product: product,
                          priceAsPill: true,
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
                        ),
                      );
                    },
                  ),
            );
              },
            ),
          ),
        ],
      ),
    );
  }
}
