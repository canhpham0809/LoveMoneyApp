import 'package:flutter/material.dart';

class AmountSuggestionChips extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onSelected;

  const AmountSuggestionChips({
    super.key,
    required this.controller,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final raw = value.text.trim();
        final base = _parseBase(raw);
        if (base == null || base <= 0) {
          return const SizedBox.shrink();
        }

        final options = _buildSuggestions(base);
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            height: 30,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < options.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _buildSlot(options[i], 80),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlot(int value, double width) {
    return SizedBox(
      width: width,
      height: 30,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity(horizontal: -2, vertical: -2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onSelected(value),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatWithComma(value),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  List<int> _buildSuggestions(int base) {
    if (base < 1000) {
      return [base * 1000, base * 10000, base * 100000];
    }
    return [base * 10, base * 100, base * 1000];
  }

  int? _parseBase(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;
    return int.tryParse(digitsOnly);
  }

  String _formatWithComma(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buffer.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
