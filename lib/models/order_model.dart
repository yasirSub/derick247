class Order {
  final int id;
  final String orderNumber;
  final double total;
  final String currency;
  final String status;
  final String createdAt;
  final List<OrderItem> items;
  final String? paymentMethod;
  final String? paymentStatus;

  Order({
    required this.id,
    required this.orderNumber,
    required this.total,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.items,
    this.paymentMethod,
    this.paymentStatus,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? json['id'].toString(),
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'total': total,
      'currency': currency,
      'status': status,
      'created_at': createdAt,
      'items': items.map((item) => item.toJson()).toList(),
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
    };
  }

  String get formattedTotal => '$currency ${total.toStringAsFixed(2)}';
}

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double total;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}
