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
import 'providers/locale_provider.dart';
import 'services/translation_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/products/product_detail_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/checkout/guest/guest_checkout_screen.dart';
import 'screens/profile/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/orders/order_details_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_verified_success_screen.dart';
import 'utils/responsive.dart';

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
        ChangeNotifierProvider(
          create: (_) {
            final service = TranslationService();
            service.initialize();
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => BlackBoardProvider()),
      ],
      child: Consumer2<LocaleProvider, TranslationService>(
        builder: (context, localeProvider, translationService, child) {
          // Force rebuild when either locale or translations change
          return ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Derick247',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              locale: localeProvider.locale,
              supportedLocales: const [
                Locale('en', ''), // English
                Locale('es', ''), // Spanish
              ],
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                final media = MediaQuery.of(context);
                final clampedScale = Responsive.clampTextScale(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(clampedScale),
                  ),
                  child: child,
                );
              },
              home: const AppInitializer(),
            ),
          );
        },
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
    // Initialize deep link service FIRST (it will handle pending links)
    _deepLinkService.initialize();

    // Set up deep link handler AFTER initializing
    // Use the setCallback method to ensure pending links are processed
    _deepLinkService.setCallback((Uri uri) {
      print('🔗 Deep link callback triggered: $uri');
      _handleDeepLink(uri);
    });

    print('✅ Deep link service initialized and callback set');
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 _handleDeepLink called with: $uri');
    print('   - _isHandlingDeepLink: $_isHandlingDeepLink');
    print('   - _isInitialized: $_isInitialized');
    print('   - mounted: $mounted');

    // Prevent multiple simultaneous deep link navigations
    if (_isHandlingDeepLink) {
      print('⚠️ Deep link already being handled, ignoring: $uri');
      return;
    }

    // Wait for app to be initialized before handling deep links
    if (!_isInitialized) {
      print('⏳ App not initialized yet, retrying in 500ms...');
      // Store the link to handle after initialization
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('🔄 Retrying deep link after initialization: $uri');
          _handleDeepLink(uri);
        } else {
          print('❌ Widget not mounted, cannot handle deep link: $uri');
        }
      });
      return;
    }

    print('✅ App is initialized, parsing deep link...');

    // Parse the deep link
    final deepLinkRoute = DeepLinkService.parseRoute(uri);
    if (deepLinkRoute == null) {
      print('❌ Unknown deep link format: $uri');
      return;
    }

    print('✅ Deep link parsed successfully: ${deepLinkRoute.type}');

    // Navigate based on route type
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      print('❌ Navigator not available for deep link: $uri');
      return;
    }

    print('✅ Navigator is available');

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
              print('   - Product will load with or without authentication');
              print('   - Auth token will be sent if user is logged in');

              // Always pop back to home first to prevent overlapping screens
              // This ensures clean navigation - no multiple product screens stacked
              if (navigator.canPop()) {
                navigator.popUntil((route) => route.isFirst);
                // Small delay to ensure navigation animation completes
                await Future.delayed(const Duration(milliseconds: 100));
              }

              // Now push the product screen - this will always load fresh data
              // Product details can be viewed without login (public access)
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
            // Handle guest checkout with token
            print('🔗 Processing guest checkout deep link');
            print(
              '   - Checkout token from route: ${deepLinkRoute.checkoutToken}',
            );
            print(
              '   - Checkout token from query: ${deepLinkRoute.queryParams['token']}',
            );

            final checkoutToken =
                deepLinkRoute.checkoutToken ??
                deepLinkRoute.queryParams['token'];

            print('🔗 Opening guest checkout with token: $checkoutToken');

            if (checkoutToken == null || checkoutToken.isEmpty) {
              print('❌ No checkout token found in deep link');
              ScaffoldMessenger.of(navContext).showSnackBar(
                const SnackBar(
                  content: Text('Invalid checkout link'),
                  backgroundColor: Colors.red,
                ),
              );
              _isHandlingDeepLink = false;
              return;
            }

            try {
              // Track referral if present
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
              }

              // Always pop back to home first to prevent overlapping screens
              if (navigator.canPop()) {
                navigator.popUntil((route) => route.isFirst);
                // Small delay to ensure navigation animation completes
                await Future.delayed(const Duration(milliseconds: 100));
              }

              // Navigate to guest checkout screen with token
              // Guest checkout can be accessed without login
              print(
                '✅ Navigating to GuestCheckoutScreen with token: $checkoutToken',
              );
              navigator.push(
                MaterialPageRoute(
                  builder: (_) =>
                      GuestCheckoutScreen(checkoutToken: checkoutToken),
                ),
              );
            } catch (e) {
              print('❌ Error handling checkout-guest: $e');
              if (mounted) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(
                    content: Text('Error opening checkout: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
          case DeepLinkType.emailVerified:
            final emailFromQuery = deepLinkRoute.queryParams['email'];
            navigator.push(
              MaterialPageRoute(
                builder: (_) => EmailVerifiedSuccessScreen(
                  email: emailFromQuery,
                  verificationLink: deepLinkRoute.rawUri,
                ),
              ),
            );
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
      await TranslationService().initialize();

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
