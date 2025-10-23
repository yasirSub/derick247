import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/storage_service.dart';

class CartItem {
  final Product product;
  int quantity;
  int? cartItemId; // Store the cart item ID from API

  CartItem({required this.product, this.quantity = 1, this.cartItemId});

  double get total => product.price * quantity;
  String get formattedTotal =>
      '${product.currencySymbol}${total.toStringAsFixed(0)}';
}

class CartProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<CartItem> _cartItems = [];
  bool _isLoading = false;

  List<CartItem> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  bool get isEmpty => _cartItems.isEmpty;
  int get itemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _cartItems.fold(0, (sum, item) => sum + item.total);

  String get formattedTotalAmount {
    if (_cartItems.isEmpty) return '\$0';
    return '${_cartItems.first.product.currencySymbol}${totalAmount.toStringAsFixed(2)}';
  }

  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      final cartData = await _storageService.getCartItems();
      _cartItems = cartData
          .map(
            (item) => CartItem(
              product: Product.fromJson(item['product']),
              quantity: item['quantity'],
            ),
          )
          .toList();
    } catch (e) {
      print('Error loading cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    try {
      print(
        '🛒 CartProvider.addToCart called: ${product.name} (ID: ${product.id}, Qty: $quantity)',
      );
      print('🛒 Current cart items before add: ${_cartItems.length}');

      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (existingIndex != -1) {
        print('🔄 Updating existing item at index $existingIndex');
        _cartItems[existingIndex].quantity += quantity;
      } else {
        print('➕ Adding new item to cart');
        _cartItems.add(CartItem(product: product, quantity: quantity));
      }

      print('🛒 Cart items after add: ${_cartItems.length}');
      for (int i = 0; i < _cartItems.length; i++) {
        print(
          '   Item $i: ${_cartItems[i].product.name} (ID: ${_cartItems[i].product.id}, Qty: ${_cartItems[i].quantity})',
        );
      }

      await _saveCart();
      notifyListeners();
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }

  Future<void> addToCartWithId(
    Product product, {
    int quantity = 1,
    int? cartItemId,
  }) async {
    try {
      print(
        '🛒 CartProvider.addToCartWithId called: ${product.name} (ID: ${product.id}, Qty: $quantity, CartItemId: $cartItemId)',
      );
      print('🛒 Current cart items before add: ${_cartItems.length}');

      // Always add as new item when loading from API
      print('➕ Adding new item to cart with cart item ID');
      _cartItems.add(
        CartItem(product: product, quantity: quantity, cartItemId: cartItemId),
      );

      print('🛒 Cart items after add: ${_cartItems.length}');
      for (int i = 0; i < _cartItems.length; i++) {
        print(
          '   Item $i: ${_cartItems[i].product.name} (ID: ${_cartItems[i].product.id}, Qty: ${_cartItems[i].quantity}, CartItemId: ${_cartItems[i].cartItemId})',
        );
      }

      await _saveCart();
      notifyListeners();
    } catch (e) {
      print('Error adding to cart with ID: $e');
    }
  }

  Future<void> removeFromCart(Product product) async {
    try {
      _cartItems.removeWhere((item) => item.product.id == product.id);
      await _saveCart();
      notifyListeners();
    } catch (e) {
      print('Error removing from cart: $e');
    }
  }

  Future<void> updateQuantity(Product product, int quantity) async {
    try {
      final index = _cartItems.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (index != -1) {
        if (quantity <= 0) {
          _cartItems.removeAt(index);
        } else {
          _cartItems[index].quantity = quantity;
        }
        await _saveCart();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      print('🗑️ Clearing cart - current items: ${_cartItems.length}');
      _cartItems.clear();
      await _storageService.clearCart();
      print('🗑️ Cart cleared - items after clear: ${_cartItems.length}');
      notifyListeners();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final cartData = _cartItems
          .map(
            (item) => {
              'product': item.product.toJson(),
              'quantity': item.quantity,
            },
          )
          .toList();
      await _storageService.saveCartItems(cartData);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  bool isInCart(Product product) {
    return _cartItems.any((item) => item.product.id == product.id);
  }

  int getProductQuantity(Product product) {
    final item = _cartItems.firstWhere(
      (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0),
    );
    return item.quantity;
  }
}
