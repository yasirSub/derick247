import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/referral_popup.dart';
import '../auth/login_screen.dart';
import '../products/products_screen.dart';
import '../products/product_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/categories_screen.dart';
import '../../widgets/custom_bottom_navigation_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/currency_selection_dialog.dart';
import '../../services/storage_service.dart';
import '../profile/dashboard_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const WishlistScreen(),
    const CartScreen(),
    const DashboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
      Provider.of<ProductProvider>(context, listen: false).loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0, // Only allow pop when on home tab
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          // If not on home tab and user pressed back, navigate to home
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  bool _isGridView = true; // true = grid view by default
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _startBannerTimer();
    _loadSelectedCurrency();
    // Auto-refresh user when home loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshUser();
    });
  }

  Future<void> _loadSelectedCurrency() async {
    final savedCurrency = await StorageService().getSelectedCurrency();
    if (mounted) {
      setState(() {
        _selectedCurrency = savedCurrency;
      });
    }
  }

  void _showCurrencyDialog(BuildContext context) async {
    final selectedCurrency = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const CurrencySelectionDialog();
      },
    );

    // Update currency if a new one was selected
    if (selectedCurrency != null && mounted) {
      setState(() {
        _selectedCurrency = selectedCurrency;
      });

      // Auto-refresh home page data with new currency
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      await productProvider.loadProducts(refresh: true);
      await productProvider.loadCategories();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<AuthProvider>(context, listen: false).refreshUser();
    }
  }

  void _startBannerTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _currentBannerIndex = (_currentBannerIndex + 1) % 2;
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startBannerTimer();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more products when user is near the bottom
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      if (!productProvider.isLoading && productProvider.hasMore) {
        productProvider.loadProducts();
      }
    }
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
      drawer: const AppDrawer(current: 'home'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        isDark: true,
        leading: IconButton(
          icon: _selectedCurrency != null && _selectedCurrency!.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _selectedCurrency!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(Icons.currency_exchange, color: Colors.white),
          onPressed: () {
            _showCurrencyDialog(context);
          },
        ),
        showSearchBar: true,
        searchHint: 'Search here...',
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                  child:
                      authProvider.user != null &&
                          authProvider.user!.avatar != null &&
                          authProvider.user!.avatar!.isNotEmpty
                      ? CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: authProvider.user!.avatar!,
                              fit: BoxFit.cover,
                              width: 36,
                              height: 36,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                color: AppTheme.darkAppBarColor,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            color: AppTheme.darkAppBarColor,
                            size: 20,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          return RefreshIndicator(
            onRefresh: () async {
              await productProvider.loadProducts(refresh: true);
              await productProvider.loadCategories();
            },
            child: Container(
              color: const Color(0xFFE9EBEE),
              child: ListView(
                controller: _scrollController,
                children: [
                  // Sliding Banner
                  Container(
                    width: double.infinity,
                    height: 120,
                    margin: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Stack(
                      children: [
                        PageView(
                          controller: _bannerController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentBannerIndex = index;
                            });
                          },
                          children: [
                            // Coming Soon Banner
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Coming Soon\nStay Tuned!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSizeXXLarge,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Developer Banner
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[700]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.code,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    SizedBox(width: AppTheme.spacingMedium),
                                    Text(
                                      'Developed by\nWorksaar',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: AppTheme.fontSizeXXLarge,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Page Indicators
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(2, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentBannerIndex == index ? 12 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentBannerIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Shop by Category
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shop by Category',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to categories screen to show all categories
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoriesScreen(),
                              ),
                            );
                          },
                          child: const Text('See More'),
                        ),
                      ],
                    ),
                  ),

                  // Categories Grid
                  SizedBox(
                    height: 104,
                    child: Consumer<ProductProvider>(
                      builder: (context, productProvider, child) {
                        if (productProvider.categories.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMedium,
                          ),
                          itemCount: productProvider.categories.length,
                          itemBuilder: (context, index) {
                            final category = productProvider.categories[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductsScreen(
                                      categoryId: category.id,
                                      categoryName: category.name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 90),
                                margin: const EdgeInsets.only(
                                  right: AppTheme.spacingMedium,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium,
                                        ),
                                      ),
                                      child: category.media != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusMedium,
                                                  ),
                                              child: Image.network(
                                                category.media!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons.category,
                                                        size: 40,
                                                      );
                                                    },
                                              ),
                                            )
                                          : const Icon(
                                              Icons.category,
                                              size: 40,
                                            ),
                                    ),
                                    const SizedBox(
                                      height: AppTheme.spacingSmall,
                                    ),
                                    Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontSize: AppTheme.fontSizeSmall,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Featured Products
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Featured Products',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Row(
                          children: [
                            // View Toggle Button
                            IconButton(
                              icon: Icon(
                                _isGridView ? Icons.list : Icons.grid_view,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isGridView = !_isGridView;
                                });
                              },
                              tooltip: _isGridView ? 'List View' : 'Grid View',
                            ),
                            TextButton(
                              onPressed: () {
                                // Navigate to products screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProductsScreen(),
                                  ),
                                );
                              },
                              child: const Text('See More'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Products Display
                  if (productProvider.isLoading &&
                      productProvider.products.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingLarge),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (productProvider.products.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingLarge),
                        child: Text('No products available'),
                      ),
                    )
                  else
                    _isGridView
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(
                              AppTheme.spacingMedium,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio:
                                      0.60, // More flexible aspect ratio
                                  crossAxisSpacing: AppTheme.spacingSmall,
                                  mainAxisSpacing: AppTheme.spacingSmall,
                                ),
                            itemCount: productProvider.products.length,
                            itemBuilder: (context, index) {
                              final product = productProvider.products[index];
                              return ProductGridCard(
                                product: product,
                                showEarnButton: true,
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
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (authProvider.isLoggedIn) {
                                    _showReferralPopup(context, product);
                                  } else {
                                    _showLoginPrompt(context);
                                  }
                                },
                                onAddToCart: () {
                                  // Show clickable popup notification
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.shopping_cart,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Added to cart! Tap to view cart.',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppTheme.successColor,
                                      duration: const Duration(seconds: 3),
                                      action: SnackBarAction(
                                        label: 'VIEW CART',
                                        textColor: Colors.white,
                                        onPressed: () {
                                          // Navigate to cart screen
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CartScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : Column(
                            children: productProvider.products.map((product) {
                              return ProductCard(
                                product: product,
                                showEarnButton: true,
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
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (authProvider.isLoggedIn) {
                                    _showReferralPopup(context, product);
                                  } else {
                                    _showLoginPrompt(context);
                                  }
                                },
                                onAddToCart: () {
                                  // Show clickable popup notification
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.shopping_cart,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Added to cart! Tap to view cart.',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppTheme.successColor,
                                      duration: const Duration(seconds: 3),
                                      action: SnackBarAction(
                                        label: 'VIEW CART',
                                        textColor: Colors.white,
                                        onPressed: () {
                                          // Navigate to cart screen
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CartScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),

                  // Loading indicator for pagination
                  if (productProvider.isLoading &&
                      productProvider.products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacingLarge),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // End of list indicator
                  if (!productProvider.hasMore &&
                      productProvider.products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spacingLarge),
                      child: Center(
                        child: Text(
                          'You\'ve reached the end!',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: AppTheme.fontSizeMedium,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppTheme.spacingLarge),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
