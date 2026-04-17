import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
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
        final iconData = _iconForType(tx.type);
        final color = _colorForType(tx.type);
        final sign = (tx.type == TransactionType.income)
            ? '+'
            : (tx.type == TransactionType.transfer ? '' : '-');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(iconData, color: color),
          ),
          title: Text(tx.title),
          subtitle: Text(formatDate(tx.date)),
          trailing: Text(
            '$sign${formatVnd(tx.amount.abs())}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  IconData _iconForType(TransactionType type) {
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
        return Icons.compare_arrows;
    }
  }

  Color _colorForType(TransactionType type) {
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
        return Colors.grey;
    }
  }
}
