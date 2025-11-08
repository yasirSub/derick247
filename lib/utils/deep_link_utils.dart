/// Utility class for generating deep link URLs
class DeepLinkUtils {
  // Base URL for deep links - using comisionista247.com where assetlinks.json is deployed
  static const String baseUrl = 'https://comisionista247.com';
  static const String customScheme = 'derick247';

  /// Generate a product deep link URL using slug (preferred) or ID
  static String generateProductLink({
    int? productId,
    String? productSlug,
    String? productName,
    String? refCode,
  }) {
    // Prefer slug over ID for better SEO and readability
    String productIdentifier;
    if (productSlug != null && productSlug.isNotEmpty) {
      productIdentifier = productSlug;
    } else if (productId != null) {
      productIdentifier = productId.toString();
    } else {
      throw ArgumentError('Either productId or productSlug must be provided');
    }

    // Use HTTPS URL for better compatibility (works as universal link)
    String url = '$baseUrl/product/$productIdentifier';

    // Add referral code if provided
    if (refCode != null && refCode.isNotEmpty) {
      url += '?ref=${Uri.encodeComponent(refCode)}';
    }

    return url;
  }

  /// Generate a product deep link URL (backward compatibility)
  static String generateProductLinkById(int productId, {String? productName}) {
    return generateProductLink(productId: productId, productName: productName);
  }

  /// Generate a product deep link URL with custom scheme
  static String generateProductLinkCustomScheme(int productId) {
    return '$customScheme://product/$productId';
  }

  /// Generate a category deep link URL
  static String generateCategoryLink(int categoryId, {String? categoryName}) {
    final url = '$baseUrl/category/$categoryId';
    if (categoryName != null) {
      return '$url?name=${Uri.encodeComponent(categoryName)}';
    }
    return url;
  }

  /// Generate a cart deep link URL
  static String generateCartLink() {
    return '$baseUrl/cart';
  }

  /// Generate a dashboard deep link URL
  static String generateDashboardLink() {
    return '$baseUrl/dashboard';
  }

  /// Generate a profile deep link URL
  static String generateProfileLink() {
    return '$baseUrl/profile';
  }

  /// Generate an order deep link URL
  static String generateOrderLink(int orderId) {
    return '$baseUrl/order/$orderId';
  }

  /// Generate shareable text with product information and deep link
  static String generateProductShareText({
    required String productName,
    required String price,
    int? productId,
    String? productSlug,
    String? description,
    String? refCode,
  }) {
    final link = generateProductLink(
      productId: productId,
      productSlug: productSlug,
      productName: productName,
      refCode: refCode,
    );
    final shareText = 'Check out $productName - $price\n\n$link';

    if (description != null && description.isNotEmpty) {
      return '$shareText\n\n$description';
    }

    return shareText;
  }
}
