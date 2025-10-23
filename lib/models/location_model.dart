class Location {
  final int id;
  final String name;
  final String? code;
  final int? parentId;
  final String? type; // country, state, city
  final String? flag; // for countries
  final String? currency;
  final String? currencySymbol;
  final String? phoneCode;
  final String? status;
  final String createdAt;
  final String updatedAt;

  Location({
    required this.id,
    required this.name,
    this.code,
    this.parentId,
    this.type,
    this.flag,
    this.currency,
    this.currencySymbol,
    this.phoneCode,
    this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      parentId: json['parent_id'],
      type: json['type'],
      flag: json['flag'],
      currency: json['currency'],
      currencySymbol: json['currency_symbol'],
      phoneCode: json['phone_code'],
      status: json['status'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'parent_id': parentId,
      'type': type,
      'flag': flag,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'phone_code': phoneCode,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isCountry => type == 'country' || parentId == null;
  bool get isState =>
      type == 'state' || (parentId != null && name.contains('State'));
  bool get isCity =>
      type == 'city' || (parentId != null && !name.contains('State'));
}

class Country extends Location {
  final String? flag;
  final String? currency;
  final String? currencySymbol;
  final String? phoneCode;

  Country({
    required int id,
    required String name,
    String? code,
    String? status,
    required String createdAt,
    required String updatedAt,
    this.flag,
    this.currency,
    this.currencySymbol,
    this.phoneCode,
  }) : super(
         id: id,
         name: name,
         code: code,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
         type: 'country',
       );

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      status: json['status'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      flag: json['flag'],
      currency: json['currency'],
      currencySymbol: json['currency_symbol'],
      phoneCode: json['phone_code'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'flag': flag,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'phone_code': phoneCode,
    };
  }
}

class State extends Location {
  final int countryId;

  State({
    required int id,
    required String name,
    required this.countryId,
    String? code,
    String? status,
    required String createdAt,
    required String updatedAt,
  }) : super(
         id: id,
         name: name,
         code: code,
         parentId: countryId,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
         type: 'state',
       );

  factory State.fromJson(Map<String, dynamic> json) {
    return State(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      countryId: json['country_id'] ?? json['parent_id'] ?? 0,
      code: json['code'],
      status: json['status'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'country_id': countryId};
  }
}

class City extends Location {
  final int stateId;
  final int countryId;

  City({
    required int id,
    required String name,
    required this.stateId,
    required this.countryId,
    String? code,
    String? status,
    required String createdAt,
    required String updatedAt,
  }) : super(
         id: id,
         name: name,
         code: code,
         parentId: stateId,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
         type: 'city',
       );

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      stateId: json['state_id'] ?? json['parent_id'] ?? 0,
      countryId: json['country_id'] ?? 0,
      code: json['code'],
      status: json['status'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'state_id': stateId, 'country_id': countryId};
  }
}
