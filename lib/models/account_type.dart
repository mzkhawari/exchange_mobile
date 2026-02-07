enum AccountType {
  real, // 1
  legal, // 2
}

extension AccountTypeX on AccountType {
  int get code => switch (this) { AccountType.real => 1, AccountType.legal => 2 };

  String get label => switch (this) { AccountType.real => 'Real', AccountType.legal => 'Legal' };

  static AccountType? fromCode(int? code) {
    switch (code) {
      case 1:
        return AccountType.real;
      case 2:
        return AccountType.legal;
      default:
        return null;
    }
  }

  static AccountType? fromLabel(String? value) {
    final v = value?.toLowerCase();
    switch (v) {
      case 'real':
        return AccountType.real;
      case 'legal':
        return AccountType.legal;
      default:
        return null;
    }
  }
}
