import 'dart:convert';
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
    String cleanFundName(String rawName) {
      if (rawName.startsWith('[GOLD]')) {
        final sepIndex = rawName.indexOf('|');
        if (sepIndex != -1) {
          return rawName.substring(6, sepIndex);
        }
        return rawName.substring(6);
      }
      return rawName;
    }
    final fundNameById = {
      for (final row in funds) row['id'] as String: cleanFundName(row['name'] as String),
    };
    final fundIconById = {
      for (final row in funds)
        row['id'] as String: ((row['icon'] as String?) ?? 'savings'),
    };
    final fundBalanceById = {
      for (final row in funds)
        row['id'] as String: ((row['current_amount'] as num?)?.toDouble() ?? 0),
    };

    final events = await _db
        .from('events')
        .select('id, name')
        .eq('couple_id', coupleId);
    final eventNameById = {
      for (final row in events) row['id'] as String: row['name'] as String,
    };

    var expensesQuery = _db
        .from('expenses')
        .select(
          'id, amount, category_id, category_name, date, description, created_at, event_id, user_id',
        )
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from)
        .lt('date', to);
    var incomesQuery = _db
        .from('incomes')
        .select('id, amount, income_source_id, date, description, created_at, user_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .or('is_from_transfer.is.null,is_from_transfer.eq.false')
        .gte('date', from)
        .lt('date', to);
    var contributionsQuery = _db
        .from('fund_contributions')
        .select(
          'amount, fund_id, contribution_type, date, note, linked_income_id, user_id',
        )
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from)
        .lt('date', to);
    var transfersQuery = _db
        .from('transfers')
        .select('id, amount, from_user_id, to_user_id, date, note, created_at')
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

    List<Map<String, dynamic>> allDebts;
    try {
      var debtsQuery = _db
          .from('debts')
          .select(
            'id, name, debt_kind, original_amount, record_to_income, linked_income_id, linked_expense_id, start_date, user_id, note',
          )
          .eq('couple_id', coupleId)
          .eq('is_deleted', false);
      allDebts = List<Map<String, dynamic>>.from(await debtsQuery);
    } catch (e) {
      if (!_isMissingDebtKindColumn(e)) rethrow;
      var debtsQuery = _db
          .from('debts')
          .select('id, name, original_amount, start_date, user_id, note')
          .eq('couple_id', coupleId)
          .eq('is_deleted', false);
      allDebts = List<Map<String, dynamic>>.from(await debtsQuery)
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

    // Fetch payments in the month for ALL debts of this couple, then decide
    // Build map of expenseId -> expenseAmount to sync edited expenses from Expense List screen
    final expenseAmountById = <String, double>{
      for (final e in expenses)
        if (e['id'] is String && e['amount'] is num)
          e['id'] as String: (e['amount'] as num).toDouble(),
    };

    // Build map of paymentId -> full amount (Gốc + Lãi + Phí) from bank loan schedules & linked expenses
    final bankLoanPaymentFullAmountMap = <String, double>{};
    for (final debt in allDebts) {
      final note = debt['note'] as String?;
      if (note != null && note.trim().startsWith('{')) {
        try {
          final data = jsonDecode(note);
          if (data['is_bank_loan'] == true && data['schedule'] is List) {
            bool scheduleUpdated = false;
            final scheduleList = data['schedule'] as List;

            for (final item in scheduleList) {
              final pid = item['payment_id'] as String? ?? item['paymentId'] as String?;
              final expId = item['expense_id'] as String? ?? item['expenseId'] as String?;
              final isPaid = item['is_paid'] as bool? ?? item['isPaid'] as bool? ?? false;

              if (isPaid) {
                double fullAmount = (item['paid_amount'] as num?)?.toDouble() ?? (item['paidAmount'] as num?)?.toDouble() ?? 0;
                final principal = (item['principal'] as num?)?.toDouble() ?? 0;
                final interest = (item['interest'] as num?)?.toDouble() ?? 0;
                final earlyPrincipal = (item['early_principal'] as num?)?.toDouble() ?? (item['earlyPrincipal'] as num?)?.toDouble() ?? 0;
                final penaltyFee = (item['penalty_fee'] as num?)?.toDouble() ?? (item['penaltyFee'] as num?)?.toDouble() ?? 0;

                if (fullAmount == 0) {
                  fullAmount = principal + interest + earlyPrincipal + penaltyFee;
                }

                // If user edited the linked expense in Expense List screen, use the edited expense amount!
                if (expId != null && expenseAmountById.containsKey(expId)) {
                  final editedExpAmount = expenseAmountById[expId]!;
                  if (editedExpAmount > 0 && editedExpAmount != fullAmount) {
                    fullAmount = editedExpAmount;
                    item['paid_amount'] = editedExpAmount;
                    item['paidAmount'] = editedExpAmount;
                    scheduleUpdated = true;
                  }
                }

                if (pid != null && pid.isNotEmpty && fullAmount > 0) {
                  bankLoanPaymentFullAmountMap[pid] = fullAmount;
                }
              }
            }

            if (scheduleUpdated) {
              final debtId = debt['id'] as String;
              _db.from('debts').update({'note': jsonEncode(data)}).eq('id', debtId).then((_) {}).catchError((_) {});
            }
          }
        } catch (_) {}
      }
    }

    final allDebtIdsForCouple = allDebts.map((r) => r['id'] as String).toList();
    final paymentsByDebtId = <String, List<Map<String, dynamic>>>{};
    if (allDebtIdsForCouple.isNotEmpty) {
      try {
        final paymentRows = List<Map<String, dynamic>>.from(
          await _db
              .from('debt_payments')
              .select('id, debt_id, amount, date, note, linked_income_id, updated_by')
              .inFilter('debt_id', allDebtIdsForCouple)
              .eq('is_deleted', false)
              .gte('date', from)
              .lt('date', to),
        );
        for (final p in paymentRows) {
          final pid = p['debt_id'] as String?;
          if (pid == null) continue;

          // If viewerUserId is specified, only include payments made by this viewer
          if (viewerUserId != null) {
            final updatedBy = p['updated_by'] as String?;
            if (updatedBy != viewerUserId) {
              continue;
            }
          }

          final payId = p['id'] as String?;
          if (payId != null && bankLoanPaymentFullAmountMap.containsKey(payId)) {
            final fullAmount = bankLoanPaymentFullAmountMap[payId]!;
            final currentAmount = (p['amount'] as num?)?.toDouble() ?? 0;
            if (fullAmount != currentAmount) {
              p['amount'] = fullAmount;
              // Sync DB retroactively
              _db.from('debt_payments').update({'amount': fullAmount}).eq('id', payId).then((_) {}).catchError((_) {});
            }
          }

          paymentsByDebtId.putIfAbsent(pid, () => []).add(p);
        }
      } catch (_) {
        // debt_payments might not exist in older schemas — skip gracefully
      }
    }

    // Fetch all-time payments for all debts to compute remaining balance.
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
      ...allDebts
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
      ...paymentsByDebtId.values
          .expand((rows) => rows)
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
    };
    final bankLoanExpenseIds = <String>{};
    for (final row in allDebts) {
      final note = row['note'] as String?;
      if (note != null && note.trim().startsWith('{')) {
        try {
          final data = jsonDecode(note);
          if (data['is_bank_loan'] == true && data['schedule'] is List) {
            for (final item in data['schedule'] as List) {
              final expId = item['expense_id'] as String?;
              if (expId != null) bankLoanExpenseIds.add(expId);
            }
          }
        } catch (_) {}
      }
    }

    final excludedExpenseIds = <String>{
      ...allDebts
          .map((row) => row['linked_expense_id'] as String?)
          .whereType<String>(),
      ...bankLoanExpenseIds,
    };

    // Filter debts and count payments based on belongsToViewer and hasPaymentsThisMonth
    final filteredDebts = <Map<String, dynamic>>[];
    final incrementsTotalThisMonthByDebtId = <String, double>{};
    final extraSubItemsByDebtId = <String, List<Map<String, dynamic>>>{};

    for (final row in allDebts) {
      final debtId = row['id'] as String;
      final belongsToViewer = viewerUserId == null || row['user_id'] == viewerUserId;
      final payments = paymentsByDebtId[debtId] ?? const [];
      final hasPaymentsThisMonth = payments.isNotEmpty;
      final startDate = row['start_date'] as String?;
      final isCreatedThisMonth =
          startDate != null &&
          startDate.compareTo(from) >= 0 &&
          startDate.compareTo(to) < 0;
      final debtKind = (row['debt_kind'] as String?) ?? 'debt';
      final recordToIncome = (row['record_to_income'] as bool?) ?? false;
      final linkedExpenseId = row['linked_expense_id'] as String?;
      final isRecorded = debtKind == 'lend'
          ? linkedExpenseId != null
          : recordToIncome;

      // Parse increments
      final note = row['note'] as String?;
      double incrementRecordedThisMonthTotal = 0;
      final extraSubItems = <Map<String, dynamic>>[];
      if (note != null && note.trim().startsWith('{')) {
        try {
          final data = jsonDecode(note);
          if (data['increments'] is List) {
            for (final inc in data['increments']) {
              final incDate = inc['date'] as String?;
              final incAmount = ((inc['amount'] as num?)?.toDouble() ?? 0);
              final incIncomeId = inc['linked_income_id'] as String?;
              final incExpenseId = inc['linked_expense_id'] as String?;
              final isIncRecorded = debtKind == 'lend'
                  ? incExpenseId != null
                  : incIncomeId != null;
              final isIncThisMonth = incDate != null &&
                  incDate.compareTo(from) >= 0 &&
                  incDate.compareTo(to) < 0;

              if (isIncThisMonth && isIncRecorded) {
                if (belongsToViewer) {
                  incrementRecordedThisMonthTotal += incAmount;
                  extraSubItems.add({
                    'type': debtKind == 'lend' ? 'record_expense' : 'record_income',
                    'amount': incAmount,
                    'date': incDate,
                    'description': (inc['note'] as String?)?.trim().isNotEmpty == true
                        ? 'Tăng thêm: ${inc['note']}'
                        : 'Mượn nợ thêm',
                  });
                }
              }
            }
          }
        } catch (_) {}
      }

      final hasIncrementsThisMonth = incrementRecordedThisMonthTotal > 0;

      // Show if: (created this month AND recorded AND belongs to viewer) OR has payments this month OR has increments this month
      if (!isCreatedThisMonth && !hasPaymentsThisMonth && !hasIncrementsThisMonth) continue;
      if (isCreatedThisMonth && ((!isRecorded || !belongsToViewer) && !hasPaymentsThisMonth && !hasIncrementsThisMonth)) continue;

      incrementsTotalThisMonthByDebtId[debtId] = incrementRecordedThisMonthTotal;
      extraSubItemsByDebtId[debtId] = extraSubItems;
      filteredDebts.add(row);
    }

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
    final manualExpenses = expenses.where((row) {
      final expId = row['id'] as String?;
      if (excludedExpenseIds.contains(expId)) return false;

      final catId = row['category_id'] as String?;
      final catName = ((catId != null ? categoryNameById[catId] : null) ?? (row['category_name'] as String?) ?? '')
          .trim()
          .toLowerCase();
      if (catName == 'trả nợ gốc & lãi' || catName == 'trả nợ' || catName == 'trả nợ ngân hàng') {
        return false;
      }
      return true;
    }).toList();

    final expenseMap = <String, Map<String, dynamic>>{};
    for (final row in manualExpenses) {
      final categoryId = row['category_id'] as String?;
      final fallbackName = (row['category_name'] as String?) ?? 'Khác';
      final eventId = row['event_id'] as String?;

      final String key;
      final String name;
      final String iconKey;

      if (eventId != null) {
        key = 'event_$eventId';
        name = eventNameById[eventId] ?? 'Sự kiện';
        iconKey = 'event_note';
      } else {
        key = categoryId ?? fallbackName;
        name = (categoryId != null ? categoryNameById[categoryId] : null) ?? fallbackName;
        iconKey = (categoryId != null ? categoryIconById[categoryId] : null) ?? 'label';
      }

      final bucket = expenseMap.putIfAbsent(
        key,
        () => {
          'name': name,
          'bucket_id': key,
          'icon_key': iconKey,
          'amount': 0.0,
        },
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
        () => {
          'name': name,
          'bucket_id': key,
          'icon_key': iconKey,
          'amount': 0.0,
        },
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
      
      final noteVal = row['note'] as String?;
      String formattedDesc = '';
      if (noteVal != null && noteVal.trim().isNotEmpty) {
        if (noteVal.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(noteVal.substring(6));
            if (decoded is Map) {
              final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
              final store = (decoded['store'] ?? decoded['shop'] ?? decoded['goldStore'] ?? decoded['gold_store'])?.toString();
              final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
              formattedDesc = contribType == 'withdrawal'
                  ? 'Rút $qty chỉ vàng'
                  : 'Góp $qty chỉ vàng';
              if (store != null && store.trim().isNotEmpty) {
                formattedDesc += ' tại ${store.trim()}';
              }
              if (userNote != null && userNote.trim().isNotEmpty) {
                formattedDesc += ' ($userNote)';
              }
            } else {
              formattedDesc = noteVal;
            }
          } catch (_) {
            formattedDesc = noteVal;
          }
        } else if (noteVal.startsWith('[WITHDRAWAL]')) {
          try {
            final decoded = jsonDecode(noteVal.substring(12));
            if (decoded is Map) {
              final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
              formattedDesc = (userNote != null && userNote.trim().isNotEmpty)
                  ? userNote.trim()
                  : (contribType == 'withdrawal' ? 'Rút quỹ' : 'Góp quỹ');
            } else {
              formattedDesc = noteVal;
            }
          } catch (_) {
            formattedDesc = noteVal;
          }
        } else {
          formattedDesc = noteVal;
        }
      } else {
        formattedDesc = contribType == 'withdrawal' ? 'Rút quỹ' : 'Góp quỹ';
      }

      (bucket['sub_items'] as List<Map<String, dynamic>>).add({
        'type': contribType,
        'amount': amount,
        'date': row['date'] as String?,
        'description': formattedDesc,
      });
    }

    final borrowItems = <Map<String, dynamic>>[];
    final lendItems = <Map<String, dynamic>>[];
    for (final row in filteredDebts) {
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
      final belongsToViewer = viewerUserId == null || row['user_id'] == viewerUserId;

      // Parse all-time increments to compute the base debt amount
      double totalIncrementsAllTime = 0;
      final note = row['note'] as String?;
      if (note != null && note.trim().startsWith('{')) {
        try {
          final data = jsonDecode(note);
          if (data['increments'] is List) {
            for (final inc in data['increments']) {
              totalIncrementsAllTime += ((inc['amount'] as num?)?.toDouble() ?? 0);
            }
          }
        } catch (_) {}
      }

      final debtOriginal = ((row['original_amount'] as num?)?.toDouble() ?? 0);
      final baseOriginalAmount = (debtOriginal - totalIncrementsAllTime).clamp(0.0, double.infinity);

      final baseOriginalAmountToShow = (isCreatedThisMonth && isRecorded && belongsToViewer)
          ? baseOriginalAmount
          : 0.0;

      final incrementRecordedThisMonthTotal = incrementsTotalThisMonthByDebtId[debtId] ?? 0.0;
      final summaryAmount = baseOriginalAmountToShow + incrementRecordedThisMonthTotal;

      final totalPaid = totalPaidAllTimeByDebtId[debtId] ?? 0;
      final amount = (debtOriginal - totalPaid).clamp(0.0, double.infinity);

      final subItems = <Map<String, dynamic>>[];
      if (isCreatedThisMonth && isRecorded && baseOriginalAmountToShow > 0) {
        subItems.add({
          'type': debtKind == 'lend' ? 'record_expense' : 'record_income',
          'amount': baseOriginalAmountToShow,
          'date': startDate,
          'description': null,
        });
      }

      // Add monthly increments
      final extraSubItems = extraSubItemsByDebtId[debtId] ?? const <Map<String, dynamic>>[];
      subItems.addAll(extraSubItems);

      // Add payments
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
        'summary_amount': summaryAmount,
        'sub_items': subItems,
        'user_id': row['user_id'] as String?,
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
    for (final row in filteredDebts) {
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
      'income_transactions': manualIncomes.map((row) {
        final sourceId = row['income_source_id'] as String?;
        final sourceName =
            (sourceId != null ? incomeSourceNameById[sourceId] : null) ??
            'Khác';
        final sourceIcon =
            (sourceId != null ? incomeSourceIconById[sourceId] : null) ??
            'payments';
        final dateValue = row['date'] as String?;
        final createdAt =
            (row['created_at'] as String?) ??
            (dateValue == null ? null : '${dateValue}T00:00:00Z');
        return <String, dynamic>{
          'id': row['id'] as String?,
          'kind': 'income',
          'bucket_id': sourceId ?? sourceName,
          'bucket_name': sourceName,
          'title': (row['description'] as String?)?.trim().isNotEmpty == true
              ? (row['description'] as String).trim()
              : sourceName,
          'icon_key': sourceIcon,
          'amount': (row['amount'] as num?)?.toDouble() ?? 0,
          'date': row['date'] as String?,
          'created_at': createdAt,
          'user_id': row['user_id'] as String?,
        };
      }).toList(),
      'expense_transactions': manualExpenses.map((row) {
        final categoryId = row['category_id'] as String?;
        final fallbackName = (row['category_name'] as String?) ?? 'Khác';
        final categoryName =
            (categoryId != null ? categoryNameById[categoryId] : null) ??
            fallbackName;
        final categoryIcon =
            (categoryId != null ? categoryIconById[categoryId] : null) ??
            'label';
        final dateValue = row['date'] as String?;
        final createdAt =
            (row['created_at'] as String?) ??
            (dateValue == null ? null : '${dateValue}T00:00:00Z');

        final eventId = row['event_id'] as String?;

        final resolvedBucketId = eventId != null ? 'event_$eventId' : (categoryId ?? fallbackName);
        final resolvedBucketName = eventId != null ? (eventNameById[eventId] ?? 'Sự kiện') : categoryName;
        final resolvedIcon = categoryIcon;

        String resolvedTitle = (row['description'] as String?)?.trim().isNotEmpty == true
            ? (row['description'] as String).trim()
            : categoryName;

        return <String, dynamic>{
          'id': row['id'] as String?,
          'kind': 'expense',
          'bucket_id': resolvedBucketId,
          'bucket_name': resolvedBucketName,
          'title': resolvedTitle,
          'icon_key': resolvedIcon,
          'amount': (row['amount'] as num?)?.toDouble() ?? 0,
          'date': row['date'] as String?,
          'created_at': createdAt,
          'user_id': row['user_id'] as String?,
        };
      }).toList(),
      'transfer_sent_transactions': transfers
          .where((row) => (row['from_user_id'] as String?) == viewerUserId)
          .map((row) {
            final dateValue = row['date'] as String?;
            final createdAt =
                (row['created_at'] as String?) ??
                (dateValue == null ? null : '${dateValue}T00:00:00Z');
            return <String, dynamic>{
              'id': row['id'] as String?,
              'kind': 'transfer_sent',
              'title': (row['note'] as String?)?.trim().isNotEmpty == true
                  ? (row['note'] as String).trim()
                  : 'Chuyển tiền',
              'icon_key': 'sync_alt',
              'amount': (row['amount'] as num?)?.toDouble() ?? 0,
              'date': row['date'] as String?,
              'created_at': createdAt,
            };
          })
          .toList(),
      'transfer_received_transactions': transfers
          .where((row) => (row['to_user_id'] as String?) == viewerUserId)
          .map((row) {
            final dateValue = row['date'] as String?;
            final createdAt =
                (row['created_at'] as String?) ??
                (dateValue == null ? null : '${dateValue}T00:00:00Z');
            return <String, dynamic>{
              'id': row['id'] as String?,
              'kind': 'transfer_received',
              'title': (row['note'] as String?)?.trim().isNotEmpty == true
                  ? (row['note'] as String).trim()
                  : 'Nhận tiền',
              'icon_key': 'sync_alt',
              'amount': (row['amount'] as num?)?.toDouble() ?? 0,
              'date': row['date'] as String?,
              'created_at': createdAt,
            };
          })
          .toList(),
      'fund_contribution_transactions': filteredContributions
          .where(
            (row) => (row['contribution_type'] as String?) == 'contribution',
          )
          .map((row) {
            final fundId = row['fund_id'] as String?;
            final fundName =
                (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ';
            final fundIcon =
                (fundId != null ? fundIconById[fundId] : null) ?? 'savings';
            final noteVal = row['note'] as String?;
            String formattedTitle = 'Góp quỹ $fundName';
            if (noteVal != null && noteVal.trim().isNotEmpty) {
              if (noteVal.startsWith('[GOLD]')) {
                try {
                  final decoded = jsonDecode(noteVal.substring(6));
                  if (decoded is Map) {
                    final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
                    final store = (decoded['store'] ?? decoded['shop'] ?? decoded['goldStore'] ?? decoded['gold_store'])?.toString();
                    final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
                    formattedTitle = 'Góp $qty chỉ vàng';
                    if (store != null && store.trim().isNotEmpty) {
                      formattedTitle += ' tại ${store.trim()}';
                    }
                    if (userNote != null && userNote.trim().isNotEmpty) {
                      formattedTitle += ' ($userNote)';
                    }
                  } else {
                    formattedTitle = noteVal;
                  }
                } catch (_) {
                  formattedTitle = noteVal;
                }
              } else {
                // Plain note (non-gold contribution)
                formattedTitle = 'Góp quỹ $fundName: ${noteVal.trim()}';
              }
            }
            return <String, dynamic>{
              'kind': 'fund_contribution',
              'bucket_id': fundId ?? fundName,
              'bucket_name': fundName,
              'title': formattedTitle,
              'icon_key': fundIcon,
              'amount': (row['amount'] as num?)?.toDouble() ?? 0,
              'date': row['date'] as String?,
              'created_at': (row['date'] as String?) == null
                  ? null
                  : '${row['date'] as String}T00:00:00Z',
              'user_id': row['user_id'] as String?,
            };
          })
          .toList(),
      'fund_withdrawal_transactions': filteredContributions
          .where((row) => (row['contribution_type'] as String?) == 'withdrawal')
          .map((row) {
            final fundId = row['fund_id'] as String?;
            final fundName =
                (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ';
            final fundIcon =
                (fundId != null ? fundIconById[fundId] : null) ?? 'savings';
            final noteVal = row['note'] as String?;
            String formattedTitle = 'Rút quỹ $fundName';
            if (noteVal != null && noteVal.trim().isNotEmpty) {
              if (noteVal.startsWith('[GOLD]')) {
                try {
                  final decoded = jsonDecode(noteVal.substring(6));
                  if (decoded is Map) {
                    final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
                    final store = (decoded['store'] ?? decoded['shop'] ?? decoded['goldStore'] ?? decoded['gold_store'])?.toString();
                    final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
                    formattedTitle = 'Rút $qty chỉ vàng';
                    if (store != null && store.trim().isNotEmpty) {
                      formattedTitle += ' tại ${store.trim()}';
                    }
                    if (userNote != null && userNote.trim().isNotEmpty) {
                      formattedTitle += ' ($userNote)';
                    }
                  } else {
                    formattedTitle = noteVal;
                  }
                } catch (_) {
                  formattedTitle = noteVal;
                }
              } else if (noteVal.startsWith('[WITHDRAWAL]')) {
                try {
                  final decoded = jsonDecode(noteVal.substring(12));
                  if (decoded is Map) {
                    final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
                    formattedTitle = (userNote != null && userNote.trim().isNotEmpty)
                        ? 'Rút quỹ $fundName: ${userNote.trim()}'
                        : 'Rút quỹ $fundName';
                  } else {
                    formattedTitle = 'Rút quỹ $fundName';
                  }
                } catch (_) {
                  formattedTitle = 'Rút quỹ $fundName';
                }
              } else {
                formattedTitle = 'Rút quỹ $fundName: ${noteVal.trim()}';
              }
            }
            return <String, dynamic>{
              'kind': 'fund_withdrawal',
              'bucket_id': fundId ?? fundName,
              'bucket_name': fundName,
              'title': formattedTitle,
              'icon_key': fundIcon,
              'amount': (row['amount'] as num?)?.toDouble() ?? 0,
              'date': row['date'] as String?,
              'created_at': (row['date'] as String?) == null
                  ? null
                  : '${row['date'] as String}T00:00:00Z',
              'user_id': row['user_id'] as String?,
            };
          })
          .toList(),
      'debt_borrow_transactions': borrowItems
          .where(
            ((row) => ((row['summary_amount'] as num?)?.toDouble() ?? 0) > 0),
          )
          .map((row) {
            final subItems =
                (row['sub_items'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[];
            final created = subItems.firstWhere(
              (sub) => (sub['type'] as String?) == 'record_income',
              orElse: () => const <String, dynamic>{},
            );
            return <String, dynamic>{
              'kind': 'debt_borrow',
              'bucket_id': row['id'] as String?,
              'bucket_name': row['name'] as String?,
              'title': (row['name'] as String?) ?? 'Khoản mượn nợ',
              'icon_key': 'request_quote',
              'amount': (row['summary_amount'] as num?)?.toDouble() ?? 0,
              'date': created['date'] as String?,
              'created_at': (created['date'] as String?) == null
                  ? null
                  : '${created['date'] as String}T00:00:00Z',
              'user_id': row['user_id'] as String?,
            };
          })
          .toList(),
      'debt_lend_transactions': lendItems
          .where(
            ((row) => ((row['summary_amount'] as num?)?.toDouble() ?? 0) > 0),
          )
          .map((row) {
            final subItems =
                (row['sub_items'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[];
            final created = subItems.firstWhere(
              (sub) => (sub['type'] as String?) == 'record_expense',
              orElse: () => const <String, dynamic>{},
            );
            return <String, dynamic>{
              'kind': 'debt_lend',
              'bucket_id': row['id'] as String?,
              'bucket_name': row['name'] as String?,
              'title': (row['name'] as String?) ?? 'Khoản cho mượn',
              'icon_key': 'account_balance_wallet',
              'amount': (row['summary_amount'] as num?)?.toDouble() ?? 0,
              'date': created['date'] as String?,
              'created_at': (created['date'] as String?) == null
                  ? null
                  : '${created['date'] as String}T00:00:00Z',
              'user_id': row['user_id'] as String?,
            };
          })
          .toList(),
      'debt_payment_made_transactions': filteredDebts
          .where((row) => ((row['debt_kind'] as String?) ?? 'debt') != 'lend')
          .expand((row) {
            final debtId = row['id'] as String;
            final payments =
                paymentsByDebtId[debtId] ?? const <Map<String, dynamic>>[];
            final debtName = (row['name'] as String?) ?? 'Khoản nợ';
            return payments.map((payment) {
              return <String, dynamic>{
                'kind': 'debt_payment_made',
                'bucket_id': debtId,
                'bucket_name': debtName,
                'title': (payment['note'] as String?)?.trim().isNotEmpty == true
                    ? (payment['note'] as String).trim()
                    : 'Trả nợ $debtName',
                'icon_key': 'outbox',
                'amount': (payment['amount'] as num?)?.toDouble() ?? 0,
                'date': payment['date'] as String?,
                'created_at': (payment['date'] as String?) == null
                    ? null
                    : '${payment['date'] as String}T00:00:00Z',
                'user_id': payment['updated_by'] as String? ?? row['user_id'] as String?,
              };
            });
          })
          .toList(),
      'debt_payment_received_transactions': filteredDebts
          .where((row) => ((row['debt_kind'] as String?) ?? 'debt') == 'lend')
          .expand((row) {
            final debtId = row['id'] as String;
            final payments =
                paymentsByDebtId[debtId] ?? const <Map<String, dynamic>>[];
            final debtName = (row['name'] as String?) ?? 'Khoản cho mượn';
            return payments.map((payment) {
              return <String, dynamic>{
                'kind': 'debt_payment_received',
                'bucket_id': debtId,
                'bucket_name': debtName,
                'title': (payment['note'] as String?)?.trim().isNotEmpty == true
                    ? (payment['note'] as String).trim()
                    : 'Nhận trả nợ $debtName',
                'icon_key': 'move_to_inbox',
                'amount': (payment['amount'] as num?)?.toDouble() ?? 0,
                'date': payment['date'] as String?,
                'created_at': (payment['date'] as String?) == null
                    ? null
                    : '${payment['date'] as String}T00:00:00Z',
                'user_id': payment['updated_by'] as String? ?? row['user_id'] as String?,
              };
            });
          })
          .toList(),
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
            .where((row) {
              final noteVal = row['note'] as String?;
              if (noteVal != null && noteVal.startsWith('[GOLD]')) {
                try {
                  final decoded = jsonDecode(noteVal.substring(6));
                  if (decoded is Map) {
                    final expVal = decoded['record_as_expense'] ?? decoded['recordAsExpense'];
                    if (expVal == false) {
                      return false;
                    }
                  }
                } catch (_) {}
              }
              return true;
            })
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
