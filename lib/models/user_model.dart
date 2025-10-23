class User {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final String? phoneCountryCode;
  final String? firstName;
  final String? lastName;
  final String? emailVerifiedAt;
  final String? googleId;
  final String? facebookId;
  final String status;
  final String currency;
  final String? referredBy;
  final String createdAt;
  final String updatedAt;
  final String? whatsapp;
  final String? whatsappCountryCode;
  final String? address;
  final int? countryId;
  final int? stateId;
  final int? cityId;
  final String role;
  final bool appliedForVendor;
  final String? avatar;
  final List<String> userPermissions;
  final List<String> vendorPermissions;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.phoneCountryCode,
    this.firstName,
    this.lastName,
    this.emailVerifiedAt,
    this.googleId,
    this.facebookId,
    required this.status,
    required this.currency,
    this.referredBy,
    required this.createdAt,
    required this.updatedAt,
    this.whatsapp,
    this.whatsappCountryCode,
    this.address,
    this.countryId,
    this.stateId,
    this.cityId,
    required this.role,
    required this.appliedForVendor,
    this.avatar,
    required this.userPermissions,
    required this.vendorPermissions,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      phoneCountryCode: json['phone_country_code'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      emailVerifiedAt: json['email_verified_at'],
      googleId: json['google_id'],
      facebookId: json['facebook_id'],
      status: json['status'] ?? 'active',
      currency: json['currency'] ?? 'USD',
      referredBy: json['referred_by'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      whatsapp: json['whatsapp'],
      whatsappCountryCode: json['whatsapp_country_code'],
      address: json['address'],
      countryId: json['country_id'],
      stateId: json['state_id'],
      cityId: json['city_id'],
      role: json['role'] ?? 'user',
      appliedForVendor: json['applied_for_vendor'] ?? false,
      avatar: json['avatar'],
      userPermissions: List<String>.from(json['user_permissions'] ?? []),
      vendorPermissions: List<String>.from(json['vendor_permission'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'phone_country_code': phoneCountryCode,
      'first_name': firstName,
      'last_name': lastName,
      'email_verified_at': emailVerifiedAt,
      'google_id': googleId,
      'facebook_id': facebookId,
      'status': status,
      'currency': currency,
      'referred_by': referredBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'whatsapp': whatsapp,
      'whatsapp_country_code': whatsappCountryCode,
      'address': address,
      'country_id': countryId,
      'state_id': stateId,
      'city_id': cityId,
      'role': role,
      'applied_for_vendor': appliedForVendor,
      'avatar': avatar,
      'user_permissions': userPermissions,
      'vendor_permission': vendorPermissions,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (username.isNotEmpty) {
      return username;
    }
    return email;
  }

  bool get isVendor => role == 'vendor' || appliedForVendor;
  bool get isAdmin => role == 'admin';
  bool get isCallCenter => role == 'callcenter';
}
