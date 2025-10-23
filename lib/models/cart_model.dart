class Cart {
  final int id;
  final int userId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double total;
  final String? productImage;
  final String? productSlug;
  final String currency;
  final String createdAt;
  final String updatedAt;

  Cart({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
    this.productImage,
    this.productSlug,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      total: (json['total'] ?? 0).toDouble(),
      productImage: json['product_image'],
      productSlug: json['product_slug'],
      currency: json['currency'] ?? 'USD',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
      'product_image': productImage,
      'product_slug': productSlug,
      'currency': currency,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get formattedPrice => '$currency ${price.toStringAsFixed(2)}';
  String get formattedTotal => '$currency ${total.toStringAsFixed(2)}';
}

class CartSummary {
  final int totalItems;
  final double totalAmount;
  final String currency;
  final List<Cart> items;

  CartSummary({
    required this.totalItems,
    required this.totalAmount,
    required this.currency,
    required this.items,
  });

  factory CartSummary.fromJson(Map<String, dynamic> json) {
    return CartSummary(
      totalItems: json['total_items'] ?? 0,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      items:
          (json['items'] as List?)
              ?.map((item) => Cart.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_items': totalItems,
      'total_amount': totalAmount,
      'currency': currency,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  String get formattedTotal => '$currency ${totalAmount.toStringAsFixed(2)}';
}
