import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/black_board_provider.dart';
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
import '../../widgets/login_required_bottom_sheet.dart';
import '../../widgets/point_options_bottom_sheet.dart';
import '../../widgets/translated_text.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../profile/dashboard_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_flags/country_flags.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, this.forceRefresh = false}) : super(key: key);

  final bool forceRefresh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Build screens list - Dashboard only when needed to avoid redirect issues
  List<Widget> _buildScreens() {
    return [
      const HomeTab(),
      const WishlistScreen(),
      const CartScreen(),
      const DashboardScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      productProvider.loadProducts(refresh: widget.forceRefresh);
      productProvider.loadCategories();

      if (widget.forceRefresh) {
        Provider.of<BlackBoardProvider>(
          context,
          listen: false,
        ).loadEntries(refresh: true);
      }
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
        backgroundColor: const Color(0xFF10131A),
        body: IndexedStack(index: _selectedIndex, children: _buildScreens()),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            // Check if user is trying to access dashboard (index 3) without being logged in
            if (index == 3) {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              if (!authProvider.isLoggedIn) {
                // Redirect to login page
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
                return;
              }
            }
            if (index == 1) {
              Provider.of<BlackBoardProvider>(
                context,
                listen: false,
              ).loadEntries(refresh: true);
            }
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
  final ApiService _apiService = ApiService();
  int _currentBannerIndex = 0;
  bool _isGridView = true; // true = grid view by default
  String? _selectedCurrency;
  String? _selectedCountryCode;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoadingBanners = true;

  String _flagForCurrency(String? code) {
    if (code == null) return '💱';
    final upper = code.toUpperCase();
    const mapping = {
      'USD': '🇺🇸',
      'HNL': '🇭🇳',
      'GTQ': '🇬🇹',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'INR': '🇮🇳',
      'PKR': '🇵🇰',
      'AUD': '🇦🇺',
      'CAD': '🇨🇦',
      'JPY': '🇯🇵',
    };
    return mapping[upper] ?? '💱';
  }

  String? _countryCodeForCurrency(String? code) {
    if (code == null) return null;
    switch (code.toUpperCase()) {
      case 'USD':
        return 'US';
      case 'HNL':
        return 'HN';
      case 'GTQ':
        return 'GT';
      case 'EUR':
        return null; // region, no single country
      case 'GBP':
        return 'GB';
      case 'INR':
        return 'IN';
      case 'PKR':
        return 'PK';
      case 'AUD':
        return 'AU';
      case 'CAD':
        return 'CA';
      case 'JPY':
        return 'JP';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadBanners();
    _loadSelectedCurrency();
    // Removed auto profile refresh due to backend 500 on /profile
  }

  Future<void> _loadBanners() async {
    try {
      final response = await _apiService.getAppAssets();
      if (response.statusCode == 200 && mounted) {
        final data = response.data['data'];
        if (data != null && data['banners'] != null) {
          setState(() {
            _banners = List<Map<String, dynamic>>.from(data['banners']);
            _isLoadingBanners = false;
          });
          if (_banners.isNotEmpty) {
            _startBannerTimer();
          }
        } else {
          setState(() {
            _isLoadingBanners = false;
          });
        }
      } else {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
  }

  Future<void> _loadSelectedCurrency() async {
    final storage = StorageService();
    final savedCurrency = await storage.getSelectedCurrency();
    final savedCountry = await storage.getSelectedCountryCode();
    if (mounted) {
      setState(() {
        _selectedCurrency = savedCurrency;
        _selectedCountryCode = savedCountry;
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
        // Also load any saved country code from selection
        StorageService().getSelectedCountryCode().then((value) {
          if (mounted) {
            setState(() {
              _selectedCountryCode = value;
            });
          }
        });
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
      // Skipped profile refresh due to backend 500 on /profile
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // ignore: avoid_print
      print('Could not launch $url');
    }
  }

  void _startBannerTimer() {
    if (_banners.isEmpty) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _banners.isNotEmpty) {
        _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'home'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        isDark: true,
        leadingWidth: 136,
        leading: Padding(
          padding: const EdgeInsets.only(left: 0),
          child: SizedBox(
            width: 136,
            child: IconButton(
              padding: const EdgeInsets.only(left: 10),
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints(minWidth: 104, minHeight: 44),
              icon: _selectedCurrency != null && _selectedCurrency!.isNotEmpty
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.34),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(
                              builder: (context) {
                                final iso =
                                    _selectedCountryCode ??
                                    _countryCodeForCurrency(_selectedCurrency);
                                if (iso != null) {
                                  return Container(
                                    width: 20,
                                    height: 14,
                                    margin: const EdgeInsets.only(right: 0),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: CountryFlag.fromCountryCode(
                                      iso,
                                      height: 14,
                                      width: 20,
                                    ),
                                  );
                                }
                                return Text(
                                  _flagForCurrency(_selectedCurrency),
                                  style: const TextStyle(fontSize: 16),
                                );
                              },
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _selectedCurrency!,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.currency_exchange,
                      color: Colors.white,
                      size: 26,
                    ),
              onPressed: () {
                _showCurrencyDialog(context);
              },
            ),
          ),
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
                    height: 160,
                    margin: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMedium,
                      AppTheme.spacingMedium,
                      AppTheme.spacingMedium,
                      AppTheme.spacingSmall,
                    ),
                    child: Stack(
                      children: [
                        PageView(
                          controller: _bannerController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentBannerIndex = index;
                            });
                          },
                          children: _isLoadingBanners
                              ? [
                                  // Loading placeholder
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                    child: Container(
                                      color: Colors.white,
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ]
                              : _banners.isEmpty
                              ? [
                                  // Fallback if no banners
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                    child: Container(
                                      color: Colors.white,
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                              : _banners.map((banner) {
                                  final imageUrl = banner['image'] as String?;
                                  return GestureDetector(
                                    onTap: () => _openUrl(
                                      'https://comisionista247.com/',
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                      child: Container(
                                        color: Colors.white,
                                        width: double.infinity,
                                        height: double.infinity,
                                        child: imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.contain,
                                                alignment: Alignment.center,
                                                width: double.infinity,
                                                height: double.infinity,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      color: Colors.white,
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Container(
                                                      color: Colors.white,
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: Colors.white,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                        // Page Indicators
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _banners.isEmpty ? 1 : _banners.length,
                              (index) {
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
                              },
                            ),
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
                        const TranslatedText(
                          'home.shopByCategory',
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
                          child: const TranslatedText('app.seeMore'),
                        ),
                      ],
                    ),
                  ),

                  // Categories Grid
                  SizedBox(
                    height: 100,
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
                                constraints: const BoxConstraints(maxWidth: 86),
                                margin: const EdgeInsets.only(
                                  right: AppTheme.spacingSmall,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    children: [
                                      // Image tile
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.06,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: category.media != null
                                            ? CachedNetworkImage(
                                                imageUrl: category.media!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      color: Colors.grey[200],
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Container(
                                                          color:
                                                              Colors.grey[200],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.category,
                                                              size: 40,
                                                            ),
                                                          ),
                                                        ),
                                              )
                                            : Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.category,
                                                    size: 40,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      // Bottom label bar (solid)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    6,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    6,
                                                  ),
                                                ),
                                          ),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            category.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: AppTheme.fontSizeSmall,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
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
                      },
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingMedium),

                  // Featured Products
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TranslatedText(
                          'home.featuredProducts',
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
                              tooltip: _isGridView
                                  ? TranslationService().translate(
                                      'home.listView',
                                    )
                                  : TranslationService().translate(
                                      'home.gridView',
                                    ),
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
                              child: const TranslatedText('app.seeMore'),
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
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingLarge),
                        child: TranslatedText('home.noProducts'),
                      ),
                    )
                  else
                    _isGridView
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingMedium,
                              AppTheme.spacingSmall,
                              AppTheme.spacingMedium,
                              AppTheme.spacingMedium,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio:
                                      0.60, // More flexible aspect ratio
                                  crossAxisSpacing: AppTheme.spacingSmall,
                                  mainAxisSpacing: 6,
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
                                  // Share functionality is handled in ProductCard widget
                                },
                                onRefer: () {
                                  _showReferralPopup(context, product);
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
                                          Expanded(
                                            child: Text(
                                              TranslationService().translate(
                                                'cart.addedTapToView',
                                              ),
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
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: AppTheme.spacingMedium,
                                  right: AppTheme.spacingMedium,
                                  bottom: 10,
                                ),
                                child: ProductCard(
                                  product: product,
                                  showEarnButton: true,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailScreen(
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
                                          label: TranslationService().translate(
                                            'cart.viewCart',
                                          ),
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
                                ),
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
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2563EB), // Primary blue
                  Color(0xFF1D4ED8), // Darker blue
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Check if user is logged in
                  if (!authProvider.isLoggedIn) {
                    // Show login required bottom sheet
                    LoginRequiredBottomSheet.show(context);
                  } else {
                    // User is logged in, show point options
                    PointOptionsBottomSheet.show(context);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.podcasts,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
