class ReferralInfo {
  final String currencySymbol;
  final String? referralCode;
  final double earnAmount;
  final String shareLink;
  final int productId;

  ReferralInfo({
    required this.currencySymbol,
    this.referralCode,
    required this.earnAmount,
    required this.shareLink,
    required this.productId,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      currencySymbol: json['currency_symbol'] ?? '\$',
      referralCode: json['referral_code'],
      earnAmount: (json['earn_amount'] ?? 0).toDouble(),
      shareLink: json['share_link'] ?? '',
      productId: json['product_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency_symbol': currencySymbol,
      'referral_code': referralCode,
      'earn_amount': earnAmount,
      'share_link': shareLink,
      'product_id': productId,
    };
  }

  String get formattedEarnAmount =>
      '$currencySymbol${earnAmount.toStringAsFixed(0)}';
}
