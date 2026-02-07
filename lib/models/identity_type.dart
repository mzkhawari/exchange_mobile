enum IdentityType {
  none, // 0
  nationalId, // 1
  passport, // 2
  driverLicense, // 3
  other, // 4
}

extension IdentityTypeX on IdentityType {
  int get code => switch (this) {
        IdentityType.none => 0,
        IdentityType.nationalId => 1,
        IdentityType.passport => 2,
        IdentityType.driverLicense => 3,
        IdentityType.other => 4,
      };

  String get label => switch (this) {
        IdentityType.none => 'None',
        IdentityType.nationalId => 'NationalId',
        IdentityType.passport => 'Passport',
        IdentityType.driverLicense => 'DriverLicense',
        IdentityType.other => 'Other',
      };

  static IdentityType? fromCode(int? code) {
    switch (code) {
      case 0:
        return IdentityType.none;
      case 1:
        return IdentityType.nationalId;
      case 2:
        return IdentityType.passport;
      case 3:
        return IdentityType.driverLicense;
      case 4:
        return IdentityType.other;
      default:
        return null;
    }
  }

  static IdentityType? fromLabel(String? value) {
    if (value == null) return null;
    final v = value.toLowerCase();
    switch (v) {
      case 'none':
        return IdentityType.none;
      case 'nationalid':
      case 'national id':
      case 'tazkira': // common local naming
        return IdentityType.nationalId;
      case 'passport':
        return IdentityType.passport;
      case 'driverlicense':
      case 'driver license':
        return IdentityType.driverLicense;
      case 'other':
        return IdentityType.other;
      default:
        return null;
    }
  }
}
