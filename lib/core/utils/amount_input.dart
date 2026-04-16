import 'package:flutter/services.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formatted = formatAmountInput(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatAmountInput(String raw) {
  final digits = _digitsOnly(raw);
  if (digits.isEmpty) return '';

  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

double? parseAmountInput(String text) {
  final digits = _digitsOnly(text);
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

String _digitsOnly(String input) {
  return input.replaceAll(RegExp(r'[^0-9]'), '');
}
