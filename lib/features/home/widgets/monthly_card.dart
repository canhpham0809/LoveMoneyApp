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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected ? AppGradients.premiumCard : null,
        color: isSelected
            ? null
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: isSelected
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.border,
              ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.tealDeep.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.tealSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${summary.month}/${summary.year}',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.tealDeep,
                        ),
                      ),
                    ),
                    if (onCarryOverPressed != null)
                      IconButton(
                        onPressed: onCarryOverPressed,
                        icon: Icon(
                          Icons.swap_horizontal_circle_outlined,
                          color: isSelected ? Colors.white70 : AppColors.teal,
                          size: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Chuyển dư',
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Số dư khả dụng',
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected ? Colors.white70 : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatVnd(summary.balance),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : (summary.balance >= 0
                              ? AppColors.tealDeep
                              : AppColors.danger),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _miniStat(
                      label: 'Thu',
                      value: summary.income,
                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.success,
                      isDark: isSelected,
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      label: 'Chi',
                      value: summary.expense,
                      color: isSelected ? Colors.white.withValues(alpha: 0.7) : AppColors.danger,
                      isDark: isSelected,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          formatVnd(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
