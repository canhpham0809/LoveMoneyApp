import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/category_visuals.dart';
import '../../../core/models/transaction.dart';

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
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions'));
    }
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: transactions.length,
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(iconData, color: color),
          ),
          title: Text(tx.title),
          subtitle: Text(
            '${formatDate(tx.date)} · ${formatTimeUtcPlus7(tx.createdAt)}',
          ),
          trailing: Text(
            '$sign${formatVnd(tx.amount.abs())}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  IconData _iconForType(TransactionType type, bool isIncomingTransfer) {
    switch (type) {
      case TransactionType.income:
        return Icons.arrow_downward;
      case TransactionType.expense:
        return Icons.arrow_upward;
      case TransactionType.fund:
        return Icons.savings;
      case TransactionType.debt:
        return Icons.payments;
      case TransactionType.transfer:
        return isIncomingTransfer
            ? Icons.south_west_rounded
            : Icons.north_east_rounded;
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
