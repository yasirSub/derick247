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

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  Product? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get sortBy => _sortBy;

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
      
      // Use search API if search query exists
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        response = await _apiService.getProducts(
          page: _currentPage,
          search: _searchQuery,
          category: _selectedCategory,
          sort: _sortBy,
        );
      } else {
        response = await _apiService.getHomeData(page: _currentPage);
      }

      if (response.statusCode == 200) {
        // Handle different response structures
        List<dynamic> dataList = [];
        
        if (response.data['data'] != null) {
          if (response.data['data'] is List) {
            dataList = response.data['data'] as List;
          } else if (response.data['data']['data'] is List) {
            dataList = response.data['data']['data'] as List;
          } else if (response.data['data']['products'] is List) {
            dataList = response.data['data']['products'] as List;
          }
        }
        
        if (dataList.isEmpty && response.data is List) {
          dataList = response.data as List;
        }
        
        print('🛍️ Products loaded: ${dataList.length} items');
        print('🛍️ Response structure: ${response.data.runtimeType}');
        
        final newProducts = dataList.map((item) {
          try {
            return Product.fromJson(item);
          } catch (e) {
            print('❌ Error parsing product: $e');
            print('❌ Product data: $item');
            return null;
          }
        }).whereType<Product>().toList();

        if (refresh) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }

        _currentPage++;
        _hasMore = newProducts.length >= 10; // Assuming 10 items per page
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

  Future<void> loadCategories() async {
    try {
      final response = await _apiService.getCategories();

      if (response.statusCode == 200) {
        final data =
            response.data['data']['data']
                as List; // Fixed: Access nested data structure
        _categories = data.map((item) => Category.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadProductDetail(int productId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔍 Fetching product details for ID: $productId');
      print('🔍 API Endpoint: ${ApiConfig.baseUrl}${ApiConfig.productDetail}$productId');
      
      final response = await _apiService.getProductDetail(productId);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Full Response Data: ${response.data}');
      
      if (response.statusCode == 200) {
        // Check response structure
        if (response.data['data'] != null) {
          print('🔍 Product Data Found: ${response.data['data']}');
          print('🔍 Medias in response: ${response.data['data']['medias']}');
          print('🔍 Description in response: ${response.data['data']['description']}');
          print('🔍 Short Description in response: ${response.data['data']['short_description']}');
          
          _selectedProduct = Product.fromJson(response.data['data']);
          
          print('🔍 Parsed Product Medias Count: ${_selectedProduct?.medias.length ?? 0}');
          print('🔍 Parsed Product Description: ${_selectedProduct?.description}');
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

  void searchProducts(String query) {
    _searchQuery = query.isEmpty ? null : query;
    loadProducts(refresh: true);
  }

  void filterByCategory(String? category) {
    _selectedCategory = category;
    loadProducts(refresh: true);
  }

  void sortProducts(String? sortBy) {
    _sortBy = sortBy;
    loadProducts(refresh: true);
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedCategory = null;
    _sortBy = null;
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
