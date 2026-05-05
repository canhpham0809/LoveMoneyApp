import 'package:flutter/material.dart';

import '../../../core/models/monthly_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/formatters.dart';

class MonthlyCard extends StatelessWidget {
  final MonthlySummary summary;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onCarryOverPressed;

  const MonthlyCard({
    required this.summary,
    this.isSelected = false,
    this.onTap,
    this.onCarryOverPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardColor = isSelected
        ? null
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final borderColor = isSelected ? Colors.transparent : AppColors.border;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isSelected ? AppGradients.softTeal : null,
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tháng ${summary.month}/${summary.year}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onCarryOverPressed,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Tooltip(
                          message: 'Chuyển dư sang tháng sau',
                          child: Icon(Icons.add_circle_outline, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _statRow(
                  context: context,
                  label: 'Thu nhập',
                  value: summary.income,
                  amountColor: AppColors.success,
                ),
                const SizedBox(height: 2),
                _statRow(
                  context: context,
                  label: 'Chi tiêu',
                  value: summary.expense,
                  amountColor: AppColors.danger,
                ),
                const Divider(height: 10, thickness: 1),
                _statRow(
                  context: context,
                  label: 'Còn lại',
                  value: summary.balance,
                  amountColor: summary.balance >= 0
                      ? AppColors.tealDeep
                      : AppColors.danger,
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow({
    required BuildContext context,
    required String label,
    required double value,
    required Color amountColor,
    bool emphasize = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          formatVnd(value),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
