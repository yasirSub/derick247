import 'package:intl/intl.dart';

class BlackBoardEntry {
  final int productId;
  final String productName;
  final String? category;
  final double commission;
  final String currencySymbol;
  final String? imageUrl;
  final String? shareLink;
  final String? checkoutLink;

  BlackBoardEntry({
    required this.productId,
    required this.productName,
    required this.commission,
    required this.currencySymbol,
    this.category,
    this.imageUrl,
    this.shareLink,
    this.checkoutLink,
  });

  factory BlackBoardEntry.fromJson(Map<String, dynamic> json) {
    final rawCommission = json['referrer_commission'] ?? json['commission'];
    final commissionValue = _parseToDouble(rawCommission);

    return BlackBoardEntry(
      productId: _parseToInt(json['product_id'] ?? json['id']),
      productName: (json['product_name'] ?? json['name'] ?? '').toString(),
      category: (json['category'] ?? json['category_name'])?.toString(),
      commission: commissionValue,
      currencySymbol: (json['currency_symbol'] ?? '  ').toString(),
      imageUrl: (json['thumbnail'] ?? json['image'])?.toString(),
      shareLink: json['share_link']?.toString(),
      checkoutLink: json['check_out_link']?.toString(),
    );
  }

  static double _parseToDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String get formattedCommission {
    final trimmedSymbol = currencySymbol.trim();
    final symbol = trimmedSymbol.isEmpty || trimmedSymbol == '\u001a'
        ? 'L'
        : trimmedSymbol;
    final formatter = NumberFormat('#,##0.00');
    final formattedValue = formatter.format(commission);
    return symbol.isEmpty ? formattedValue : '$symbol $formattedValue';
  }
}
