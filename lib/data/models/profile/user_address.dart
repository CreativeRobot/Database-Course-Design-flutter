class UserAddress {
  const UserAddress({
    required this.id,
    required this.receiverName,
    required this.receiverPhone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
    required this.postalCode,
    required this.defaultAddress,
    this.createTime,
    this.updateTime,
  });

  factory UserAddress.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('\u6536\u8d27\u5730\u5740\u54cd\u5e94\u683c\u5f0f\u4e0d\u6b63\u786e');
    }
    return UserAddress(
      id: (json['id'] as num).toInt(),
      receiverName: json['receiverName'] as String? ?? '',
      receiverPhone: json['receiverPhone'] as String? ?? '',
      province: json['province'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      detailAddress: json['detailAddress'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      defaultAddress: json['defaultAddress'] as bool? ?? false,
      createTime: DateTime.tryParse(json['createTime'] as String? ?? ''),
      updateTime: DateTime.tryParse(json['updateTime'] as String? ?? ''),
    );
  }

  final int id;
  final String receiverName;
  final String receiverPhone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final String postalCode;
  final bool defaultAddress;
  final DateTime? createTime;
  final DateTime? updateTime;

  String get region => [
    province,
    city,
    district,
  ].where((value) => value.trim().isNotEmpty).join(' ');

  String get fullAddress => '$region $detailAddress'.trim();
}

class UserAddressInput {
  const UserAddressInput({
    required this.receiverName,
    required this.receiverPhone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
    required this.postalCode,
    required this.defaultAddress,
  });

  factory UserAddressInput.fromAddress(UserAddress address) {
    return UserAddressInput(
      receiverName: address.receiverName,
      receiverPhone: address.receiverPhone,
      province: address.province,
      city: address.city,
      district: address.district,
      detailAddress: address.detailAddress,
      postalCode: address.postalCode,
      defaultAddress: address.defaultAddress,
    );
  }

  final String receiverName;
  final String receiverPhone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final String postalCode;
  final bool defaultAddress;

  Map<String, dynamic> toJson() {
    return {
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'province': province,
      'city': city,
      'district': district,
      'detailAddress': detailAddress,
      'postalCode': postalCode,
      'defaultAddress': defaultAddress,
    };
  }
}
