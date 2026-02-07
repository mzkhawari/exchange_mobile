enum Gender {
  all,
  male,
  female,
  other,
}

extension GenderX on Gender {
  int get code => index; // All=0, Male=1, Female=2, Other=3

  String get label {
    switch (this) {
      case Gender.all:
        return 'All';
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }

  static Gender fromCode(int code) {
    if (code < 0 || code >= Gender.values.length) return Gender.all;
    return Gender.values[code];
  }

  static Gender? fromLabel(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'all':
        return Gender.all;
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
      case 'otrher': // handle typo from source
        return Gender.other;
      default:
        return null;
    }
  }
}
