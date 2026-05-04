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
        .eq('is_deleted', false)
        .or('is_from_transfer.is.null,is_from_transfer.eq.false');
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
        .select('id, amount, date, created_at, from_user_id, to_user_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (viewerUserId != null) {
      incomesQuery = incomesQuery.eq('user_id', viewerUserId);
      expensesQuery = expensesQuery.eq('user_id', viewerUserId);
      fundsQuery = fundsQuery.eq('user_id', viewerUserId);
      debtsQuery = debtsQuery.eq('updated_by', viewerUserId);
      transfersQuery = transfersQuery.or(
        'from_user_id.eq.$viewerUserId,to_user_id.eq.$viewerUserId',
      );
    }

    final results = await Future.wait([
      incomesQuery.order('created_at', ascending: false),
      expensesQuery.order('created_at', ascending: false),
      fundsQuery.order('created_at', ascending: false),
      debtsQuery.order('created_at', ascending: false),
      transfersQuery.order('created_at', ascending: false),
    ]);

    final grouped = <String, Map<String, double>>{};

    void addIncome(DateTime date, double amount) {
      final key = '${date.year}-${date.month}';
      final bucket = grouped.putIfAbsent(
        key,
        () => <String, double>{'income': 0, 'expense': 0},
      );
      bucket['income'] = (bucket['income'] ?? 0) + amount;
    }

    void addExpense(DateTime date, double amount) {
      final key = '${date.year}-${date.month}';
      final bucket = grouped.putIfAbsent(
        key,
        () => <String, double>{'income': 0, 'expense': 0},
      );
      bucket['expense'] = (bucket['expense'] ?? 0) + amount.abs();
    }

    for (final row in results[0] as List) {
      final date = DateTime.parse(
        (row as Map<String, dynamic>)['date'] as String,
      );
      addIncome(date, (row['amount'] as num).toDouble());
    }
    for (final row in results[1] as List) {
      final date = DateTime.parse(
        (row as Map<String, dynamic>)['date'] as String,
      );
      addExpense(date, (row['amount'] as num).toDouble());
    }
    for (final row in results[2] as List) {
      final date = DateTime.parse(
        (row as Map<String, dynamic>)['date'] as String,
      );
      addExpense(date, (row['amount'] as num).toDouble());
    }
    for (final row in results[3] as List) {
      final date = DateTime.parse(
        (row as Map<String, dynamic>)['date'] as String,
      );
      addExpense(date, (row['amount'] as num).toDouble());
    }
    for (final row in results[4] as List) {
      final map = row as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final amount = (map['amount'] as num).toDouble();

      if (viewerUserId == null) {
        // Internal transfers should not affect couple-level net summary.
        continue;
      }

      if (map['to_user_id'] == viewerUserId) {
        addIncome(date, amount);
      } else {
        addExpense(date, amount);
      }
    }

    return grouped.entries.map((entry) {
      final parts = entry.key.split('-');
      return MonthlySummary(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        income: entry.value['income'] ?? 0,
        expense: entry.value['expense'] ?? 0,
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
        .select('id, name, icon')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final categoryNameById = {
      for (final c in categories) c['id'] as String: c['name'] as String,
    };
    final categoryIconById = {
      for (final c in categories)
        c['id'] as String: ((c['icon'] as String?) ?? 'label'),
    };

    final incomeSources = await supabase
        .from('income_sources')
        .select('id, name, icon')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final incomeSourceNameById = {
      for (final s in incomeSources) s['id'] as String: s['name'] as String,
    };
    final incomeSourceIconById = {
      for (final s in incomeSources)
        s['id'] as String: ((s['icon'] as String?) ?? 'payments'),
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
        .select('id, amount, date, created_at, description, income_source_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .or('is_from_transfer.is.null,is_from_transfer.eq.false')
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
        .select('id, amount, date, created_at, note, from_user_id, to_user_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));

    if (viewerUserId != null) {
      incomesQuery = incomesQuery.eq('user_id', viewerUserId);
      expensesQuery = expensesQuery.eq('user_id', viewerUserId);
      fundsQuery = fundsQuery.eq('user_id', viewerUserId);
      debtsQuery = debtsQuery.eq('updated_by', viewerUserId);
      transfersQuery = transfersQuery.or(
        'from_user_id.eq.$viewerUserId,to_user_id.eq.$viewerUserId',
      );
    }

    final results = await Future.wait([
      incomesQuery
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(20),
      expensesQuery
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(20),
      fundsQuery
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(20),
      debtsQuery
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(20),
      transfersQuery
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(20),
    ]);

    final incomes = (results[0] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      final sourceId = row['income_source_id'] as String?;
      row['resolved_category_name'] = sourceId != null
          ? incomeSourceNameById[sourceId]
          : null;
      return Transaction.fromJson({
        ...row,
        'type': 'income',
        'icon_key': sourceId != null ? incomeSourceIconById[sourceId] : null,
        'title': _pickTitle(row: row, fallback: 'Thu nhập'),
      });
    });
    final expenses = (results[1] as List).map((json) {
      final row = Map<String, dynamic>.from(json);
      final categoryId = row['category_id'] as String?;
      row['resolved_category_name'] =
          (categoryId != null ? categoryNameById[categoryId] : null) ??
          row['category_name'];
      return Transaction.fromJson({
        ...row,
        'type': 'expense',
        'icon_key': categoryId != null ? categoryIconById[categoryId] : null,
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

    final transferRows = (results[4] as List)
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
    final transferUserIds = <String>{
      ...transferRows.map((row) => row['from_user_id']).whereType<String>(),
      ...transferRows.map((row) => row['to_user_id']).whereType<String>(),
    };
    final transferUsers = transferUserIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await supabase
                .from('users')
                .select('id, display_name, email')
                .inFilter('id', transferUserIds.toList()),
          );
    final transferUserNameById = {
      for (final row in transferUsers)
        row['id'] as String:
            ((row['display_name'] as String?)?.trim().isNotEmpty == true
            ? (row['display_name'] as String).trim()
            : ((row['email'] as String?) ?? 'Người kia')),
    };

    final transfers = transferRows.map((row) {
      final fromUserId = row['from_user_id'] as String?;
      final toUserId = row['to_user_id'] as String?;
      final isIncoming = viewerUserId != null
          ? toUserId == viewerUserId
          : false;
      final partnerId = isIncoming ? fromUserId : toUserId;
      final partnerName =
          (partnerId != null ? transferUserNameById[partnerId] : null) ??
          'Người kia';
      final directionLabel = isIncoming ? 'Nhận từ' : 'Chuyển cho';
      final title = ((row['note'] as String?)?.trim().isNotEmpty ?? false)
          ? (row['note'] as String).trim()
          : '$directionLabel $partnerName';
      return Transaction.fromJson({
        ...row,
        'type': 'transfer',
        'title': title,
        'is_incoming_transfer': isIncoming,
      });
    });

    final transactions = <Transaction>[
      ...incomes,
      ...expenses,
      ...fundsTx,
      ...debtTx,
      ...transfers,
    ];

    transactions.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return transactions.take(20).toList();
  }
}
