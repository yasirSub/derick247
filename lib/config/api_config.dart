class ApiConfig {
  // Base URL for the API
  // static const String baseUrl = 'https://comisionista247.com/api/';
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
  static const String forgotPassword = 'forgot-password';
  static const String verifyOtp = 'verify-otp';
  static const String resetPassword = 'reset-password';

  // Location endpoints
  static const String locations = 'locations';

  // Currency endpoints
  static const String setCurrency = 'set-currency';

  // Product endpoints
  static const String home = ''; // Home API endpoint (root)
  static const String productDetail = 'product/';
  static const String categories = 'categories';

  // Referral endpoints
  static const String referralInfo = 'referral-info/';
  static const String referFriend = 'refer-friend';
  static const String cartReferFriend = 'cart/refer-friend';

  // Cart endpoints
  static const String cart = 'cart';
  static const String checkout = 'checkout';
  static const String addShippingAddress = 'add-new-shipping-adress';
  static const String addressStore = 'address/store';

  // Order endpoints
  static const String orders = 'orders';

  // Dashboard endpoint
  static const String dashboard = 'dashboard';

  // Leaderboard endpoints
  static const String blackBoard = 'black-board';

  // Dropshipping Product endpoints
  static const String dropshippingProduct = 'dropshipping-product';

  // Vendor Product endpoints
  static const String vendorProduct = 'vendor-product';

  // Wallet endpoints
  static const String wallet = 'wallet';
  static const String walletCreateOrder = 'wallet/create-order';
  static const String walletWithdraw = 'wallet/withdraw';
  static const String walletSendMoney = 'wallet/send-money';

  // App Assets endpoint
  static const String appAssets = 'app-assets';

  // Pointer Link endpoint
  static const String pointerLink = 'pointer-link';
}
