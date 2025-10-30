class Product {
  final int id;
  final String name;
  final String slug;
  final double price;
  final String currencySymbol;
  final double? referrerCommission;
  final String? shareLink;
  final String? categoryName;
  final String? shortDescription;
  final String? description;
  final int minBuyingQty;
  final List<ShippingInfo> shippingAvailable;
  final Map<String, String> medias;
  final String? thumbnail;
  final String? status; // e.g., active/inactive for dropshipping
  final String? productType; // e.g., Point Web Product

  Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.currencySymbol,
    this.referrerCommission,
    this.shareLink,
    this.categoryName,
    this.shortDescription,
    this.description,
    required this.minBuyingQty,
    required this.shippingAvailable,
    required this.medias,
    this.thumbnail,
    this.status,
    this.productType,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Extract medias map
    Map<String, String> medias = {};
    String? thumbnail;

    if (json['medias'] != null) {
      if (json['medias'] is Map) {
        medias = Map<String, String>.from(json['medias']);

        // Find thumbnail - it's the one with "thumbnail" in the URL or the first one
        for (var entry in medias.entries) {
          if (entry.value.toString().contains('thumbnail')) {
            thumbnail = entry.value;
            break;
          }
        }
        // If no thumbnail found, use the first media as thumbnail
        if (thumbnail == null && medias.isNotEmpty) {
          thumbnail = medias.values.first;
        }
      }
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currencySymbol: json['currency_symbol'] ?? '\$',
      referrerCommission: json['referrer_commission']?.toDouble(),
      shareLink: json['share_link'],
      categoryName: json['category_name'],
      shortDescription: json['short_description'],
      description: json['description'],
      minBuyingQty: json['min_buying_qty'] ?? 1,
      shippingAvailable:
          (json['shipping_available'] as List?)
              ?.map((item) => ShippingInfo.fromJson(item))
              .toList() ??
          [],
      medias: medias,
      thumbnail: thumbnail ?? json['thumbnail'],
      status: json['status'],
      productType: json['product_type'] ?? json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'price': price,
      'currency_symbol': currencySymbol,
      'referrer_commission': referrerCommission,
      'share_link': shareLink,
      'category_name': categoryName,
      'short_description': shortDescription,
      'description': description,
      'min_buying_qty': minBuyingQty,
      'shipping_available': shippingAvailable
          .map((item) => item.toJson())
          .toList(),
      'medias': medias,
      'thumbnail': thumbnail,
      'status': status,
      'product_type': productType,
    };
  }

  String get formattedPrice => '$currencySymbol${price.toStringAsFixed(0)}';
  String get formattedCommission => referrerCommission != null
      ? '$currencySymbol${referrerCommission!.toStringAsFixed(0)}'
      : '${currencySymbol}0';

  String? get firstImage {
    if (thumbnail != null) {
      return thumbnail;
    }
    if (medias.isNotEmpty) {
      return medias.values.first;
    }
    return null;
  }
}

class ShippingInfo {
  final String flag;
  final String countryName;
  final String shippingTime;
  final String timeType;

  ShippingInfo({
    required this.flag,
    required this.countryName,
    required this.shippingTime,
    required this.timeType,
  });

  factory ShippingInfo.fromJson(Map<String, dynamic> json) {
    return ShippingInfo(
      flag: json['flag'] ?? '',
      countryName: json['country_name'] ?? '',
      shippingTime: json['shipping_time'] ?? '',
      timeType: json['time_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flag': flag,
      'country_name': countryName,
      'shipping_time': shippingTime,
      'time_type': timeType,
    };
  }
}
