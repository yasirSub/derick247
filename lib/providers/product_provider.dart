import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<Category> _categories = [];
  Product? _selectedProduct;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _searchQuery;
  String? _selectedCategory;
  String? _sortBy;

  // Category pagination state
  int _currentCategoryPage = 1;
  bool _hasMoreCategories = true;
  bool _isLoadingCategories = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  Product? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get sortBy => _sortBy;
  bool get isLoadingCategories => _isLoadingCategories;
  bool get hasMoreCategories => _hasMoreCategories;

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _products.clear();
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response response;

      print('🛍️ [PRODUCT_PROVIDER] loadProducts called:');
      print('   → refresh: $refresh');
      print('   → _currentPage: $_currentPage');
      print('   → _searchQuery: $_searchQuery');
      print('   → _selectedCategory: $_selectedCategory');
      print('   → _sortBy: $_sortBy');

      // Use getProducts API if we have search query OR category filter OR sort
      // IMPORTANT: When searching in a category, BOTH search and category must be passed
      if (_searchQuery != null && _searchQuery!.isNotEmpty ||
          _selectedCategory != null ||
          _sortBy != null) {
        print('   → Using getProducts API (has search/category/sort filter)');
        print('   → API call parameters:');
        print('      • page: $_currentPage');
        print('      • search: $_searchQuery');
        print('      • category (as categories): $_selectedCategory');
        print('      • sort: $_sortBy');
        print(
          '   → ⚠️  CRITICAL: Category filter MUST be included when searching in category!',
        );

        // Ensure category is ALWAYS passed when it's set, even during search
        response = await _apiService.getProducts(
          page: _currentPage,
          search: _searchQuery,
          category:
              _selectedCategory, // This MUST be included if we're in a category
          sort: _sortBy,
        );
        print('   → API Response Status: ${response.statusCode}');
        print(
          '   → API Response Data Count: ${response.data['data']?['data']?.length ?? response.data['data']?.length ?? 0}',
        );
      } else {
        print('   → Using getHomeData API (no filters)');
        print('   → API call parameters:');
        print('      • page: $_currentPage');
        response = await _apiService.getHomeData(page: _currentPage);
        print('   → API Response Status: ${response.statusCode}');
        print(
          '   → API Response Data Count: ${response.data['data']?['data']?.length ?? response.data['data']?.length ?? 0}',
        );
      }

      if (response.statusCode == 200) {
        // Handle different response structures
        List<dynamic> dataList = [];
        Map<String, dynamic>? paginationData;

        if (response.data['data'] != null) {
          if (response.data['data'] is List) {
            dataList = response.data['data'] as List;
          } else if (response.data['data']['data'] is List) {
            dataList = response.data['data']['data'] as List;
            // Extract pagination metadata
            paginationData = response.data['data'] as Map<String, dynamic>?;
          } else if (response.data['data']['products'] is List) {
            dataList = response.data['data']['products'] as List;
            paginationData = response.data['data'] as Map<String, dynamic>?;
          }
        }

        if (dataList.isEmpty && response.data is List) {
          dataList = response.data as List;
        }

        print('🛍️ Products loaded: ${dataList.length} items');
        print('🛍️ Response structure: ${response.data.runtimeType}');

        final newProducts = dataList
            .map((item) {
              try {
                return Product.fromJson(item);
              } catch (e) {
                print('❌ Error parsing product: $e');
                print('❌ Product data: $item');
                return null;
              }
            })
            .whereType<Product>()
            .toList();

        if (refresh) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }

        // Check pagination metadata to determine if there are more pages
        if (paginationData != null) {
          // Check if next_page_url exists and is not null
          final nextPageUrl = paginationData['next_page_url'];
          if (nextPageUrl != null) {
            _hasMore = true;
          } else {
            // Fallback: compare current_page with last_page
            final currentPage = paginationData['current_page'] as int?;
            final lastPage = paginationData['last_page'] as int?;
            if (currentPage != null && lastPage != null) {
              _hasMore = currentPage < lastPage;
            } else {
              // If no pagination metadata, check if we got a full page
              _hasMore = newProducts.length >= 10;
            }
          }
        } else {
          // Fallback: if no pagination metadata, check if we got a full page
          _hasMore = newProducts.length >= 10;
        }

        _currentPage++;
      } else {
        print('❌ API returned status: ${response.statusCode}');
        print('❌ Response: ${response.data}');
      }
    } catch (e) {
      print('❌ Error loading products: $e');
      if (e is DioException) {
        print('❌ DioException details:');
        print('  - Response: ${e.response?.data}');
        print('  - Status: ${e.response?.statusCode}');
        print('  - Message: ${e.message}');
      }
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories({bool refresh = false}) async {
    if (refresh) {
      _currentCategoryPage = 1;
      _categories.clear();
      _hasMoreCategories = true;
    }

    if (_isLoadingCategories || !_hasMoreCategories) return;

    _isLoadingCategories = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getCategories(
        page: _currentCategoryPage,
      );

      if (response.statusCode == 200) {
        // Handle different response structures
        List<dynamic> dataList = [];
        Map<String, dynamic>? paginationData;

        if (response.data['data'] != null) {
          if (response.data['data'] is List) {
            dataList = response.data['data'] as List;
          } else if (response.data['data']['data'] is List) {
            dataList = response.data['data']['data'] as List;
            // Extract pagination metadata
            paginationData = response.data['data'] as Map<String, dynamic>?;
          }
        }

        if (dataList.isEmpty && response.data is List) {
          dataList = response.data as List;
        }

        print('📂 Categories loaded: ${dataList.length} items');

        final newCategories = dataList
            .map((item) {
              try {
                return Category.fromJson(item);
              } catch (e) {
                print('❌ Error parsing category: $e');
                print('❌ Category data: $item');
                return null;
              }
            })
            .whereType<Category>()
            .toList();

        if (refresh) {
          _categories = newCategories;
        } else {
          _categories.addAll(newCategories);
        }

        // Check pagination metadata to determine if there are more pages
        if (paginationData != null) {
          // Check if next_page_url exists and is not null
          final nextPageUrl = paginationData['next_page_url'];
          if (nextPageUrl != null) {
            _hasMoreCategories = true;
          } else {
            // Fallback: compare current_page with last_page
            final currentPage = paginationData['current_page'] as int?;
            final lastPage = paginationData['last_page'] as int?;
            if (currentPage != null && lastPage != null) {
              _hasMoreCategories = currentPage < lastPage;
            } else {
              // If no pagination metadata, check if we got a full page
              _hasMoreCategories = newCategories.length >= 10;
            }
          }
        } else {
          // Fallback: if no pagination metadata, check if we got a full page
          _hasMoreCategories = newCategories.length >= 10;
        }

        _currentCategoryPage++;
      } else {
        print('❌ Categories API returned status: ${response.statusCode}');
        print('❌ Response: ${response.data}');
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
      if (e is DioException) {
        print('❌ DioException details:');
        print('  - Response: ${e.response?.data}');
        print('  - Status: ${e.response?.statusCode}');
        print('  - Message: ${e.message}');
      }
      _error = e.toString();
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadProductDetail(int productId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔍 Fetching product details for ID: $productId');
      print(
        '🔍 API Endpoint: ${ApiConfig.baseUrl}${ApiConfig.productDetail}$productId',
      );

      final response = await _apiService.getProductDetail(productId);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Full Response Data: ${response.data}');

      if (response.statusCode == 200) {
        // Check response structure
        if (response.data['data'] != null) {
          print('🔍 Product Data Found: ${response.data['data']}');
          print('🔍 Medias in response: ${response.data['data']['medias']}');
          print(
            '🔍 Description in response: ${response.data['data']['description']}',
          );
          print(
            '🔍 Short Description in response: ${response.data['data']['short_description']}',
          );
          print('🏳️ Flag in response: ${response.data['data']['flag']}');

          _selectedProduct = Product.fromJson(response.data['data']);

          print(
            '🔍 Parsed Product Medias Count: ${_selectedProduct?.medias.length ?? 0}',
          );
          print(
            '🔍 Parsed Product Description: ${_selectedProduct?.description}',
          );
          print('🏳️ Parsed Product Flag: ${_selectedProduct?.flag}');
        } else {
          print('❌ No data field in response');
          _error = 'Product data not found';
        }
      } else {
        print('❌ API returned status: ${response.statusCode}');
        _error = 'Failed to load product details';
      }
    } catch (e) {
      print('❌ Error loading product detail: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProductDetailBySlug(String slug) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔍 Fetching product details for slug: $slug');
      print(
        '🔍 API Endpoint: ${ApiConfig.baseUrl}${ApiConfig.productDetail}$slug',
      );

      final response = await _apiService.getProductDetailBySlug(slug);

      print('🔍 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.data['data'] != null) {
          final productData = response.data['data'];
          print(
            '🏳️ Product data flag (loadProductDetailBySlug): ${productData['flag']}',
          );
          _selectedProduct = Product.fromJson(productData);
          print(
            '🏳️ Parsed product flag (loadProductDetailBySlug): ${_selectedProduct?.flag}',
          );
          _error = null;
        } else {
          _error = 'Product data not found';
        }
      } else {
        _error = 'Failed to load product details';
      }
    } catch (e) {
      print('❌ Error loading product by slug: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load product by identifier - tries ID first, then slug if ID fails
  Future<void> loadProductDetailByIdentifier(String identifier) async {
    print('🔍 loadProductDetailByIdentifier called with: "$identifier"');
    print('   - Identifier length: ${identifier.length}');
    print('   - Identifier type: ${identifier.runtimeType}');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First, try to parse as numeric ID
      final productId = int.tryParse(identifier);

      if (productId != null) {
        // Try loading by ID first
        print('🔍 Trying to load product by ID: $productId');
        try {
          // Call the internal method directly to avoid double loading state
          final response = await _apiService.getProductDetail(productId);
          print('📦 Response status: ${response.statusCode}');
          print('📦 Response data keys: ${response.data.keys}');

          if (response.statusCode == 200) {
            if (response.data['data'] != null) {
              final productData = response.data['data'];
              print('✅ Product data found (ID): ${productData['id'] ?? 'N/A'}');
              print('🏳️ Product data flag (ID): ${productData['flag']}');
              _selectedProduct = Product.fromJson(productData);
              print('🏳️ Parsed product flag (ID): ${_selectedProduct?.flag}');
              _error = null;
              _isLoading = false;
              notifyListeners();
              return; // Success!
            } else {
              print('⚠️ Response data is null, will try as slug');
            }
          } else {
            print(
              '⚠️ Failed to load by ID (status: ${response.statusCode}), will try as slug',
            );
            print('   Response: ${response.data}');
          }
        } catch (e) {
          print('⚠️ Exception loading by ID, will try as slug: $e');
          print('   Error type: ${e.runtimeType}');
          // If it's a 500 error on ID, still try slug
          if (!e.toString().contains('500') &&
              !e.toString().contains('Server error')) {
            // If it's not a server error, rethrow immediately
            rethrow;
          }
        }
      }

      // If ID approach failed or identifier is not numeric, try as slug
      print('🔍 Trying to load product by slug: "$identifier"');
      print('   - Slug length: ${identifier.length}');
      print('   - Slug contains spaces: ${identifier.contains(" ")}');
      print(
        '   - Slug contains special chars: ${identifier.contains(RegExp(r'[^a-zA-Z0-9\-_]'))}',
      );

      try {
        // First, try direct slug API call
        print('🔄 Trying direct slug API call...');
        final response = await _apiService.getProductDetailBySlug(identifier);
        print('📦 Slug response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          if (response.data['data'] != null) {
            final productData = response.data['data'];
            print('✅ Product data found (slug): ${productData['id'] ?? 'N/A'}');
            print('🏳️ Product data flag (slug): ${productData['flag']}');
            _selectedProduct = Product.fromJson(productData);
            print('🏳️ Parsed product flag (slug): ${_selectedProduct?.flag}');
            _error = null;
          } else {
            _error = 'Product data not found in response';
            print('⚠️ Product response data is null');
            print('   Response structure: ${response.data.keys}');
          }
        } else {
          _error = 'Failed to load product (Status: ${response.statusCode})';
          print('❌ Product API returned status: ${response.statusCode}');
          print('   Response: ${response.data}');
          // Check if server returned an error message
          if (response.data['message'] != null) {
            _error = response.data['message'].toString();
          }
        }
      } catch (slugError) {
        print('❌ Error loading product by slug: $slugError');
        print('   Error details: ${slugError.toString()}');

        // Check if it's a 500 error (server-side bug)
        final is500Error =
            slugError.toString().contains('500') ||
            slugError.toString().contains('Server error') ||
            slugError.toString().contains('shippingAvailable');

        // If slug lookup fails with 500, try to find the product in the products list as fallback
        if (is500Error) {
          print(
            '🔄 Slug API returned 500 (server bug detected). Trying products list fallback...',
          );
          try {
            // Load products list and search for matching slug
            // Try with larger limit to find the product
            final productsResponse = await _apiService.getProducts(
              limit: 200,
            ); // Get more products
            if (productsResponse.statusCode == 200 &&
                productsResponse.data['data'] != null) {
              // Handle different response structures (same as loadProducts method)
              List<dynamic> productsList = [];

              if (productsResponse.data['data'] is List) {
                productsList = productsResponse.data['data'] as List;
              } else if (productsResponse.data['data'] is Map) {
                final dataMap = productsResponse.data['data'] as Map;
                if (dataMap['data'] is List) {
                  productsList = dataMap['data'] as List;
                } else if (dataMap['products'] is List) {
                  productsList = dataMap['products'] as List;
                }
              }

              if (productsList.isNotEmpty) {
                print(
                  '📋 Searching ${productsList.length} products for slug: "$identifier"',
                );

                // Search for product by slug in the list
                for (var productData in productsList) {
                  // Ensure productData is a Map
                  if (productData is! Map<String, dynamic>) continue;

                  final productSlug = productData['slug']?.toString() ?? '';
                  final productId = productData['id']?.toString();

                  // Try exact match first
                  if (productSlug.toLowerCase() == identifier.toLowerCase() ||
                      productId == identifier) {
                    print(
                      '✅ Found product in list: ID=${productData['id']}, slug=$productSlug',
                    );
                    // Load full details by ID instead (this should work)
                    final foundId = productData['id'] as int?;
                    if (foundId != null) {
                      try {
                        print('🔄 Loading product details by ID: $foundId');
                        final detailResponse = await _apiService
                            .getProductDetail(foundId);
                        if (detailResponse.statusCode == 200 &&
                            detailResponse.data['data'] != null) {
                          _selectedProduct = Product.fromJson(
                            detailResponse.data['data'],
                          );
                          _error = null;
                          _isLoading = false;
                          notifyListeners();
                          print(
                            '✅ Product loaded successfully via fallback (by ID)',
                          );
                          return; // Success!
                        }
                      } catch (idError) {
                        print(
                          '⚠️ Failed to load product by found ID: $idError',
                        );
                      }
                    }
                  }
                }

                // Try partial match if exact match failed
                print('⚠️ Exact match not found. Trying partial match...');
                for (var productData in productsList) {
                  // Ensure productData is a Map
                  if (productData is! Map<String, dynamic>) continue;

                  final productSlug = productData['slug']?.toString() ?? '';
                  if (productSlug.toLowerCase().contains(
                        identifier.toLowerCase(),
                      ) ||
                      identifier.toLowerCase().contains(
                        productSlug.toLowerCase(),
                      )) {
                    print(
                      '✅ Found similar product: ID=${productData['id']}, slug=$productSlug',
                    );
                    final foundId = productData['id'] as int?;
                    if (foundId != null) {
                      try {
                        final detailResponse = await _apiService
                            .getProductDetail(foundId);
                        if (detailResponse.statusCode == 200 &&
                            detailResponse.data['data'] != null) {
                          _selectedProduct = Product.fromJson(
                            detailResponse.data['data'],
                          );
                          _error = null;
                          _isLoading = false;
                          notifyListeners();
                          print('✅ Product loaded via partial match fallback');
                          return;
                        }
                      } catch (idError) {
                        print(
                          '⚠️ Failed to load product by partial match ID: $idError',
                        );
                      }
                    }
                  }
                }

                print(
                  '⚠️ Product not found in products list (checked ${productsList.length} products)',
                );
              } else {
                print('⚠️ Products list is empty or invalid structure');
              }
            }
          } catch (listError) {
            print('⚠️ Failed to load products list for fallback: $listError');
          }

          // If fallback also failed, set error message
          _error =
              'Server error: Unable to load product. Please try again later or contact support.';
        } else if (slugError.toString().contains('404')) {
          _error =
              'Product not found. The product may have been removed or the link is invalid.';
        } else if (slugError.toString().contains('timeout')) {
          _error =
              'Request timed out. Please check your connection and try again.';
        } else {
          _error = 'Failed to load product: ${slugError.toString()}';
        }

        // Don't throw - let the error be shown in UI
        // The error is already set above
      }
    } catch (e) {
      print('❌ Top-level error in loadProductDetailByIdentifier: $e');
      // Only set error if it's not already set
      if (_error == null) {
        if (e.toString().contains('500') ||
            e.toString().contains('Server error')) {
          _error = 'Server error loading product. Please try again later.';
        } else if (e.toString().contains('404') ||
            e.toString().contains('Not found')) {
          _error = 'Product not found. Please check the link and try again.';
        } else {
          _error = 'Failed to load product: ${e.toString()}';
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      print(
        '📊 Final state - isLoading: $_isLoading, error: $_error, product: ${_selectedProduct != null ? "loaded" : "null"}',
      );
    }
  }

  void searchProducts(String query) {
    _searchQuery = query.isEmpty ? null : query;
    print('🔍 [PRODUCT_PROVIDER] searchProducts called:');
    print('   → Search query: $_searchQuery');
    print('   → Category filter (MUST be preserved): $_selectedCategory');
    print(
      '   → ⚠️  IMPORTANT: If category is set, search will ONLY show products in that category!',
    );

    // Ensure category filter is preserved when searching
    if (_selectedCategory != null) {
      print(
        '   → ✅ Category filter is set - search will be scoped to category $_selectedCategory',
      );
    } else {
      print('   → ℹ️  No category filter - search will show all products');
    }

    loadProducts(refresh: true);
  }

  void clearSearchOnly() {
    print('🔍 [PRODUCT_PROVIDER] clearSearchOnly called:');
    print('   → Clearing searchQuery: $_searchQuery');
    print('   → Preserving category filter: $_selectedCategory');
    _searchQuery = null;
    loadProducts(refresh: true);
  }

  void filterByCategory(String? category) {
    print('🔍 [PRODUCT_PROVIDER] filterByCategory called:');
    print('   → Category filter: $category');
    print('   → Type: ${category.runtimeType}');
    _selectedCategory = category;
    print('   → _selectedCategory set to: $_selectedCategory');
    print('   → Calling loadProducts(refresh: true)');
    loadProducts(refresh: true);
  }

  void sortProducts(String? sortBy) {
    _sortBy = sortBy;
    loadProducts(refresh: true);
  }

  void clearFilters() {
    print('🧹 [PRODUCT_PROVIDER] clearFilters called:');
    print('   → Clearing searchQuery: $_searchQuery');
    print('   → Clearing selectedCategory: $_selectedCategory');
    print('   → Clearing sortBy: $_sortBy');
    _searchQuery = null;
    _selectedCategory = null;
    _sortBy = null;
    // Reset to page 1 to use base URL without parameters
    _currentPage = 1;
    print(
      '   → All filters cleared, reset to page 1, loading base products (NO query parameters)',
    );
    loadProducts(refresh: true);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<Product> get filteredProducts {
    List<Product> filtered = _products;

    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      filtered = filtered
          .where(
            (product) =>
                product.name.toLowerCase().contains(
                  _searchQuery!.toLowerCase(),
                ) ||
                (product.description?.toLowerCase().contains(
                      _searchQuery!.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where(
            (product) =>
                product.categoryName?.toLowerCase() ==
                _selectedCategory!.toLowerCase(),
          )
          .toList();
    }

    return filtered;
  }
}
