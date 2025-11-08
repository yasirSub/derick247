import 'package:app_links/app_links.dart';
import 'dart:async';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri>? _uriLinkSubscription;

  // Callback function to handle deep links
  Function(Uri)? onLinkReceived;

  /// Initialize deep link listening
  void initialize() {
    // Handle links when app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        print('Deep link error: $err');
      },
    );

    // Handle initial link when app is opened from a deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle links when app is in background and opened
    _uriLinkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        print('Deep link error: $err');
      },
    );
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');
    if (onLinkReceived != null) {
      onLinkReceived!(uri);
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _uriLinkSubscription?.cancel();
  }

  /// Parse deep link and extract route information
  /// Works with or without referral codes
  static DeepLinkRoute? parseRoute(Uri uri) {
    final path = uri.path;
    final queryParams = uri.queryParameters;

    print('🔍 Parsing deep link: path=$path, queryParams=$queryParams');

    // Handle different deep link patterns
    if (path.startsWith('/product/') || path.contains('/product/')) {
      // Extract product slug or ID from path
      // Format: /product/{slug} or /product/{id}
      final productMatch = RegExp(r'/product/([^/?]+)').firstMatch(path);
      if (productMatch != null) {
        final productIdentifier = productMatch.group(1)!;

        // Try to parse as numeric ID first
        final productId = int.tryParse(productIdentifier);
        if (productId != null) {
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
    } else if (path.startsWith('/checkout-guest/')) {
      // Extract referral code from path
      // Format: /checkout-guest/{referralCode}
      final checkoutMatch = RegExp(
        r'/checkout-guest/([^/?]+)',
      ).firstMatch(path);
      if (checkoutMatch != null) {
        final referralCode = checkoutMatch.group(1)!;
        return DeepLinkRoute(
          type: DeepLinkType.checkoutGuest,
          queryParams: {...queryParams, 'ref': referralCode},
        );
      }
      // Also support /checkout-guest with ref in query params
      return DeepLinkRoute(
        type: DeepLinkType.checkoutGuest,
        queryParams: queryParams,
      );
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
  final Map<String, String> queryParams;

  DeepLinkRoute({
    required this.type,
    this.productId,
    this.productSlug,
    this.productIdentifier,
    this.categoryId,
    this.orderId,
    this.queryParams = const {},
  });
}
