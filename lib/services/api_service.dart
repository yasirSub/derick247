import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Enable to print detailed request/response logs for debugging connectivity
  static bool debugLogging = false;

  late Dio _dio;
  String? _authToken;

  void initialize() {
    // Ensure baseUrl is treated as a directory by ending with '/'
    final normalizedBaseUrl = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl
        : '${ApiConfig.baseUrl}/';

    _dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        headers: ApiConfig.jsonHeaders,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // LogInterceptor removed to reduce console noise
    // Uncomment below if you need to debug API calls:
    // _dio.interceptors.add(
    //   LogInterceptor(requestBody: false, responseBody: false, error: true),
    // );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          if (debugLogging) {
            try {
              final uri = options.uri;
              print('🌐 [API REQUEST]');
              print('   → ${options.method} $uri');
              print('   → baseUrl: ${_dio.options.baseUrl}');
              print('   → headers: ${options.headers}');
              print('   → contentType: ${options.contentType}');
              if (options.data is FormData) {
                final fields = (options.data as FormData).fields
                    .map((e) => e.key)
                    .toList();
                print('   → form fields: $fields');
              } else if (options.data != null) {
                // Avoid printing secrets; print type and size
                final dataStr = options.data.toString();
                final preview = dataStr.length > 300
                    ? '${dataStr.substring(0, 300)}...'
                    : dataStr;
                print('   → body: $preview');
              }
            } catch (_) {}
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle common errors
          if (error.response?.statusCode == 401) {
            // Token expired or invalid
            _authToken = null;
          }
          if (debugLogging) {
            try {
              final req = error.requestOptions;
              print('❌ [API ERROR]');
              print('   → ${req.method} ${req.uri}');
              print('   → message: ${error.message}');
              print('   → type: ${error.type}');
              if (error.response != null) {
                print('   → status: ${error.response?.statusCode}');
                print('   → data: ${error.response?.data}');
                print('   → headers: ${error.response?.headers}');
              }
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // Authentication methods
  Future<Response> login(String email, String password) async {
    if (debugLogging) {
      print('🔐 [LOGIN] Starting login request');
      print('   → baseUrl: ${_dio.options.baseUrl}');
      print('   → endpoint: ${ApiConfig.login}');
      print(
        '   → email: ${email.replaceAll(RegExp(r"(^.).*(@.*$)"), r"$1***$2")}',
      );
      print(
        '   → hasApiKeyHeader: ${ApiConfig.formHeaders.containsKey('x-api-key')}',
      );
    }
    final formData = FormData.fromMap({'email': email, 'password': password});

    final resp = await _dio.post(
      ApiConfig.login,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
    if (debugLogging) {
      try {
        print('✅ [LOGIN RESPONSE]');
        print('   → status: ${resp.statusCode}');
        // Avoid dumping huge payload; preview JSON keys
        final data = resp.data;
        if (data is Map) {
          print('   → keys: ${data.keys.toList()}');
          print(
            '   → message: ${data['message'] ?? data['error'] ?? data['status'] ?? data['success']}',
          );
        } else {
          final str = data.toString();
          print(
            '   → dataPreview: ${str.length > 300 ? str.substring(0, 300) + '...' : str}',
          );
        }
      } catch (_) {}
    }
    return resp;
  }

  Future<Response> register(Map<String, dynamic> userData) async {
    final formData = FormData.fromMap(userData);

    return await _dio.post(
      ApiConfig.register,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<Response> logout() async {
    return await _dio.post(
      ApiConfig.logout,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  Future<Response> resendVerification() async {
    return await _dio.post(
      ApiConfig.resendVerification,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  Future<Response> getProfile() async {
    return await _dio.get(ApiConfig.profile);
  }

  // Home API method
  Future<Response> getHomeData({int page = 1}) async {
    final queryParams = {'page': page};
    return await _dio.get(ApiConfig.home, queryParameters: queryParams);
  }

  // Product methods
  Future<Response> getProducts({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
    String? sort,
  }) async {
    final queryParams = {
      'page': page,
      'limit': limit,
      if (category != null) 'category': category,
      if (search != null) 'search': search,
      if (sort != null) 'sort': sort,
    };
    return await _dio.get(ApiConfig.home, queryParameters: queryParams);
  }

  // Dashboard method
  Future<Response> getDashboard() async {
    // Ensure Authorization header is present
    return await _dio.get(
      ApiConfig.dashboard,
      options: Options(
        headers: {
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      ),
    );
  }

  Future<Response> getProductDetail(int productId) async {
    return await _dio.get('${ApiConfig.productDetail}$productId');
  }

  Future<Response> getProductDetailBySlug(String slug) async {
    return await _dio.get('${ApiConfig.productDetail}$slug');
  }

  Future<Response> getCategories() async {
    return await _dio.get(ApiConfig.categories);
  }

  // Subcategories for a given category
  Future<Response> getSubcategories(int categoryId) async {
    return await _dio.get('${ApiConfig.categories}/$categoryId/subcategories');
  }

  // Cart methods
  Future<Response> getCart() async {
    return await _dio.get(ApiConfig.cart);
  }

  Future<Response> addToCart(int productId, int quantity) async {
    final formData = FormData.fromMap({
      'product_id': productId,
      'quantity': quantity,
    });

    return await _dio.post(
      ApiConfig.cart,
      data: formData,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  Future<Response> updateCartItem(int cartItemId, int quantity) async {
    final formData = FormData.fromMap({'_method': 'PUT', 'quantity': quantity});

    return await _dio.post(
      '${ApiConfig.cart}/$cartItemId',
      data: formData,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  Future<Response> removeFromCart(int cartItemId) async {
    return await _dio.delete(
      '${ApiConfig.cart}/$cartItemId',
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Get checkout information
  Future<Response> getCheckout() async {
    return await _dio.get(
      ApiConfig.checkout,
      options: Options(headers: ApiConfig.jsonHeaders),
    );
  }

  // Submit checkout
  Future<Response> checkout(Map<String, dynamic> checkoutData) async {
    final formData = FormData.fromMap(checkoutData);

    return await _dio.post(
      ApiConfig.checkout,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  // Add new shipping address (legacy endpoint)
  Future<Response> addShippingAddress(Map<String, dynamic> addressData) async {
    final formData = FormData.fromMap(addressData);

    return await _dio.post(
      ApiConfig.addShippingAddress,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  // Add new shipping address (new endpoint)
  Future<Response> storeAddress(Map<String, dynamic> addressData) async {
    final formData = FormData.fromMap(addressData);

    return await _dio.post(
      ApiConfig.addressStore,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  // Referral methods
  Future<Response> getReferralInfo(int productId) async {
    return await _dio.get('${ApiConfig.referralInfo}$productId');
  }

  Future<Response> getBlackBoard({int page = 1}) async {
    return await _dio.get(
      ApiConfig.blackBoard,
      queryParameters: {'page': page},
    );
  }

  Future<Response> referFriend(Map<String, dynamic> referralData) async {
    final formData = FormData.fromMap(referralData);

    return await _dio.post(
      ApiConfig.referFriend,
      data: formData,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Cart referral method
  Future<Response> referFriendFromCart(
    Map<String, dynamic> referralData,
  ) async {
    final formData = FormData.fromMap(referralData);

    return await _dio.post(
      ApiConfig.cartReferFriend,
      data: formData,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Order methods
  Future<Response> getOrders({String? search}) async {
    final queryParams = <String, dynamic>{};
    if (search != null) queryParams['search'] = search;

    return await _dio.get(
      ApiConfig.orders,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Future<Response> getOrderDetails(int orderId) async {
    return await _dio.get('${ApiConfig.orders}/$orderId');
  }

  // Location methods
  Future<Response> getCountries() async {
    return await _dio.get(ApiConfig.locations);
  }

  Future<Response> getStates(int countryId) async {
    return await _dio.get(
      ApiConfig.locations,
      queryParameters: {'country_id': countryId},
    );
  }

  Future<Response> getCities(int stateId) async {
    return await _dio.get(
      ApiConfig.locations,
      queryParameters: {'states': stateId},
    );
  }

  // Profile update method
  Future<Response> updateProfile(Map<String, dynamic> profileData) async {
    final formData = FormData.fromMap(profileData);

    return await _dio.post(
      ApiConfig.profile,
      data: formData,
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Dropshipping Product methods
  Future<Response> getDropshippingProducts() async {
    return await _dio.get(ApiConfig.dropshippingProduct);
  }

  Future<Response> addDropshippingProduct(
    Map<String, dynamic> productData,
  ) async {
    final formData = FormData.fromMap(productData);

    return await _dio.post(
      ApiConfig.dropshippingProduct,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
      ),
    );
  }

  Future<Response> getDropshippingProduct(int productId) async {
    return await _dio.get('${ApiConfig.dropshippingProduct}/$productId');
  }

  Future<Response> updateDropshippingProduct(
    int productId,
    Map<String, dynamic> productData,
  ) async {
    final formData = FormData.fromMap({'_method': 'PUT', ...productData});

    return await _dio.post(
      '${ApiConfig.dropshippingProduct}/$productId',
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
      ),
    );
  }

  Future<Response> deleteDropshippingProduct(int productId) async {
    return await _dio.delete(
      '${ApiConfig.dropshippingProduct}/$productId',
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Vendor Product methods
  Future<Response> getVendorProducts() async {
    return await _dio.get(ApiConfig.vendorProduct);
  }

  Future<Response> addVendorProduct(Map<String, dynamic> productData) async {
    final formData = FormData.fromMap(productData);

    return await _dio.post(
      ApiConfig.vendorProduct,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
      ),
    );
  }

  Future<Response> getVendorProduct(int productId) async {
    return await _dio.get('${ApiConfig.vendorProduct}/$productId');
  }

  Future<Response> updateVendorProduct(
    int productId,
    Map<String, dynamic> productData,
  ) async {
    final formData = FormData.fromMap({'_method': 'PUT', ...productData});

    return await _dio.post(
      '${ApiConfig.vendorProduct}/$productId',
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
      ),
    );
  }

  Future<Response> deleteVendorProduct(int productId) async {
    return await _dio.delete(
      '${ApiConfig.vendorProduct}/$productId',
      options: Options(headers: ApiConfig.formHeaders),
    );
  }

  // Currency methods
  // Get currencies from countries (countries API returns currency_code)
  Future<Response> getCurrencies() async {
    // Using locations endpoint to get countries with currencies
    return await _dio.get(ApiConfig.locations);
  }

  Future<Response> setCurrency(String currencyCode) async {
    final formData = FormData.fromMap({'currency': currencyCode});

    return await _dio.post(
      ApiConfig.setCurrency,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  // Wallet methods
  Future<Response> getWallet() async {
    return await _dio.get(
      ApiConfig.wallet,
      options: Options(headers: ApiConfig.jsonHeaders),
    );
  }

  Future<Response> createWalletOrder(Map<String, dynamic> orderData) async {
    final formData = FormData.fromMap(orderData);

    return await _dio.post(
      ApiConfig.walletCreateOrder,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<Response> withdrawFromWallet(Map<String, dynamic> withdrawData) async {
    final formData = FormData.fromMap(withdrawData);

    return await _dio.post(
      ApiConfig.walletWithdraw,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<Response> sendMoney(Map<String, dynamic> sendMoneyData) async {
    final formData = FormData.fromMap(sendMoneyData);

    return await _dio.post(
      ApiConfig.walletSendMoney,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  // Get app assets (banners, logo, etc.)
  Future<Response> getAppAssets() async {
    return await _dio.get(
      ApiConfig.appAssets,
      options: Options(
        headers: ApiConfig.jsonHeaders,
        validateStatus: (status) => true,
      ),
    );
  }

  // Get pointer link (vendor and referrer links)
  Future<Response> getPointerLink() async {
    return await _dio.get(
      ApiConfig.pointerLink,
      options: Options(
        headers: ApiConfig.jsonHeaders,
        validateStatus: (status) => true,
      ),
    );
  }
}
