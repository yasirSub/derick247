import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _authToken;

  void initialize() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: ApiConfig.jsonHeaders,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle common errors
          if (error.response?.statusCode == 401) {
            // Token expired or invalid
            _authToken = null;
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
    final formData = FormData.fromMap({'email': email, 'password': password});

    return await _dio.post(
      ApiConfig.login,
      data: formData,
      options: Options(
        headers: ApiConfig.formHeaders,
        contentType: Headers.multipartFormDataContentType,
        validateStatus: (status) => true,
      ),
    );
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

  Future<Response> getProductDetail(int productId) async {
    return await _dio.get('${ApiConfig.productDetail}$productId');
  }

  Future<Response> getCategories() async {
    return await _dio.get(ApiConfig.categories);
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

  // Referral methods
  Future<Response> getReferralInfo(int productId) async {
    return await _dio.get('${ApiConfig.referralInfo}$productId');
  }

  Future<Response> referFriend(Map<String, dynamic> referralData) async {
    final formData = FormData.fromMap(referralData);

    return await _dio.post(
      ApiConfig.referFriend,
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
}
