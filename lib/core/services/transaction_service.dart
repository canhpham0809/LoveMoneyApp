import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';
import '../models/monthly_summary.dart';

class TransactionService {
  final supabase = Supabase.instance.client;

  String _pickTitle({
    required Map<String, dynamic> row,
    required String fallback,
    List<String> preferredFields = const ['description', 'note'],
  }) {
    for (final key in preferredFields) {
      final value = (row[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    final categoryName = (row['resolved_category_name'] as String?)?.trim();
    if (categoryName != null && categoryName.isNotEmpty) {
      return categoryName;
    }
    return fallback;
  }

  Future<List<MonthlySummary>> fetchMonthlySummaries({
    required String coupleId,
    String? viewerUserId,
  }) async {
    var incomesQuery = supabase
        .from('incomes')
        .select('id, amount, date, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    var expensesQuery = supabase
        .from('expenses')
        .select('id, amount, date, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    var fundsQuery = supabase
        .from('fund_contributions')
        .select('id, amount, date, created_at')
        .eq('couple_id', coupleId)
        .eq('contribution_type', 'contribution')
        .eq('is_deleted', false);
    var debtsQuery = supabase
        .from('debt_payments')
        .select('id, amount, date, created_at, updated_by')
        .eq('couple_id', coupleId)
        .isFilter('linked_income_id', null)
        .eq('is_deleted', false);
    var transfersQuery = supabase
        .from('transfers')
        .select('id, amount, date, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (viewerUserId != null) {
      incomesQuery = incomesQuery.eq('user_id', viewerUserId);
      expensesQuery = expensesQuery.eq('user_id', viewerUserId);
      fundsQuery = fundsQuery.eq('user_id', viewerUserId);
      debtsQuery = debtsQuery.eq('updated_by', viewerUserId);
      transfersQuery = transfersQuery.eq('from_user_id', viewerUserId);
    }

    final results = await Future.wait([
      incomesQuery.order('created_at', ascending: false),
      expensesQuery.order('created_at', ascending: false),
      fundsQuery.order('created_at', ascending: false),
      debtsQuery.order('created_at', ascending: false),
      transfersQuery.order('created_at', ascending: false),
    ]);

    final transactions = <Transaction>[
      ...(results[0] as List).map(
        (json) => Transaction.fromJson({...json, 'type': 'income'}),
      ),
      ...(results[1] as List).map(
        (json) => Transaction.fromJson({...json, 'type': 'expense'}),
      ),
      ...(results[2] as List).map(
        (json) => Transaction.fromJson({...json, 'type': 'fund'}),
      ),
      ...(results[3] as List).map(
        (json) => Transaction.fromJson({...json, 'type': 'debt'}),
      ),
      ...(results[4] as List).map(
        (json) => Transaction.fromJson({...json, 'type': 'transfer'}),
      ),
    ];

    final Map<String, List<Transaction>> grouped = {};
    for (final tx in transactions) {
      final key = '${tx.date.year}-${tx.date.month}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return grouped.entries.map((entry) {
      final txs = entry.value;
      double income = 0, expense = 0;
      for (final tx in txs) {
        switch (tx.type) {
          case TransactionType.income:
            income += tx.amount;
            break;
          case TransactionType.expense:
          case TransactionType.fund:
          case TransactionType.debt:
          case TransactionType.transfer:
            expense += tx.amount.abs();
            break;
        }
      }
      final parts = entry.key.split('-');
      return MonthlySummary(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        income: income,
        expense: expense,
      );
    }).toList()..sort(
      (a, b) => b.year != a.year
          ? b.year.compareTo(a.year)
          : b.month.compareTo(a.month),
    );
  }

  Future<List<Transaction>> fetchRecentTransactions({
    required String coupleId,
    required int year,
    required int month,
    String? viewerUserId,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final categories = await supabase
        .from('categories')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final categoryNameById = {
      for (final c in categories) c['id'] as String: c['name'] as String,
    };

    final funds = await supabase
        .from('funds')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final fundNameById = {
      for (final f in funds) f['id'] as String: f['name'] as String,
    };

    final debts = await supabase
        .from('debts')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final debtNameById = {
      for (final d in debts) d['id'] as String: d['name'] as String,
    };

    var incomesQuery = supabase
        .from('incomes')
        .select('id, amount, date, created_at, description')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
    var expensesQuery = supabase
        .from('expenses')
        .select(
          'id, amount, date, created_at, description, category_id, category_name',
        )
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
    var fundsQuery = supabase
        .from('fund_contributions')
        .select('id, amount, date, created_at, note, fund_id')
        .eq('couple_id', coupleId)
        .eq('contribution_type', 'contribution')
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
    var debtsQuery = supabase
        .from('debt_payments')
        .select('id, amount, date, created_at, note, debt_id, updated_by')
        .eq('couple_id', coupleId)
        .isFilter('linked_income_id', null)
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
    var transfersQuery = supabase
        .from('transfers')
        .select('id, amount, date, created_at, note')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));

    if (viewerUserId != null) {
      incomesQuery = incomesQuery.eq('user_id', viewerUserId);
      expensesQuery = expensesQuery.eq('user_id', viewerUserId);
      fundsQuery = fundsQuery.eq('user_id', viewerUserId);
      debtsQuery = debtsQuery.eq('updated_by', viewerUserId);
      transfersQuery = transfersQuery.eq('from_user_id', viewerUserId);
    }

    final results = await Future.wait([
      incomesQuery.order('created_at', ascending: false).limit(20),
      expensesQuery.order('created_at', ascending: false).limit(20),
      fundsQuery.order('created_at', ascending: false).limit(20),
      debtsQuery.order('created_at', ascending: false).limit(20),
      transfersQuery.order('created_at', ascending: false).limit(20),
    ]);

    final incomes = (results[0] as List).map(
      (json) => Transaction.fromJson({
        ...json,
        'type': 'income',
        'title': _pickTitle(
          row: Map<String, dynamic>.from(json),
          fallback: 'Thu nhập',
        ),
      }),
    );
    final expenses = (results[1] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      final categoryId = row['category_id'] as String?;
      row['resolved_category_name'] =
          (categoryId != null ? categoryNameById[categoryId] : null) ??
          row['category_name'];
      return Transaction.fromJson({
        ...row,
        'type': 'expense',
        'title': _pickTitle(row: row, fallback: 'Chi tiêu'),
      });
    });
    final fundsTx = (results[2] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      final fundId = row['fund_id'] as String?;
      final fallback = fundId != null && fundNameById[fundId] != null
          ? fundNameById[fundId]!
          : 'Góp quỹ';
      return Transaction.fromJson({
        ...row,
        'type': 'fund',
        'title': _pickTitle(
          row: row,
          fallback: fallback,
          preferredFields: const ['note'],
        ),
      });
    });
    final debtTx = (results[3] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      final debtId = row['debt_id'] as String?;
      final fallback = debtId != null && debtNameById[debtId] != null
          ? debtNameById[debtId]!
          : 'Trả nợ';
      return Transaction.fromJson({
        ...row,
        'type': 'debt',
        'title': _pickTitle(
          row: row,
          fallback: fallback,
          preferredFields: const ['note'],
        ),
      });
    });
    final transfers = (results[4] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      return Transaction.fromJson({
        ...row,
        'type': 'transfer',
        'title': _pickTitle(
          row: row,
          fallback: 'Chuyển tiền',
          preferredFields: const ['note'],
        ),
      });
    });

    final transactions = <Transaction>[
      ...incomes,
      ...expenses,
      ...fundsTx,
      ...debtTx,
      ...transfers,
    ];

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions.take(20).toList();
  }
}
