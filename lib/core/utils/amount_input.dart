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

    // Count digits before the cursor in the new (unformatted) value
    final cursorPos = newValue.selection.end.clamp(0, newValue.text.length);
    int digitsBeforeCursor = 0;
    for (int i = 0; i < cursorPos; i++) {
      if (newValue.text[i].contains(RegExp(r'[0-9]'))) digitsBeforeCursor++;
    }

    // Find where that many digits fall in the formatted string
    int newCursorPos = formatted.length;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (seen == digitsBeforeCursor) {
        newCursorPos = i;
        break;
      }
      if (formatted[i].contains(RegExp(r'[0-9]'))) seen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
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
