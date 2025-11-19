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
            final data = error.response?.data;
            final message = (data is Map && data['message'] != null)
                ? data['message'].toString().toLowerCase()
                : '';
            final requiresVerification = message.contains('verify your email');
            if (!requiresVerification) {
              // Only clear token when it's truly invalid/expired
              _authToken = null;
            }
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

  Future<Response> forgotPassword(String email) async {
    final formData = FormData.fromMap({'email': email});
    return await _dio.post(
      ApiConfig.forgotPassword,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<void> confirmEmailVerification(Uri verificationLink) async {
    try {
      final dio = Dio();
      await dio.getUri(
        verificationLink,
        options: Options(
          headers: ApiConfig.jsonHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final formData = FormData.fromMap({'email': email, 'otp': otp});
    return await _dio.post(
      ApiConfig.verifyOtp,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<Response> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    final formData = FormData.fromMap({
      'email': email,
      'otp': otp,
      'password': password,
      'password_confirmation': confirmPassword,
    });
    return await _dio.post(
      ApiConfig.resetPassword,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
  }

  Future<Response> resendVerification({required String email}) async {
    final formData = FormData.fromMap({'email': email});
    return await _dio.post(
      ApiConfig.resendVerification,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
      ),
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
    print('🔗 Fetching product by ID: $productId');
    final url = '${ApiConfig.productDetail}$productId';
    print('🔗 Full URL: ${ApiConfig.baseUrl}$url');
    print('🔑 Auth token available: ${_authToken != null}');

    try {
      // Build headers - include auth token if available (for public browsing, token is optional)
      final headers = Map<String, String>.from(ApiConfig.jsonHeaders);
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
        print('🔑 Sending auth token with request');
      } else {
        print('ℹ️ No auth token - allowing public access to product details');
      }

      final response = await _dio.get(url, options: Options(headers: headers));
      print('✅ Product loaded by ID: Status ${response.statusCode}');
      return response;
    } catch (e) {
      print('❌ Error fetching product by ID $productId: $e');
      rethrow;
    }
  }

  Future<Response> getProductDetailBySlug(String slug) async {
    print('🔗 Fetching product by slug: "$slug"');
    print('   - Slug type: ${slug.runtimeType}');
    print('   - Slug length: ${slug.length}');
    print('🔑 Auth token available: ${_authToken != null}');

    // Clean the slug - remove any trailing slashes or query params
    final cleanSlug = slug.trim().replaceAll(RegExp(r'/$'), '');

    // Build headers - include auth token if available (for public browsing, token is optional)
    final headers = Map<String, String>.from(ApiConfig.jsonHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      print('🔑 Sending auth token with request');
    } else {
      print('ℹ️ No auth token - allowing public access to product details');
    }

    // Try multiple URL formats since browser URL might work differently than API
    final urlFormats = [
      cleanSlug, // As-is (no encoding)
      Uri.encodeComponent(cleanSlug), // Fully encoded
      Uri.encodeFull(cleanSlug), // Path-encoded (keeps / and ?)
    ];

    for (int i = 0; i < urlFormats.length; i++) {
      final url = '${ApiConfig.productDetail}${urlFormats[i]}';
      final fullUrl = '${ApiConfig.baseUrl}$url';
      print('🔗 Attempt ${i + 1}: $fullUrl');

      try {
        final response = await _dio.get(
          url,
          options: Options(
            headers: headers,
            validateStatus: (status) =>
                status != null &&
                status < 600, // Don't throw on 500, we'll check it
          ),
        );

        print('📦 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          print(
            '✅ Product loaded by slug (attempt ${i + 1}): Status ${response.statusCode}',
          );
          return response;
        } else if (response.statusCode == 404) {
          // 404 means endpoint exists but product not found - try next format
          print(
            '⚠️ Product not found (404) with format ${i + 1}, trying next...',
          );
          continue;
        } else if (response.statusCode == 500) {
          // 500 means server error - log the error details
          print('❌ Server error (500) with format ${i + 1}');
          if (response.data != null && response.data is Map) {
            final errorData = response.data as Map;
            print('   Error message: ${errorData['message']}');
            print('   Exception: ${errorData['exception']}');
            print('   File: ${errorData['file']}');
          } else {
            print('   Response data: ${response.data}');
          }

          if (i < urlFormats.length - 1) {
            print('   Trying next URL format...');
            continue;
          } else {
            // Last attempt failed with 500 - include error details in exception
            final errorMessage = response.data != null && response.data is Map
                ? (response.data as Map)['message']?.toString() ??
                      'Server error (500)'
                : 'Server error (500)';

            throw DioException(
              requestOptions: RequestOptions(path: url),
              response: Response(
                requestOptions: RequestOptions(path: url),
                statusCode: 500,
                data: response.data,
              ),
              type: DioExceptionType.badResponse,
              error: errorMessage,
            );
          }
        }
      } catch (e) {
        // Check if it's a 500 error (either from status code or error message)
        final is500Error =
            (e is DioException && e.response?.statusCode == 500) ||
            e.toString().contains('500') ||
            e.toString().contains('shippingAvailable');

        if (is500Error) {
          // If it's a 500, try next format
          if (i < urlFormats.length - 1) {
            print('❌ Server error (500) with format ${i + 1}, trying next...');
            continue;
          }
        }
        // For last attempt, rethrow
        if (i == urlFormats.length - 1) {
          print('❌ All URL format attempts failed. Last error: $e');
          // Include error message in the exception for better detection
          if (e is DioException && e.response?.statusCode == 500) {
            final errorMsg = e.response?.data != null && e.response!.data is Map
                ? (e.response!.data as Map)['message']?.toString() ?? e.message
                : e.message;
            throw DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: errorMsg ?? 'Server error (500)',
            );
          }
          rethrow;
        }
      }
    }

    // Should not reach here, but just in case
    throw Exception('Failed to load product with all URL formats');
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

  // Get guest checkout information by token
  Future<Response> getGuestCheckout(String checkoutToken) async {
    print('🛒 Fetching guest checkout with token: $checkoutToken');

    // Build headers - include auth token if available (optional for guest checkout)
    final headers = Map<String, String>.from(ApiConfig.jsonHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      print('🔑 Sending auth token with guest checkout request');
    } else {
      print('ℹ️ No auth token - guest checkout (public access)');
    }

    // Use checkout-guest endpoint, not checkout endpoint
    final url = 'checkout-guest/$checkoutToken';
    final fullUrl = '${ApiConfig.baseUrl}$url';
    print('🔗 Full URL: $fullUrl');

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: headers,
          validateStatus: (status) =>
              status != null && status < 600, // Don't throw on 500
        ),
      );

      print('📦 Guest checkout response status: ${response.statusCode}');

      if (response.statusCode == 500) {
        // Log server error details
        if (response.data != null && response.data is Map) {
          final errorData = response.data as Map;
          print('❌ Server error (500) details:');
          print('   - Message: ${errorData['message']}');
          print('   - Exception: ${errorData['exception']}');
          print('   - File: ${errorData['file']}');
        }
      }

      return response;
    } catch (e) {
      print('❌ Error fetching guest checkout: $e');
      rethrow;
    }
  }

  // Submit guest checkout
  Future<Response> submitGuestCheckout(
    String checkoutToken,
    Map<String, dynamic> checkoutData,
  ) async {
    print('🛒 Submitting guest checkout with token: $checkoutToken');

    // Build headers - include auth token if available (optional for guest checkout)
    final headers = Map<String, String>.from(ApiConfig.jsonHeaders);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      print('🔑 Sending auth token with guest checkout submission');
    } else {
      print('ℹ️ No auth token - guest checkout (public access)');
    }

    // Add checkout token to the request data
    final requestData = Map<String, dynamic>.from(checkoutData);
    requestData['checkout_token'] = checkoutToken;

    // Use POST to checkout-guest endpoint (not with token in URL)
    final url = 'checkout-guest';
    final fullUrl = '${ApiConfig.baseUrl}$url';
    print('🔗 Full URL: $fullUrl');
    print('📤 Request data: $requestData');

    try {
      final response = await _dio.post(
        url,
        data: requestData,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      print(
        '📦 Guest checkout submission response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Guest checkout submitted successfully');
        if (response.data != null && response.data is Map) {
          final data = response.data as Map;
          print('   - Status: ${data['status']}');
          print('   - Order ID: ${data['order_id']}');
          print('   - PayPal Order ID: ${data['orderID']}');
          print('   - Approval Link: ${data['approvalLink']}');
        }
      }
      return response;
    } catch (e) {
      print('❌ Error submitting guest checkout: $e');
      rethrow;
    }
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
      queryParameters: {'state_id': stateId},
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
        validateStatus: (status) =>
            true, // Accept all status codes for error handling
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
    // Enable debug logging for update operations
    final wasDebugLogging = debugLogging;
    debugLogging = true;

    try {
      print('🔄 [UPDATE PRODUCT] Starting update for product ID: $productId');
      print('   → Endpoint: ${ApiConfig.vendorProduct}');
      print('   → Product ID: $productId');
      print('   → Method: POST with _method: PUT');

      // Log payload keys (excluding file data)
      final payloadKeys = productData.keys.toList();
      print('   → Payload keys: $payloadKeys');

      // Log specific fields for debugging
      if (productData.containsKey('name')) {
        print('   → Name: ${productData['name']}');
      }
      if (productData.containsKey('price')) {
        print('   → Price: ${productData['price']}');
      }
      if (productData.containsKey('category_id')) {
        print('   → Category ID: ${productData['category_id']}');
      }
      if (productData.containsKey('currency')) {
        print('   → Currency: ${productData['currency']}');
      }

      // Add product ID to payload and use _method: PUT
      // Use the same endpoint as create, but include product_id in payload
      final updatePayload = {
        '_method': 'PUT',
        'product_id': productId,
        'id': productId,
        ...productData,
      };

      print(
        '   → Update payload includes: product_id=$productId, id=$productId',
      );

      final formData = FormData.fromMap(updatePayload);

      final response = await _dio.post(
        ApiConfig.vendorProduct, // Same endpoint as create
        data: formData,
        options: Options(
          headers: ApiConfig.formHeaders,
          contentType: Headers.multipartFormDataContentType,
          validateStatus: (status) =>
              true, // Accept all status codes for error handling
        ),
      );

      print('✅ [UPDATE PRODUCT] Response received');
      print('   → Status Code: ${response.statusCode}');
      print('   → Headers: ${response.headers}');

      if (response.data != null) {
        if (response.data is Map) {
          print('   → Response keys: ${(response.data as Map).keys.toList()}');
          if (response.data.containsKey('message')) {
            print('   → Message: ${response.data['message']}');
          }
          if (response.data.containsKey('errors')) {
            print('   → Errors: ${response.data['errors']}');
          }
          if (response.data.containsKey('success')) {
            print('   → Success: ${response.data['success']}');
          }
        } else {
          print('   → Response data type: ${response.data.runtimeType}');
          print(
            '   → Response data: ${response.data.toString().substring(0, response.data.toString().length > 500 ? 500 : response.data.toString().length)}',
          );
        }
      }

      return response;
    } catch (e, stackTrace) {
      print('❌ [UPDATE PRODUCT] Error occurred');
      print('   → Error: $e');
      print('   → Stack trace: $stackTrace');
      rethrow;
    } finally {
      debugLogging = wasDebugLogging;
    }
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
