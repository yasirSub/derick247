class ApiConfig {
  // Base URL for the API
  static const String baseUrl = 'https://derick247.com/api/';

  // API Key for authentication
  static const String apiKey = 'gcs##2022##';

  // API Headers for JSON requests
  static Map<String, String> get jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    
    'x-api-key': apiKey,
  };

  // API Headers for form-data requests
  static Map<String, String> get formHeaders => {
    'Accept': 'application/json',
    'x-api-key': apiKey,
  };

  // Authentication endpoints
  static const String login = 'login';
  static const String register = 'register';
  static const String logout = 'logout';
  static const String resendVerification = 'resend-verification';
  static const String profile = 'profile';

  // Location endpoints
  static const String locations = 'locations';

  // Product endpoints
  static const String home = ''; // Home API endpoint (root)
  static const String productDetail = 'product/';
  static const String categories = 'categories';

  // Referral endpoints
  static const String referralInfo = 'referral-info/';
  static const String referFriend = 'refer-friend';

  // Cart endpoints
  static const String cart = 'cart';

  // Order endpoints
  static const String orders = 'orders';

  // Dropshipping Product endpoints
  static const String dropshippingProduct = 'dropshipping-product';

  // Vendor Product endpoints
  static const String vendorProduct = 'vendor-product';
}
