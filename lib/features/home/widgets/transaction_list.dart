import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/category_visuals.dart';
import '../../../core/models/transaction.dart';
import '../../../core/theme/app_colors.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const TransactionList({
    required this.transactions,
    this.shrinkWrap = false,
    this.physics,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có giao dịch nào',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final tx = transactions[idx];
        final inferredIncomingFromTitle = tx.title.startsWith('Nhận từ');
        final inferredOutgoingFromTitle = tx.title.startsWith('Chuyển cho');
        final isIncomingTransfer =
            tx.type == TransactionType.transfer &&
            (tx.isIncomingTransfer ?? inferredIncomingFromTitle);
        final isOutgoingTransfer =
            tx.type == TransactionType.transfer &&
            (tx.isIncomingTransfer == false || inferredOutgoingFromTitle);
        final iconData = tx.iconKey != null && tx.iconKey!.trim().isNotEmpty
            ? iconFromKey(tx.iconKey!)
            : _iconForType(tx.type, isIncomingTransfer);
        final color = _colorForType(
          tx.type,
          isIncomingTransfer: isIncomingTransfer,
          isOutgoingTransfer: isOutgoingTransfer,
        );
        final sign = tx.type == TransactionType.income
            ? '+'
            : tx.type == TransactionType.transfer
            ? (isIncomingTransfer ? '+' : (isOutgoingTransfer ? '-' : ''))
            : '-';
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            title: Text(
              tx.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            subtitle: Text(
              '${formatDate(tx.date)} · ${formatTimeUtcPlus7(tx.createdAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              '$sign${formatVnd(tx.amount.abs())}',
              style: textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(TransactionType type, bool isIncomingTransfer) {
    switch (type) {
      case TransactionType.income:
        return Icons.payments_outlined;
      case TransactionType.expense:
        return Icons.shopping_bag_outlined;
      case TransactionType.fund:
        return Icons.savings;
      case TransactionType.debt:
        return Icons.payments;
      case TransactionType.transfer:
        return isIncomingTransfer
            ? Icons.move_to_inbox_rounded
            : Icons.send_rounded;
    }
  }

  Color _colorForType(
    TransactionType type, {
    bool isIncomingTransfer = false,
    bool isOutgoingTransfer = false,
  }) {
    switch (type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.fund:
        return Colors.orange;
      case TransactionType.debt:
        return Colors.blue;
      case TransactionType.transfer:
        if (isIncomingTransfer) return Colors.green;
        if (isOutgoingTransfer) return Colors.red;
        return Colors.grey;
    }
  }
}
