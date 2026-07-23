import 'package:flutter/services.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text &&
        oldValue.selection == newValue.selection) {
      return newValue;
    }

    final digits = _digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formatted = formatAmountInput(digits);

    if (formatted == newValue.text) {
      return newValue;
    }

    // Count digits before the cursor in the new (unformatted) value
    final cursorPos = newValue.selection.end.clamp(0, newValue.text.length);
    int digitsBeforeCursor = 0;
    for (int i = 0; i < cursorPos; i++) {
      final code = newValue.text.codeUnitAt(i);
      if (code >= 48 && code <= 57) digitsBeforeCursor++;
    }

    // Find where that many digits fall in the formatted string
    int newCursorPos = formatted.length;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (seen == digitsBeforeCursor) {
        newCursorPos = i;
        break;
      }
      final code = formatted.codeUnitAt(i);
      if (code >= 48 && code <= 57) seen++;
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
  final sb = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code >= 48 && code <= 57) {
      sb.writeCharCode(code);
    }
  }
  return sb.toString();
}

