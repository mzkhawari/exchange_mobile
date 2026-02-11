class CustomerModel {
  final int id;
  final int accountNo;
  final String branchTitle;
  final int accountTypeId;
  final String createDateFa;
  final int identityTypeId;
  final String identityNo;
  final String identityDescription;
  final String firstName;
  final String lastName;
  final int gender;
  final String mobileNo;
  final String email;
  final String description;
  final int countryId;
  final int zoneId;
  final int provinceId;
  final String cityName;
  final String address;
  final String postalCode;
  final int accountStatus;
  final String branchId;

  const CustomerModel({
    required this.id,
    required this.accountNo,
    required this.branchTitle,
    required this.accountTypeId,
    required this.createDateFa,
    required this.identityTypeId,
    required this.identityNo,
    required this.identityDescription,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.mobileNo,
    required this.email,
    required this.description,
    required this.countryId,
    required this.zoneId,
    required this.provinceId,
    required this.cityName,
    required this.address,
    required this.postalCode,
    required this.accountStatus,
    required this.branchId,
  });
  
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