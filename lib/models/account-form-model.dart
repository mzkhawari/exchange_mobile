class CustomerModel {
  // ... فیلدهای قبلی
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountNo': accountNo,
      'branchTitle': branchTitle,
      'accountTypeId': accountTypeId,
      'createDateFa': createDateFa,
      'identityTypeId': identityTypeId,
      'identityNo': identityNo,
      'identityDescription': identityDescription,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'mobileNo': mobileNo,
      'email': email,
      'description': description,
      'countryId': countryId,
      'zoneId': zoneId,
      'provinceId': provinceId,
      'cityName': cityName,
      'address': address,
      'postalCode': postalCode,
      'accountStatus': accountStatus,
      'branchId': branchId,
    };
  }
  
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? 0,
      accountNo: json['accountNo'] ?? 0,
      branchTitle: json['branchTitle'] ?? '',
      accountTypeId: json['accountTypeId'] ?? 0,
      createDateFa: json['createDateFa'] ?? '',
      identityTypeId: json['identityTypeId'] ?? 0,
      identityNo: json['identityNo'] ?? '',
      identityDescription: json['identityDescription'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? 0,
      mobileNo: json['mobileNo'] ?? '',
      email: json['email'] ?? '',
      description: json['description'] ?? '',
      countryId: json['countryId'] ?? 0,
      zoneId: json['zoneId'] ?? 0,
      provinceId: json['provinceId'] ?? 0,
      cityName: json['cityName'] ?? '',
      address: json['address'] ?? '',
      postalCode: json['postalCode'] ?? '',
      accountStatus: json['accountStatus'] ?? 0,
      branchId: json['branchId'] ?? '',
    );
  }
}