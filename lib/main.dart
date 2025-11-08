import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'config/theme_config.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/referral_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/black_board_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/products/product_detail_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/checkout/checkout_screen.dart';
import 'screens/profile/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/orders/order_details_screen.dart';
import 'screens/auth/login_screen.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

void main() {
  runApp(const Derick247App());
}

// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Derick247App extends StatelessWidget {
  const Derick247App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => BlackBoardProvider()),
      ],
      child: ScrollConfiguration(
        behavior: NoGlowScrollBehavior(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Derick247',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: const AppInitializer(),
        ),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _isHandlingDeepLink =
      false; // Prevent multiple simultaneous deep link navigations
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupDeepLinks();
  }

  void _setupDeepLinks() {
    // Set up deep link handler
    _deepLinkService.onLinkReceived = (Uri uri) {
      _handleDeepLink(uri);
    };

    // Initialize deep link service
    _deepLinkService.initialize();
  }

  void _handleDeepLink(Uri uri) {
    // Prevent multiple simultaneous deep link navigations
    if (_isHandlingDeepLink) {
      print('⚠️ Deep link already being handled, ignoring: $uri');
      return;
    }

    // Wait for app to be initialized before handling deep links
    if (!_isInitialized) {
      // Store the link to handle after initialization
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _handleDeepLink(uri);
        }
      });
      return;
    }

    // Parse the deep link
    final deepLinkRoute = DeepLinkService.parseRoute(uri);
    if (deepLinkRoute == null) {
      print('Unknown deep link: $uri');
      return;
    }

    // Navigate based on route type
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      print('Navigator not available for deep link: $uri');
      return;
    }

    // Get context from navigator - it should have access to providers
    final navContext = navigator.context;

    // Set flag to prevent multiple navigations
    _isHandlingDeepLink = true;

    // Navigate to the specific screen
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) {
        _isHandlingDeepLink = false;
        return;
      }

      try {
        switch (deepLinkRoute.type) {
          case DeepLinkType.product:
            // Handle referral code if present (optional - deep link works with or without it)
            final refCode = deepLinkRoute.queryParams['ref'];
            if (refCode != null && refCode.isNotEmpty) {
              try {
                final referralProvider = Provider.of<ReferralProvider>(
                  navContext,
                  listen: false,
                );
                referralProvider.trackReferralClick(refCode);
                print('✅ Referral code tracked: $refCode');
              } catch (e) {
                print('⚠️ Error tracking referral: $e');
                // Continue even if referral tracking fails
              }
            } else {
              print(
                'ℹ️ No referral code in deep link - opening product normally',
              );
            }

            // Get product identifier
            String? productIdentifier;

            if (deepLinkRoute.productIdentifier != null) {
              productIdentifier = deepLinkRoute.productIdentifier;
            } else if (deepLinkRoute.productSlug != null) {
              productIdentifier = deepLinkRoute.productSlug;
            } else if (deepLinkRoute.productId != null) {
              productIdentifier = deepLinkRoute.productId.toString();
            }

            if (productIdentifier != null) {
              print('🔗 Opening product: $productIdentifier');

              // Always pop back to home first to prevent overlapping screens
              // This ensures clean navigation - no multiple product screens stacked
              if (navigator.canPop()) {
                navigator.popUntil((route) => route.isFirst);
                // Small delay to ensure navigation animation completes
                await Future.delayed(const Duration(milliseconds: 100));
              }

              // Now push the product screen - this will always load fresh data
              navigator.push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(productSlug: productIdentifier),
                ),
              );
            } else {
              print('❌ No product identifier found in deep link');
            }
            break;
          case DeepLinkType.checkoutGuest:
            // Handle checkout-guest with referral code
            final refCode = deepLinkRoute.queryParams['ref'];
            try {
              final authProvider = Provider.of<AuthProvider>(
                navContext,
                listen: false,
              );

              if (!authProvider.isLoggedIn) {
                // Show login screen first
                final loginResult = await navigator.push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (loginResult != true) {
                  return; // User didn't login
                }
              }

              // Track referral if present
              if (refCode != null && refCode.isNotEmpty) {
                try {
                  final referralProvider = Provider.of<ReferralProvider>(
                    navContext,
                    listen: false,
                  );
                  referralProvider.trackReferralClick(refCode);
                } catch (e) {
                  print('Error tracking referral: $e');
                }
              }

              // Navigate to checkout
              navigator.push(
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            } catch (e) {
              print('Error handling checkout-guest: $e');
            }
            break;
          case DeepLinkType.category:
            if (deepLinkRoute.categoryId != null) {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ProductsScreen(
                    categoryId: deepLinkRoute.categoryId!,
                    categoryName:
                        deepLinkRoute.queryParams['name'] ?? 'Category',
                  ),
                ),
              );
            }
            break;
          case DeepLinkType.cart:
            navigator.push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
            break;
          case DeepLinkType.dashboard:
            // Check if user is logged in
            try {
              final authProvider = Provider.of<AuthProvider>(
                navContext,
                listen: false,
              );
              if (authProvider.isLoggedIn) {
                navigator.push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              } else {
                navigator.push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            } catch (e) {
              print('Error accessing AuthProvider: $e');
              navigator.push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
            break;
          case DeepLinkType.profile:
            navigator.push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            break;
          case DeepLinkType.order:
            if (deepLinkRoute.orderId != null) {
              // Check if user is logged in
              try {
                final authProvider = Provider.of<AuthProvider>(
                  navContext,
                  listen: false,
                );
                if (authProvider.isLoggedIn) {
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailsScreen(orderId: deepLinkRoute.orderId!),
                    ),
                  );
                } else {
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              } catch (e) {
                print('Error accessing AuthProvider: $e');
                navigator.push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            }
            break;
          case DeepLinkType.home:
            // Navigate to home if not already there
            if (navigator.canPop()) {
              navigator.popUntil((route) => route.isFirst);
            }
            break;
        }
      } catch (e) {
        print('Error handling deep link: $e');
      } finally {
        // Reset flag after handling is complete
        _isHandlingDeepLink = false;
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize services
      ApiService().initialize();
      AuthService().initialize();

      // Initialize providers
      await context.read<AuthProvider>().initialize();
      await context.read<CartProvider>().loadCart();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart, size: 44, color: AppTheme.primaryColor),
              SizedBox(height: 20),
              Text(
                'Derick247',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
