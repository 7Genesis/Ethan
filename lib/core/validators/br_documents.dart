class BrDocumentsValidator {
  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValidCpf(String value) {
    final digits = digitsOnly(value);
    if (digits.length != 11) {
      return false;
    }
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }

    final firstDigit = _cpfVerifierDigit(digits.substring(0, 9));
    final secondDigit = _cpfVerifierDigit(
      digits.substring(0, 9) + firstDigit.toString(),
    );
    return digits.endsWith('$firstDigit$secondDigit');
  }

  static bool isValidCnpj(String value) {
    final digits = digitsOnly(value);
    if (digits.length != 14) {
      return false;
    }
    if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) {
      return false;
    }

    final firstDigit = _cnpjVerifierDigit(digits.substring(0, 12));
    final secondDigit = _cnpjVerifierDigit(
      digits.substring(0, 12) + firstDigit.toString(),
    );
    return digits.endsWith('$firstDigit$secondDigit');
  }

  static String normalizeBrazilPhone(String value) {
    final digits = digitsOnly(value);
    if (digits.length == 13 && digits.startsWith('55')) {
      return digits.substring(2);
    }
    return digits;
  }

  static bool isValidBrazilWhatsApp(String value) {
    final digits = normalizeBrazilPhone(value);
    if (digits.length != 11) {
      return false;
    }

    final ddd = int.tryParse(digits.substring(0, 2));
    final ninthDigit = digits.substring(2, 3);
    if (ddd == null || ddd < 11 || ddd > 99) {
      return false;
    }
    if (ninthDigit != '9') {
      return false;
    }
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }
    return true;
  }

  static int _cpfVerifierDigit(String base) {
    var sum = 0;
    for (var i = 0; i < base.length; i++) {
      sum += int.parse(base[i]) * (base.length + 1 - i);
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  static int _cnpjVerifierDigit(String base) {
    final multipliers = base.length == 12
        ? const [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        : const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var i = 0; i < base.length; i++) {
      sum += int.parse(base[i]) * multipliers[i];
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }
}
