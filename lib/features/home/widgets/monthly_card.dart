import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/models/monthly_summary.dart';

class MonthlyCard extends StatelessWidget {
  final MonthlySummary summary;
  final bool isSelected;
  const MonthlyCard({
    required this.summary,
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(fontSize: 17);
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tháng ${summary.month}/${summary.year}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            _statRow(
              'Thu nhập',
              summary.income,
              const Color(0xFF2E7D32),
              labelStyle,
            ),
            const Divider(height: 10, thickness: 0.5),
            _statRow(
              'Chi tiêu',
              summary.expense,
              const Color(0xFFC62828),
              labelStyle,
            ),
            const Divider(height: 10, thickness: 0.5),
            _statRow(
              'Còn lại',
              summary.balance,
              summary.balance >= 0
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFC62828),
              labelStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    String label,
    double value,
    Color amountColor,
    TextStyle? labelStyle,
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: labelStyle),
      Text(
        formatVnd(value),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    ],
  );
}
