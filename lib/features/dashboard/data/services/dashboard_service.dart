import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  SupabaseClient get _db => Supabase.instance.client;

  bool _isMissingDebtKindColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('debt_kind');
  }

  /// Returns wallet balances from the computed view.
  Future<List<Map<String, dynamic>>> getWalletBalances(String coupleId) async {
    final rows = await _db
        .from('wallet_balances')
        .select()
        .eq('couple_id', coupleId);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Total income for the current month.
  Future<double> getMonthlyIncome(String coupleId) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('incomes')
        .select('amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    return rows.fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Total expense for the current month.
  Future<double> getMonthlyExpense(String coupleId) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('expenses')
        .select('amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    return rows.fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Recent transactions (latest 20 across expense, income, transfer).
  Future<List<Map<String, dynamic>>> getRecentTransactions(
    String coupleId,
  ) async {
    final categories = await _db
        .from('categories')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final categoryNameById = {
      for (final c in categories) c['id'] as String: c['name'] as String,
    };

    final expenses = await _db
        .from('expenses')
        .select(
          'id, amount, date, description, category_id, category_name, created_at',
        )
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(10);
    final incomes = await _db
        .from('incomes')
        .select('id, amount, date, description, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(10);
    final transfers = await _db
        .from('transfers')
        .select('id, amount, date, note, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(10);

    final normalizedExpenses = expenses.map((e) {
      final categoryId = e['category_id'] as String?;
      return {
        ...e,
        'type': 'expense',
        'resolved_category_name': categoryId == null
            ? (e['category_name'] as String?)
            : (categoryNameById[categoryId] ?? (e['category_name'] as String?)),
      };
    });

    final combined = [
      ...normalizedExpenses,
      ...incomes.map((i) => {...i, 'type': 'income'}),
      ...transfers.map((t) => {...t, 'type': 'transfer'}),
    ];
    DateTime parseCreatedAt(Map<String, dynamic> tx) {
      final value = tx['created_at'] as String?;
      if (value == null || value.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    combined.sort((a, b) => parseCreatedAt(b).compareTo(parseCreatedAt(a)));
    return combined.take(20).toList();
  }

  /// Expense breakdown by category for the current month.
  Future<List<Map<String, dynamic>>> getCategoryBreakdown(
    String coupleId,
  ) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('expenses')
        .select('category_name, amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    // Group by category client-side
    final Map<String, double> map = {};
    for (final r in rows) {
      final cat = (r['category_name'] as String?) ?? 'Other';
      map[cat] = (map[cat] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }
    return map.entries
        .map((e) => {'category': e.key, 'amount': e.value})
        .toList()
      ..sort(
        (a, b) => (b['amount']! as double).compareTo(a['amount']! as double),
      );
  }

  Future<Map<String, dynamic>> getMonthlyOperationsDashboard({
    required String coupleId,
    required int year,
    required int month,
    String? viewerUserId,
  }) async {
    final from = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final to = DateTime(
      month == 12 ? year + 1 : year,
      month == 12 ? 1 : month + 1,
      1,
    ).toIso8601String().substring(0, 10);

    final categories = await _db
        .from('categories')
        .select('id, name, icon')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final categoryNameById = {
      for (final row in categories) row['id'] as String: row['name'] as String,
    };
    final categoryIconById = {
      for (final row in categories)
        row['id'] as String: ((row['icon'] as String?) ?? 'label'),
    };

    final incomeSources = await _db
        .from('income_sources')
        .select('id, name, icon, show_in_income_form')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final incomeSourceNameById = {
      for (final row in incomeSources)
        row['id'] as String: row['name'] as String,
    };
    final incomeSourceIconById = {
      for (final row in incomeSources)
        row['id'] as String: ((row['icon'] as String?) ?? 'payments'),
    };
    final hiddenIncomeSourceIds = {
      for (final row in incomeSources)
        if ((row['show_in_income_form'] as bool?) == false) row['id'] as String,
    };
    final generatedIncomeSourceNames = {'nhận tiền nợ', 'rút quỹ', 'xóa quỹ'};

    final funds = await _db
        .from('funds')
        .select('id, name, icon, current_amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final fundNameById = {
      for (final row in funds) row['id'] as String: row['name'] as String,
    };
    final fundIconById = {
      for (final row in funds)
        row['id'] as String: ((row['icon'] as String?) ?? 'savings'),
    };
    final fundBalanceById = {
      for (final row in funds)
        row['id'] as String: ((row['current_amount'] as num?)?.toDouble() ?? 0),
    };

    var expensesQuery = _db
        .from('expenses')
        .select('id, amount, category_id, category_name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from)
        .lt('date', to);
    var incomesQuery = _db
        .from('incomes')
        .select('id, amount, income_source_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .or('is_from_transfer.is.null,is_from_transfer.eq.false')
        .gte('date', from)
        .lt('date', to);
    var contributionsQuery = _db
        .from('fund_contributions')
        .select(
          'amount, fund_id, contribution_type, date, note, linked_income_id',
        )
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from)
        .lt('date', to);
    var transfersQuery = _db
        .from('transfers')
        .select('amount, from_user_id, to_user_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from)
        .lt('date', to);

    if (viewerUserId != null) {
      expensesQuery = expensesQuery.eq('user_id', viewerUserId);
      incomesQuery = incomesQuery.eq('user_id', viewerUserId);
      contributionsQuery = contributionsQuery.eq('user_id', viewerUserId);
      transfersQuery = transfersQuery.or(
        'from_user_id.eq.$viewerUserId,to_user_id.eq.$viewerUserId',
      );
    }

    List<Map<String, dynamic>> debtRows;
    try {
      var debtsQuery = _db
          .from('debts')
          .select(
            'id, name, debt_kind, original_amount, record_to_income, linked_income_id, linked_expense_id, start_date',
          )
          .eq('couple_id', coupleId)
          .eq('is_deleted', false);
      if (viewerUserId != null) {
        debtsQuery = debtsQuery.eq('user_id', viewerUserId);
      }
      debtRows = List<Map<String, dynamic>>.from(await debtsQuery);
    } catch (e) {
      if (!_isMissingDebtKindColumn(e)) rethrow;
      var debtsQuery = _db
          .from('debts')
          .select('id, name, original_amount, start_date')
          .eq('couple_id', coupleId)
          .eq('is_deleted', false);
      if (viewerUserId != null) {
        debtsQuery = debtsQuery.eq('user_id', viewerUserId);
      }
      debtRows = List<Map<String, dynamic>>.from(await debtsQuery)
          .map(
            (row) => {
              ...row,
              'debt_kind': 'debt',
              'record_to_income': false,
              'linked_income_id': null,
              'linked_expense_id': null,
            },
          )
          .toList();
    }

    final results = await Future.wait([
      expensesQuery,
      incomesQuery,
      contributionsQuery,
      transfersQuery,
    ]);

    final expenses = List<Map<String, dynamic>>.from(results[0] as List);
    final incomes = List<Map<String, dynamic>>.from(results[1] as List);
    final contributions = List<Map<String, dynamic>>.from(results[2] as List);
    final transfers = List<Map<String, dynamic>>.from(results[3] as List);

    final activeFundIds = fundNameById.keys.toSet();
    final filteredContributions = contributions.where((row) {
      final fundId = row['fund_id'] as String?;
      return fundId != null && activeFundIds.contains(fundId);
    }).toList();

    double transferSent = 0;
    double transferReceived = 0;
    for (final row in transfers) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final fromUserId = row['from_user_id'] as String?;
      final toUserId = row['to_user_id'] as String?;

      if (viewerUserId == null) {
        continue;
      }
      if (fromUserId == viewerUserId) {
        transferSent += amount;
      } else if (toUserId == viewerUserId) {
        transferReceived += amount;
      }
    }

    // Fetch payments in the month for ALL debts of this viewer, then decide
    // inclusion in Dart (recorded+created-this-month OR has payments this month).
    final allDebtIdsForCouple = debtRows.map((r) => r['id'] as String).toList();
    final paymentsByDebtId = <String, List<Map<String, dynamic>>>{};
    if (allDebtIdsForCouple.isNotEmpty) {
      try {
        final paymentRows = List<Map<String, dynamic>>.from(
          await _db
              .from('debt_payments')
              .select('debt_id, amount, date, note, linked_income_id')
              .inFilter('debt_id', allDebtIdsForCouple)
              .eq('is_deleted', false)
              .gte('date', from)
              .lt('date', to),
        );
        for (final p in paymentRows) {
          final pid = p['debt_id'] as String?;
          if (pid == null) continue;
          paymentsByDebtId.putIfAbsent(pid, () => []).add(p);
        }
      } catch (_) {
        // debt_payments might not exist in older schemas — skip gracefully
      }
    }

    // Fetch all-time payments for non-recorded debts to compute remaining balance.
    final totalPaidAllTimeByDebtId = <String, double>{};
    if (allDebtIdsForCouple.isNotEmpty) {
      try {
        final allPaymentRows = List<Map<String, dynamic>>.from(
          await _db
              .from('debt_payments')
              .select('debt_id, amount')
              .inFilter('debt_id', allDebtIdsForCouple)
              .eq('is_deleted', false),
        );
        for (final p in allPaymentRows) {
          final pid = p['debt_id'] as String?;
          if (pid == null) continue;
          totalPaidAllTimeByDebtId[pid] =
              (totalPaidAllTimeByDebtId[pid] ?? 0) +
              ((p['amount'] as num?)?.toDouble() ?? 0);
        }
      } catch (_) {}
    }

    final excludedIncomeIds = <String>{
      ...filteredContributions
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
      ...debtRows
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
      ...paymentsByDebtId.values
          .expand((rows) => rows)
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
    };
    final excludedExpenseIds = <String>{
      ...debtRows
          .map((row) => row['linked_expense_id'] as String?)
          .whereType<String>(),
    };

    final manualIncomes = incomes.where((row) {
      final incomeId = row['id'] as String?;
      final sourceId = row['income_source_id'] as String?;
      final sourceName =
          ((sourceId != null ? incomeSourceNameById[sourceId] : null) ?? '')
              .trim()
              .toLowerCase();
      return !excludedIncomeIds.contains(incomeId) &&
          !hiddenIncomeSourceIds.contains(sourceId) &&
          !generatedIncomeSourceNames.contains(sourceName);
    }).toList();
    final manualExpenses = expenses
        .where((row) => !excludedExpenseIds.contains(row['id'] as String?))
        .toList();

    final expenseMap = <String, Map<String, dynamic>>{};
    for (final row in manualExpenses) {
      final categoryId = row['category_id'] as String?;
      final fallbackName = (row['category_name'] as String?) ?? 'Khác';
      final name =
          (categoryId != null ? categoryNameById[categoryId] : null) ??
          fallbackName;
      final iconKey =
          (categoryId != null ? categoryIconById[categoryId] : null) ?? 'label';
      final key = categoryId ?? fallbackName;
      final bucket = expenseMap.putIfAbsent(
        key,
        () => {'name': name, 'icon_key': iconKey, 'amount': 0.0},
      );
      bucket['amount'] =
          (bucket['amount'] as double) +
          ((row['amount'] as num?)?.toDouble() ?? 0);
    }

    final incomeMap = <String, Map<String, dynamic>>{};
    for (final row in manualIncomes) {
      final sourceId = row['income_source_id'] as String?;
      final name =
          (sourceId != null ? incomeSourceNameById[sourceId] : null) ?? 'Khác';
      final iconKey =
          (sourceId != null ? incomeSourceIconById[sourceId] : null) ??
          'payments';
      final key = sourceId ?? name;
      final bucket = incomeMap.putIfAbsent(
        key,
        () => {'name': name, 'icon_key': iconKey, 'amount': 0.0},
      );
      bucket['amount'] =
          (bucket['amount'] as double) +
          ((row['amount'] as num?)?.toDouble() ?? 0);
    }

    final contributionMap = <String, Map<String, dynamic>>{};
    for (final row in filteredContributions) {
      final fundId = row['fund_id'] as String?;
      final name = (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ';
      final iconKey =
          (fundId != null ? fundIconById[fundId] : null) ?? 'savings';
      final key = fundId ?? name;
      final bucket = contributionMap.putIfAbsent(
        key,
        () => {
          'name': name,
          'icon_key': iconKey,
          'amount': fundId != null ? (fundBalanceById[fundId] ?? 0.0) : 0.0,
          'sub_items': <Map<String, dynamic>>[],
        },
      );
      final contribType =
          (row['contribution_type'] as String?) ?? 'contribution';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      (bucket['sub_items'] as List<Map<String, dynamic>>).add({
        'type': contribType,
        'amount': amount,
        'date': row['date'] as String?,
        'description': row['note'] as String?,
      });
    }

    final borrowItems = <Map<String, dynamic>>[];
    final lendItems = <Map<String, dynamic>>[];
    for (final row in debtRows) {
      final debtKind = (row['debt_kind'] as String?) ?? 'debt';
      final recordToIncome = (row['record_to_income'] as bool?) ?? false;
      final linkedExpenseId = row['linked_expense_id'] as String?;
      final debtId = row['id'] as String;
      final startDate = row['start_date'] as String?;
      final isCreatedThisMonth =
          startDate != null &&
          startDate.compareTo(from) >= 0 &&
          startDate.compareTo(to) < 0;
      final isRecorded = debtKind == 'lend'
          ? linkedExpenseId != null
          : recordToIncome;
      final payments = paymentsByDebtId[debtId] ?? const [];

      // Show if: (created this month AND recorded) OR has payments this month
      if (!isCreatedThisMonth && payments.isEmpty) continue;
      if (isCreatedThisMonth && !isRecorded && payments.isEmpty) continue;

      // Only count original amount if the debt was recorded AND created this month
      final originalAmount = (isCreatedThisMonth && isRecorded)
          ? ((row['original_amount'] as num?)?.toDouble() ?? 0)
          : 0.0;
      final debtOriginal = ((row['original_amount'] as num?)?.toDouble() ?? 0);
      final totalPaid = totalPaidAllTimeByDebtId[debtId] ?? 0;
      final amount = (debtOriginal - totalPaid).clamp(0.0, double.infinity);

      final subItems = <Map<String, dynamic>>[];
      if (isCreatedThisMonth && isRecorded && originalAmount > 0) {
        subItems.add({
          'type': debtKind == 'lend' ? 'record_expense' : 'record_income',
          'amount': originalAmount,
          'date': startDate,
          'description': null,
        });
      }
      subItems.addAll(
        payments.map((p) {
          return <String, dynamic>{
            'type': debtKind == 'lend' ? 'receipt' : 'payment',
            'amount': (p['amount'] as num?)?.toDouble() ?? 0,
            'date': p['date'] as String?,
            'description': p['note'] as String?,
          };
        }),
      );

      final item = {
        'id': debtId,
        'name': (row['name'] as String?) ?? 'Khoản nợ',
        'amount': amount,
        'summary_amount': originalAmount,
        'sub_items': subItems,
      };

      if (debtKind == 'lend') {
        lendItems.add(item);
      } else {
        borrowItems.add(item);
      }
    }

    // Compute total payments made (debt_kind == 'debt') and received (lend)
    double totalDebtPaymentMade = 0;
    double totalDebtPaymentReceived = 0;
    for (final row in debtRows) {
      final debtKind = (row['debt_kind'] as String?) ?? 'debt';
      final debtId = row['id'] as String;
      final payments = paymentsByDebtId[debtId] ?? const [];
      final sum = payments.fold<double>(
        0,
        (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0),
      );
      if (debtKind == 'lend') {
        totalDebtPaymentReceived += sum;
      } else {
        totalDebtPaymentMade += sum;
      }
    }

    List<Map<String, dynamic>> sortByAmountDesc(
      Iterable<Map<String, dynamic>> input,
    ) {
      final rows = List<Map<String, dynamic>>.from(input);
      rows.sort(
        (a, b) => ((b['amount'] as num?)?.toDouble() ?? 0).compareTo(
          (a['amount'] as num?)?.toDouble() ?? 0,
        ),
      );
      return rows;
    }

    return {
      'income_by_source': sortByAmountDesc(incomeMap.values),
      'expense_by_category': sortByAmountDesc(expenseMap.values),
      'fund_contribution_by_item': sortByAmountDesc(contributionMap.values),
      'transfer_summary': {'sent': transferSent, 'received': transferReceived},
      'debt_borrowed_by_item': sortByAmountDesc(borrowItems),
      'debt_lent_by_item': sortByAmountDesc(lendItems),
      'totals': {
        'income': manualIncomes.fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        ),
        'expense': manualExpenses.fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        ),
        'fund_contribution': filteredContributions
            .where(
              (row) => (row['contribution_type'] as String?) == 'contribution',
            )
            .fold<double>(
              0,
              (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
            ),
        'fund_withdrawal': filteredContributions
            .where(
              (row) => (row['contribution_type'] as String?) == 'withdrawal',
            )
            .fold<double>(
              0,
              (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
            ),
        'debt_borrow': borrowItems.fold<double>(
          0,
          (sum, row) =>
              sum + ((row['summary_amount'] as num?)?.toDouble() ?? 0),
        ),
        'debt_lend': lendItems.fold<double>(
          0,
          (sum, row) =>
              sum + ((row['summary_amount'] as num?)?.toDouble() ?? 0),
        ),
        'debt_payment_made': totalDebtPaymentMade,
        'debt_payment_received': totalDebtPaymentReceived,
      },
    };
  }
}
