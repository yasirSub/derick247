class ReferralInfo {
  final int id;
  final int productId;
  final String productName;
  final double commission;
  final String currency;
  final String? shareLink;
  final String? qrCode;
  final String? description;
  final String createdAt;
  final String updatedAt;

  ReferralInfo({
    required this.id,
    required this.productId,
    required this.productName,
    required this.commission,
    required this.currency,
    this.shareLink,
    this.qrCode,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      commission: (json['commission'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      shareLink: json['share_link'],
      qrCode: json['qr_code'],
      description: json['description'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'commission': commission,
      'currency': currency,
      'share_link': shareLink,
      'qr_code': qrCode,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get formattedCommission =>
      '$currency ${commission.toStringAsFixed(2)}';
}

class ReferralFriend {
  final int id;
  final String friendName;
  final String friendPhone;
  final String friendStatus;
  final String? notes;
  final int productId;
  final String productName;
  final String status;
  final String createdAt;
  final String updatedAt;

  ReferralFriend({
    required this.id,
    required this.friendName,
    required this.friendPhone,
    required this.friendStatus,
    this.notes,
    required this.productId,
    required this.productName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReferralFriend.fromJson(Map<String, dynamic> json) {
    return ReferralFriend(
      id: json['id'] ?? 0,
      friendName: json['friend_name'] ?? '',
      friendPhone: json['friend_phone'] ?? '',
      friendStatus: json['friend_status'] ?? 'not_ready',
      notes: json['notes'],
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friend_name': friendName,
      'friend_phone': friendPhone,
      'friend_status': friendStatus,
      'notes': notes,
      'product_id': productId,
      'product_name': productName,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get statusDisplayText {
    switch (friendStatus) {
      case 'not_ready':
        return 'Not Ready';
      case 'need_significant_work':
        return 'Need Significant Work';
      case 'almost_ready':
        return 'Almost Ready';
      case 'completely_ready':
        return 'Completely Ready';
      default:
        return 'Unknown';
    }
  }
}
