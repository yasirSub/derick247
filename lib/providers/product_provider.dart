import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';

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
      final response = await _apiService.getHomeData(page: _currentPage);

      if (response.statusCode == 200) {
        final data = response.data['data']['data'] as List;
        final newProducts = data.map((item) => Product.fromJson(item)).toList();

        if (refresh) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }

        _currentPage++;
        _hasMore = newProducts.length == 10; // Assuming 10 items per page
      }
    } catch (e) {
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
      final response = await _apiService.getProductDetail(productId);

      if (response.statusCode == 200) {
        _selectedProduct = Product.fromJson(response.data['data']);
      }
    } catch (e) {
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
