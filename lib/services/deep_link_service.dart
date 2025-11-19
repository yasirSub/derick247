import 'package:app_links/app_links.dart';
import 'dart:async';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Callback function to handle deep links
  Function(Uri)? onLinkReceived;

  // Store pending links until callback is set
  Uri? _pendingLink;

  /// Initialize deep link listening
  void initialize() {
    print('🔧 Initializing deep link service...');

    // Handle links when app is already open or in background
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('📱 Deep link from stream: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        print('❌ Deep link stream error: $err');
      },
    );

    // Handle initial link when app is opened from a deep link
    // This might be called before the callback is set, so we store it
    _appLinks
        .getInitialLink()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⏱️ Timeout getting initial link');
            return null;
          },
        )
        .then((Uri? uri) {
          if (uri != null) {
            print('🚀 Initial deep link received: $uri');
            // Store pending link if callback not set yet
            if (onLinkReceived == null) {
              print('⏳ Callback not set yet, storing pending link');
              _pendingLink = uri;
              // Try again after a delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_pendingLink != null && onLinkReceived != null) {
                  print('✅ Processing pending link: $_pendingLink');
                  final link = _pendingLink;
                  _pendingLink = null;
                  _handleDeepLink(link!);
                }
              });
            } else {
              _handleDeepLink(uri);
            }
          } else {
            print('ℹ️ No initial deep link');
          }
        })
        .catchError((err) {
          print('❌ Error getting initial link: $err');
        });
  }

  /// Set the callback and process any pending links
  void setCallback(Function(Uri) callback) {
    onLinkReceived = callback;
    if (_pendingLink != null) {
      print('✅ Callback set, processing pending link: $_pendingLink');
      final link = _pendingLink;
      _pendingLink = null;
      _handleDeepLink(link!);
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link received in service: $uri');
    if (onLinkReceived != null) {
      onLinkReceived!(uri);
    } else {
      print(
        '⚠️ Warning: Deep link received but onLinkReceived callback is null!',
      );
      // Retry after a short delay in case callback is being set
      Future.delayed(const Duration(milliseconds: 100), () {
        if (onLinkReceived != null) {
          print('✅ Retrying deep link handling...');
          onLinkReceived!(uri);
        }
      });
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }

  /// Parse deep link and extract route information
  /// Works with or without referral codes
  static DeepLinkRoute? parseRoute(Uri uri) {
    final path = uri.path;
    final queryParams = uri.queryParameters;

    print('🔍 Parsing deep link: path=$path, queryParams=$queryParams');
    print('   - Full URI: $uri');

    // Handle different deep link patterns
    if (path.startsWith('/product/') || path.contains('/product/')) {
      // Extract product slug or ID from path
      // Format: /product/{slug} or /product/{id}
      final productMatch = RegExp(r'/product/([^/?]+)').firstMatch(path);
      if (productMatch != null) {
        // Decode URL-encoded characters (e.g., %20 -> space, %2F -> /)
        final rawIdentifier = productMatch.group(1)!;
        final productIdentifier = Uri.decodeComponent(rawIdentifier);

        print('🔍 Extracted product identifier from URL:');
        print('   - Raw: "$rawIdentifier"');
        print('   - Decoded: "$productIdentifier"');

        // Check for referral code
        if (queryParams.containsKey('ref')) {
          print('   - Referral code found: ${queryParams['ref']}');
        }

        // Try to parse as numeric ID first
        final productId = int.tryParse(productIdentifier);
        if (productId != null) {
          print('✅ Product identifier is numeric ID: $productId');
          return DeepLinkRoute(
            type: DeepLinkType.product,
            productId: productId,
            productSlug: null,
            productIdentifier: productIdentifier,
            queryParams: queryParams,
          );
        } else {
          // It's a slug or non-numeric ID (e.g., "laptop-BJt35c")
          // Store it as both slug and identifier - we'll try both approaches
          print('✅ Product identifier is slug: "$productIdentifier"');
          return DeepLinkRoute(
            type: DeepLinkType.product,
            productId: null,
            productSlug: productIdentifier,
            productIdentifier: productIdentifier,
            queryParams: queryParams,
          );
        }
      }
      // Also check query parameters
      if (queryParams.containsKey('product_id') ||
          queryParams.containsKey('productId')) {
        final productId = int.tryParse(
          queryParams['product_id'] ?? queryParams['productId'] ?? '',
        );
        if (productId != null) {
          return DeepLinkRoute(
            type: DeepLinkType.product,
            productId: productId,
            productSlug: null,
            productIdentifier: productId.toString(),
            queryParams: queryParams,
          );
        }
      }
      // Check for slug in query params
      if (queryParams.containsKey('slug')) {
        final slug = queryParams['slug']!;
        return DeepLinkRoute(
          type: DeepLinkType.product,
          productId: null,
          productSlug: slug,
          productIdentifier: slug,
          queryParams: queryParams,
        );
      }
    } else if (path.startsWith('/category/') || path.contains('/category/')) {
      // Extract category ID from path
      final categoryIdMatch = RegExp(r'/category/(\d+)').firstMatch(path);
      if (categoryIdMatch != null) {
        final categoryId = int.tryParse(categoryIdMatch.group(1)!);
        if (categoryId != null) {
          return DeepLinkRoute(
            type: DeepLinkType.category,
            categoryId: categoryId,
            queryParams: queryParams,
          );
        }
      }
      // Also check query parameters
      if (queryParams.containsKey('category_id') ||
          queryParams.containsKey('categoryId')) {
        final categoryId = int.tryParse(
          queryParams['category_id'] ?? queryParams['categoryId'] ?? '',
        );
        if (categoryId != null) {
          return DeepLinkRoute(
            type: DeepLinkType.category,
            categoryId: categoryId,
            queryParams: queryParams,
          );
        }
      }
    } else if (path.startsWith('/cart') || path == '/cart') {
      return DeepLinkRoute(type: DeepLinkType.cart, queryParams: queryParams);
    } else if (path.startsWith('/dashboard') || path == '/dashboard') {
      return DeepLinkRoute(
        type: DeepLinkType.dashboard,
        queryParams: queryParams,
      );
    } else if (path.startsWith('/profile') || path == '/profile') {
      return DeepLinkRoute(
        type: DeepLinkType.profile,
        queryParams: queryParams,
      );
    } else if (path.startsWith('/checkout/') || path.contains('/checkout/')) {
      // Extract checkout token from path
      // Format: /checkout/{token} (for guest checkout)
      final checkoutMatch = RegExp(r'/checkout/([^/?]+)').firstMatch(path);
      if (checkoutMatch != null) {
        final checkoutToken = checkoutMatch.group(1)!;
        return DeepLinkRoute(
          type: DeepLinkType.checkoutGuest,
          checkoutToken: checkoutToken,
          queryParams: queryParams,
        );
      }
      // Also support /checkout-guest/{token} for backward compatibility
    } else if (path.startsWith('/checkout-guest/') ||
        path.contains('/checkout-guest/')) {
      // Extract token from path
      // Format: /checkout-guest/{token}
      final checkoutMatch = RegExp(
        r'/checkout-guest/([^/?]+)',
      ).firstMatch(path);
      if (checkoutMatch != null) {
        // Decode URL-encoded characters
        final rawToken = checkoutMatch.group(1)!;
        final checkoutToken = Uri.decodeComponent(rawToken);

        print('🔍 Extracted checkout token from URL:');
        print('   - Raw: "$rawToken"');
        print('   - Decoded: "$checkoutToken"');

        return DeepLinkRoute(
          type: DeepLinkType.checkoutGuest,
          checkoutToken: checkoutToken,
          queryParams: queryParams,
        );
      }
      // Also support /checkout-guest with token in query params
      final tokenFromQuery = queryParams['token'];
      if (tokenFromQuery != null) {
        print('🔍 Checkout token from query params: $tokenFromQuery');
        return DeepLinkRoute(
          type: DeepLinkType.checkoutGuest,
          checkoutToken: tokenFromQuery,
          queryParams: queryParams,
        );
      }
    } else if (path.startsWith('/order/') || path.contains('/order/')) {
      // Extract order ID from path
      final orderIdMatch = RegExp(r'/order/(\d+)').firstMatch(path);
      if (orderIdMatch != null) {
        final orderId = int.tryParse(orderIdMatch.group(1)!);
        if (orderId != null) {
          return DeepLinkRoute(
            type: DeepLinkType.order,
            orderId: orderId,
            queryParams: queryParams,
          );
        }
      }
    } else if (path.contains('email-verified') ||
        path.contains('/verify-email') ||
        path.contains('verify-email-success') ||
        path.contains('email-verification-success')) {
      return DeepLinkRoute(
        type: DeepLinkType.emailVerified,
        queryParams: queryParams,
        rawUri: uri,
      );
    } else if (path == '/' || path.isEmpty) {
      return DeepLinkRoute(type: DeepLinkType.home, queryParams: queryParams);
    }

    return null;
  }
}

/// Deep link route types
enum DeepLinkType {
  product,
  category,
  cart,
  checkoutGuest,
  dashboard,
  profile,
  order,
  emailVerified,
  home,
}

/// Deep link route information
class DeepLinkRoute {
  final DeepLinkType type;
  final int? productId;
  final String? productSlug;
  final String? productIdentifier; // Can be ID or slug - try both
  final int? categoryId;
  final int? orderId;
  final String? checkoutToken; // Token for guest checkout
  final Map<String, String> queryParams;
  final Uri? rawUri;

  DeepLinkRoute({
    required this.type,
    this.productId,
    this.productSlug,
    this.productIdentifier,
    this.categoryId,
    this.orderId,
    this.checkoutToken,
    this.queryParams = const {},
    this.rawUri,
  });
}
