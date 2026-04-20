import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_payment_model.dart';

class DebtService {
  SupabaseClient get _db => Supabase.instance.client;

  bool _isMissingSortOrderColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('sort_order');
  }

  bool _isMissingQuickAddColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('show_in_quick_add');
  }

  bool _isMissingExpenseFormColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('show_in_expense_form');
  }

  bool _isMissingIncomeFormColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('show_in_income_form');
  }

  static const String _debtInitIncomeSource = 'Nhan tien no';
  static const String _debtRepaymentIncomeSource = 'Thu hoi cho muon';
  static const String _debtLendExpenseCategory = 'Cho mượn no';
  static const String _debtDeleteExpenseCategory = 'Xóa no dieu chinh';
  static const String _debtDeleteIncomeSource = 'Xóa cho muon dieu chinh';

  Future<List<DebtModel>> getDebts(String coupleId) async {
    try {
      final rows = await _db
          .from('debts')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order')
          .order('created_at');
      return rows.map((r) => DebtModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final rows = await _db
          .from('debts')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('due_date');
      return rows.map((r) => DebtModel.fromJson(r)).toList();
    }
  }

  Future<int> _nextSortOrder(String coupleId) async {
    try {
      final rows = await _db
          .from('debts')
          .select('sort_order')
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order', ascending: false)
          .limit(1);
      if (rows.isEmpty) return 0;
      return ((rows.first['sort_order'] as num?)?.toInt() ?? 0) + 1;
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      return 0;
    }
  }

  Future<DebtModel> createDebt({
    required String coupleId,
    required String userId,
    required String debtTypeId,
    required String debtKind,
    required bool recordToIncome,
    required bool recordToExpense,
    required String name,
    required double originalAmount,
    required String creditorName,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
    int? reminderDaysBefore,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'user_id': userId,
      'debt_type_id': debtTypeId,
      'debt_kind': debtKind,
      'record_to_income': recordToIncome,
      'name': name,
      'original_amount': originalAmount,
      'remaining_amount': originalAmount,
      'creditor_name': creditorName,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'note': note,
      'reminder_days_before': reminderDaysBefore,
      'is_closed': false,
      'sort_order': await _nextSortOrder(coupleId),
    };

    late final Map<String, dynamic> row;
    try {
      row = await _db.from('debts').insert(payload).select().single();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      payload.remove('sort_order');
      row = await _db.from('debts').insert(payload).select().single();
    }

    final debtId = row['id'] as String;
    String? createdIncomeId;
    String? createdExpenseId;

    try {
      final defaultWalletId = await _resolveDefaultWalletId(coupleId);

      if (debtKind == 'debt' && recordToIncome) {
        if (defaultWalletId == null) {
          throw Exception('Chua co vi mac dinh de ghi nhan thu nhap tu no.');
        }
        final incomeSourceId = await _ensureIncomeSource(
          coupleId,
          _debtInitIncomeSource,
          icon: 'request_quote',
        );
        final incomeRow = await _db
            .from('incomes')
            .insert({
              'couple_id': coupleId,
              'user_id': userId,
              'wallet_id': defaultWalletId,
              'income_source_id': incomeSourceId,
              'amount': originalAmount,
              'description': note?.trim().isNotEmpty == true
                  ? note!.trim()
                  : 'Nhan no: $name',
              'is_from_transfer': false,
              'date': startDate.toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        createdIncomeId = incomeRow['id'] as String;
      }

      if (debtKind == 'lend' && recordToExpense) {
        if (defaultWalletId == null) {
          throw Exception('Chua co vi mac dinh de ghi nhan cho muon.');
        }
        final categoryId = await _ensureExpenseCategory(
          coupleId,
          _debtLendExpenseCategory,
          icon: 'payments',
          color: '#F97316',
        );
        final expenseRow = await _db
            .from('expenses')
            .insert({
              'couple_id': coupleId,
              'user_id': userId,
              'wallet_id': defaultWalletId,
              'category_id': categoryId,
              'amount': originalAmount,
              'description': note?.trim().isNotEmpty == true
                  ? note!.trim()
                  : 'Cho mượn: $name',
              'date': startDate.toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        createdExpenseId = expenseRow['id'] as String;
      }

      if (createdIncomeId != null || createdExpenseId != null) {
        await _db
            .from('debts')
            .update({
              'linked_income_id': createdIncomeId,
              'linked_expense_id': createdExpenseId,
            })
            .eq('id', debtId);
      }

      final updated = await _db
          .from('debts')
          .select()
          .eq('id', debtId)
          .single();
      return DebtModel.fromJson(updated);
    } catch (_) {
      if (createdIncomeId != null) {
        await _db.from('incomes').delete().eq('id', createdIncomeId);
      }
      if (createdExpenseId != null) {
        await _db.from('expenses').delete().eq('id', createdExpenseId);
      }
      await _db.from('debts').delete().eq('id', debtId);
      rethrow;
    }
  }

  Future<DebtModel> getDebtById(String debtId) async {
    final row = await _db.from('debts').select().eq('id', debtId).single();
    return DebtModel.fromJson(row);
  }

  Future<void> updateDebt({
    required String debtId,
    required String debtTypeId,
    required String debtKind,
    required bool recordToIncome,
    required bool recordToExpense,
    required String name,
    required double originalAmount,
    required String creditorName,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
  }) async {
    final existingDebt = await _db
        .from('debts')
        .select('couple_id, user_id, linked_income_id, linked_expense_id')
        .eq('id', debtId)
        .single();
    var linkedIncomeId = existingDebt['linked_income_id'] as String?;
    var linkedExpenseId = existingDebt['linked_expense_id'] as String?;

    final dateIso = startDate.toIso8601String().substring(0, 10);
    final incomeDescription = note?.trim().isNotEmpty == true
        ? note!.trim()
        : 'Nhan no: $name';
    final expenseDescription = note?.trim().isNotEmpty == true
        ? note!.trim()
        : 'Cho mượn: $name';

    final payments = await _db
        .from('debt_payments')
        .select('amount')
        .eq('debt_id', debtId)
        .eq('is_deleted', false);
    final paidTotal = payments.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
    final nextRemaining = (originalAmount - paidTotal).clamp(0, originalAmount);

    await _db
        .from('debts')
        .update({
          'debt_type_id': debtTypeId,
          'debt_kind': debtKind,
          'record_to_income': recordToIncome,
          'name': name,
          'original_amount': originalAmount,
          'remaining_amount': nextRemaining,
          'creditor_name': creditorName,
          'start_date': dateIso,
          'due_date': dueDate?.toIso8601String().substring(0, 10),
          'note': note,
          'is_closed': nextRemaining <= 0,
        })
        .eq('id', debtId);

    if (debtKind == 'debt' && recordToIncome) {
      final incomeSourceId = await _ensureIncomeSource(
        existingDebt['couple_id'] as String,
        _debtInitIncomeSource,
        icon: 'request_quote',
      );

      if (linkedIncomeId != null) {
        final incomeRows = await _db
            .from('incomes')
            .select('id, wallet_id, is_deleted')
            .eq('id', linkedIncomeId)
            .limit(1);

        if (incomeRows.isNotEmpty && incomeRows.first['is_deleted'] == false) {
          final incomeWalletId = incomeRows.first['wallet_id'] as String?;
          final fallbackWalletId =
              incomeWalletId ??
              await _resolveDefaultWalletId(
                existingDebt['couple_id'] as String,
              );
          if (fallbackWalletId == null) {
            throw Exception('Chua co vi de cap nhat ghi nhan thu nhap tu no.');
          }
          await _db
              .from('incomes')
              .update({
                'user_id': existingDebt['user_id'] as String,
                'wallet_id': fallbackWalletId,
                'income_source_id': incomeSourceId,
                'amount': originalAmount,
                'description': incomeDescription,
                'date': dateIso,
              })
              .eq('id', linkedIncomeId)
              .eq('is_deleted', false);
        } else {
          linkedIncomeId = null;
        }
      }

      if (linkedIncomeId == null) {
        final defaultWalletId = await _resolveDefaultWalletId(
          existingDebt['couple_id'] as String,
        );
        if (defaultWalletId == null) {
          throw Exception('Chua co vi de ghi nhan thu nhap tu no.');
        }
        final createdIncome = await _db
            .from('incomes')
            .insert({
              'couple_id': existingDebt['couple_id'] as String,
              'user_id': existingDebt['user_id'] as String,
              'wallet_id': defaultWalletId,
              'income_source_id': incomeSourceId,
              'amount': originalAmount,
              'description': incomeDescription,
              'is_from_transfer': false,
              'date': dateIso,
            })
            .select('id')
            .single();
        linkedIncomeId = createdIncome['id'] as String;
      }
    } else if (linkedIncomeId != null) {
      await _db
          .from('incomes')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', linkedIncomeId)
          .eq('is_deleted', false);
      linkedIncomeId = null;
    }

    if (debtKind == 'lend' && recordToExpense) {
      final categoryId = await _ensureExpenseCategory(
        existingDebt['couple_id'] as String,
        _debtLendExpenseCategory,
        icon: 'payments',
        color: '#F97316',
      );

      if (linkedExpenseId != null) {
        final expenseRows = await _db
            .from('expenses')
            .select('id, wallet_id, is_deleted')
            .eq('id', linkedExpenseId)
            .limit(1);

        if (expenseRows.isNotEmpty &&
            expenseRows.first['is_deleted'] == false) {
          final expenseWalletId = expenseRows.first['wallet_id'] as String?;
          final fallbackWalletId =
              expenseWalletId ??
              await _resolveDefaultWalletId(
                existingDebt['couple_id'] as String,
              );
          if (fallbackWalletId == null) {
            throw Exception('Chua co vi de cap nhat giao dich cho muon.');
          }
          await _db
              .from('expenses')
              .update({
                'user_id': existingDebt['user_id'] as String,
                'wallet_id': fallbackWalletId,
                'category_id': categoryId,
                'amount': originalAmount,
                'description': expenseDescription,
                'date': dateIso,
              })
              .eq('id', linkedExpenseId)
              .eq('is_deleted', false);
        } else {
          linkedExpenseId = null;
        }
      }

      if (linkedExpenseId == null) {
        final defaultWalletId = await _resolveDefaultWalletId(
          existingDebt['couple_id'] as String,
        );
        if (defaultWalletId == null) {
          throw Exception('Chua co vi de ghi nhan giao dich cho muon.');
        }
        final createdExpense = await _db
            .from('expenses')
            .insert({
              'couple_id': existingDebt['couple_id'] as String,
              'user_id': existingDebt['user_id'] as String,
              'wallet_id': defaultWalletId,
              'category_id': categoryId,
              'amount': originalAmount,
              'description': expenseDescription,
              'date': dateIso,
            })
            .select('id')
            .single();
        linkedExpenseId = createdExpense['id'] as String;
      }
    } else if (linkedExpenseId != null) {
      await _db
          .from('expenses')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', linkedExpenseId)
          .eq('is_deleted', false);
      linkedExpenseId = null;
    }

    await _db
        .from('debts')
        .update({
          'linked_income_id': linkedIncomeId,
          'linked_expense_id': linkedExpenseId,
        })
        .eq('id', debtId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deleteDebt(String debtId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Không tìm thấy phiên đăng nhập.');
    }

    final debt = await _db
        .from('debts')
        .select('couple_id, user_id, name, linked_income_id, linked_expense_id')
        .eq('id', debtId)
        .single();

    final creatorUserId = debt['user_id'] as String?;
    if (creatorUserId != null && creatorUserId != currentUserId) {
      throw Exception('Chỉ người tạo khoản nợ mới có quyền xóa.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final adjustment = await _calculateDeleteDebtAdjustment(
      debtId,
      debtRow: debt,
    );

    if (adjustment < 0) {
      final defaultWalletId = await _resolveDefaultWalletId(
        debt['couple_id'] as String,
      );
      if (defaultWalletId != null) {
        final categoryId = await _ensureExpenseCategory(
          debt['couple_id'] as String,
          _debtDeleteExpenseCategory,
          icon: 'money_off',
          color: '#EF4444',
        );
        await _db.from('expenses').insert({
          'couple_id': debt['couple_id'] as String,
          'user_id': debt['user_id'] as String,
          'wallet_id': defaultWalletId,
          'category_id': categoryId,
          'amount': adjustment.abs(),
          'description':
              'Dieu chinh khi xoa khoan no ${(debt['name'] as String?) ?? ''}'
                  .trim(),
          'date': DateTime.now().toIso8601String().substring(0, 10),
        });
      }
    }

    if (adjustment > 0) {
      final defaultWalletId = await _resolveDefaultWalletId(
        debt['couple_id'] as String,
      );
      if (defaultWalletId != null) {
        final incomeSourceId = await _ensureIncomeSource(
          debt['couple_id'] as String,
          _debtDeleteIncomeSource,
          icon: 'undo',
        );
        await _db.from('incomes').insert({
          'couple_id': debt['couple_id'] as String,
          'user_id': debt['user_id'] as String,
          'wallet_id': defaultWalletId,
          'income_source_id': incomeSourceId,
          'amount': adjustment,
          'description':
              'Dieu chinh khi xoa cho muon ${(debt['name'] as String?) ?? ''}'
                  .trim(),
          'is_from_transfer': false,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        });
      }
    }

    await _db
        .from('debts')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('id', debtId);
  }

  Future<double> previewDeleteDebtImpact(String debtId) async {
    final debt = await _db
        .from('debts')
        .select('linked_income_id, linked_expense_id')
        .eq('id', debtId)
        .single();

    return _calculateDeleteDebtAdjustment(debtId, debtRow: debt);
  }

  Future<double> _calculateDeleteDebtAdjustment(
    String debtId, {
    required Map<String, dynamic> debtRow,
  }) async {
    final linkedIncomeAmount = await _getActiveIncomeAmount(
      debtRow['linked_income_id'] as String?,
    );
    final linkedExpenseAmount = await _getActiveExpenseAmount(
      debtRow['linked_expense_id'] as String?,
    );

    final paymentRows = await _db
        .from('debt_payments')
        .select('linked_income_id')
        .eq('debt_id', debtId)
        .eq('is_deleted', false)
        .not('linked_income_id', 'is', null);
    final paymentIncomeIds = paymentRows
        .map((row) => row['linked_income_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final paymentIncomeTotal = await _getActiveIncomeTotalByIds(
      paymentIncomeIds,
    );
    final paymentExpenseTotal = await _getActiveDebtPaymentExpenseTotal(debtId);

    // Positive: add money back. Negative: subtract money.
    return linkedExpenseAmount +
        paymentExpenseTotal -
        linkedIncomeAmount -
        paymentIncomeTotal;
  }

  Future<double> _getActiveDebtPaymentExpenseTotal(String debtId) async {
    final rows = await _db
        .from('debt_payments')
        .select('amount')
        .eq('debt_id', debtId)
        .eq('is_deleted', false)
        .isFilter('linked_income_id', null);

    return rows.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<double> _getActiveIncomeAmount(String? incomeId) async {
    if (incomeId == null) return 0;
    final rows = await _db
        .from('incomes')
        .select('amount')
        .eq('id', incomeId)
        .eq('is_deleted', false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['amount'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getActiveExpenseAmount(String? expenseId) async {
    if (expenseId == null) return 0;
    final rows = await _db
        .from('expenses')
        .select('amount')
        .eq('id', expenseId)
        .eq('is_deleted', false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['amount'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getActiveIncomeTotalByIds(List<String> incomeIds) async {
    if (incomeIds.isEmpty) return 0;
    final rows = await _db
        .from('incomes')
        .select('amount')
        .inFilter('id', incomeIds)
        .eq('is_deleted', false);
    return rows.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<double> previewDeletePaymentImpact(String paymentId) async {
    final row = await _db
        .from('debt_payments')
        .select('amount, linked_income_id')
        .eq('id', paymentId)
        .eq('is_deleted', false)
        .single();

    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final linkedIncomeId = row['linked_income_id'] as String?;
    if (linkedIncomeId != null) {
      return -amount;
    }
    return 0;
  }

  Future<List<DebtPaymentModel>> getPaymentsByDebt({
    required String coupleId,
    required String debtId,
  }) async {
    final rows = await _db
        .from('debt_payments')
        .select()
        .eq('couple_id', coupleId)
        .eq('debt_id', debtId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows.map((r) => DebtPaymentModel.fromJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getDebtTypes(String coupleId) async {
    final rows = await _db
        .from('debt_types')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createDebtType({
    required String coupleId,
    required String name,
  }) async {
    final row = await _db
        .from('debt_types')
        .insert({'couple_id': coupleId, 'name': name})
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> updateDebtOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    for (var i = 0; i < orderedIds.length; i++) {
      try {
        await _db
            .from('debts')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      } catch (e) {
        if (_isMissingSortOrderColumn(e)) {
          return;
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> updateDebtType({
    required String debtTypeId,
    required String name,
  }) async {
    final row = await _db
        .from('debt_types')
        .update({'name': name})
        .eq('id', debtTypeId)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> deleteDebtType(String debtTypeId) async {
    await _db
        .from('debt_types')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', debtTypeId);
  }

  Future<DebtPaymentModel> createPayment({
    required String coupleId,
    required String debtId,
    required String walletId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final debt = await _db
        .from('debts')
        .select('id, couple_id, user_id, debt_kind, name')
        .eq('id', debtId)
        .single();
    final debtKind = (debt['debt_kind'] as String?) ?? 'debt';

    final row = await _db
        .from('debt_payments')
        .insert({
          'couple_id': coupleId,
          'debt_id': debtId,
          'wallet_id': walletId,
          'amount': amount,
          'date': date.toIso8601String().substring(0, 10),
          'note': note,
        })
        .select()
        .single();

    final paymentId = row['id'] as String;

    if (debtKind == 'lend') {
      final incomeSourceId = await _ensureIncomeSource(
        coupleId,
        _debtRepaymentIncomeSource,
        icon: 'account_balance_wallet',
      );
      final incomeRow = await _db
          .from('incomes')
          .insert({
            'couple_id': debt['couple_id'] as String,
            'user_id': debt['user_id'] as String,
            'wallet_id': walletId,
            'income_source_id': incomeSourceId,
            'amount': amount,
            'description': note?.trim().isNotEmpty == true
                ? note!.trim()
                : 'Thu hoi cho muon: ${debt['name'] as String}',
            'is_from_transfer': false,
            'date': date.toIso8601String().substring(0, 10),
          })
          .select('id')
          .single();

      await _db
          .from('debt_payments')
          .update({'linked_income_id': incomeRow['id'] as String})
          .eq('id', paymentId);
    }

    await _recalculateDebtRemaining(debtId);

    final updated = await _db
        .from('debt_payments')
        .select()
        .eq('id', paymentId)
        .single();
    return DebtPaymentModel.fromJson(updated);
  }

  Future<void> updatePayment({
    required String paymentId,
    required String debtId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final existingPayment = await _db
        .from('debt_payments')
        .select('linked_income_id, wallet_id')
        .eq('id', paymentId)
        .single();
    final linkedIncomeId = existingPayment['linked_income_id'] as String?;

    final debt = await _db
        .from('debts')
        .select('id, couple_id, user_id, debt_kind, name')
        .eq('id', debtId)
        .single();
    final debtKind = (debt['debt_kind'] as String?) ?? 'debt';

    await _db
        .from('debt_payments')
        .update({
          'amount': amount,
          'date': date.toIso8601String().substring(0, 10),
          'note': note,
        })
        .eq('id', paymentId);

    if (debtKind == 'lend') {
      final incomeSourceId = await _ensureIncomeSource(
        debt['couple_id'] as String,
        _debtRepaymentIncomeSource,
        icon: 'account_balance_wallet',
      );
      final description = note?.trim().isNotEmpty == true
          ? note!.trim()
          : 'Thu hoi cho muon: ${debt['name'] as String}';
      if (linkedIncomeId != null) {
        await _db
            .from('incomes')
            .update({
              'amount': amount,
              'description': description,
              'wallet_id': existingPayment['wallet_id'] as String,
              'date': date.toIso8601String().substring(0, 10),
            })
            .eq('id', linkedIncomeId)
            .eq('is_deleted', false);
      } else {
        final incomeRow = await _db
            .from('incomes')
            .insert({
              'couple_id': debt['couple_id'] as String,
              'user_id': debt['user_id'] as String,
              'wallet_id': existingPayment['wallet_id'] as String,
              'income_source_id': incomeSourceId,
              'amount': amount,
              'description': description,
              'is_from_transfer': false,
              'date': date.toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        await _db
            .from('debt_payments')
            .update({'linked_income_id': incomeRow['id'] as String})
            .eq('id', paymentId);
      }
    }

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deletePayment({
    required String paymentId,
    required String debtId,
  }) async {
    final existingPayment = await _db
        .from('debt_payments')
        .select('linked_income_id')
        .eq('id', paymentId)
        .single();

    final debt = await _db
        .from('debts')
        .select('debt_kind')
        .eq('id', debtId)
        .single();

    await _db
        .from('debt_payments')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', paymentId);

    if ((debt['debt_kind'] as String?) == 'lend' &&
        existingPayment['linked_income_id'] != null) {
      await _db
          .from('incomes')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existingPayment['linked_income_id'] as String)
          .eq('is_deleted', false);
    }

    await _recalculateDebtRemaining(debtId);
  }

  Future<String> _ensureIncomeSource(
    String coupleId,
    String name, {
    required String icon,
  }) async {
    try {
      final existing = await _db
          .from('income_sources')
          .select('id, show_in_income_form')
          .eq('couple_id', coupleId)
          .eq('name', name)
          .eq('is_deleted', false)
          .limit(1);

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as String;
        final showInIncomeForm =
            (existing.first['show_in_income_form'] as bool?) ?? true;
        if (showInIncomeForm) {
          await _db
              .from('income_sources')
              .update({'show_in_income_form': false})
              .eq('id', id);
        }
        return id;
      }

      final created = await _db
          .from('income_sources')
          .insert({
            'couple_id': coupleId,
            'name': name,
            'icon': icon,
            'type': 'other',
            'show_in_income_form': false,
          })
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      if (!_isMissingIncomeFormColumn(e)) rethrow;
      final existing = await _db
          .from('income_sources')
          .select('id')
          .eq('couple_id', coupleId)
          .eq('name', name)
          .eq('is_deleted', false)
          .limit(1);

      if (existing.isNotEmpty) {
        return existing.first['id'] as String;
      }

      final created = await _db
          .from('income_sources')
          .insert({
            'couple_id': coupleId,
            'name': name,
            'icon': icon,
            'type': 'other',
          })
          .select('id')
          .single();
      return created['id'] as String;
    }
  }

  Future<String> _ensureExpenseCategory(
    String coupleId,
    String name, {
    required String icon,
    required String color,
  }) async {
    try {
      final existing = await _db
          .from('categories')
          .select('id, show_in_quick_add, show_in_expense_form')
          .eq('couple_id', coupleId)
          .eq('name', name)
          .eq('is_deleted', false)
          .limit(1);

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as String;
        final showInQuickAdd =
            (existing.first['show_in_quick_add'] as bool?) ?? true;
        final showInExpenseForm =
            (existing.first['show_in_expense_form'] as bool?) ?? true;
        if (showInQuickAdd) {
          await _db
              .from('categories')
              .update({'show_in_quick_add': false})
              .eq('id', id);
        }
        if (showInExpenseForm) {
          await _db
              .from('categories')
              .update({'show_in_expense_form': false})
              .eq('id', id);
        }
        return id;
      }

      final created = await _db
          .from('categories')
          .insert({
            'couple_id': coupleId,
            'name': name,
            'icon': icon,
            'color': color,
            'sort_order': 0,
            'show_in_quick_add': false,
            'show_in_expense_form': false,
          })
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      if (!_isMissingQuickAddColumn(e) && !_isMissingExpenseFormColumn(e)) {
        rethrow;
      }
      final existing = await _db
          .from('categories')
          .select('id')
          .eq('couple_id', coupleId)
          .eq('name', name)
          .eq('is_deleted', false)
          .limit(1);

      if (existing.isNotEmpty) {
        return existing.first['id'] as String;
      }

      final created = await _db
          .from('categories')
          .insert({
            'couple_id': coupleId,
            'name': name,
            'icon': icon,
            'color': color,
            'sort_order': 0,
          })
          .select('id')
          .single();
      return created['id'] as String;
    }
  }

  Future<String?> _resolveDefaultWalletId(String coupleId) async {
    final rows = await _db
        .from('wallets')
        .select('id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  Future<void> _recalculateDebtRemaining(String debtId) async {
    final debtRow = await _db
        .from('debts')
        .select('original_amount')
        .eq('id', debtId)
        .single();
    final original = (debtRow['original_amount'] as num?)?.toDouble() ?? 0;

    final payments = await _db
        .from('debt_payments')
        .select('amount')
        .eq('debt_id', debtId)
        .eq('is_deleted', false);
    final paidTotal = payments.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );

    final nextRemaining = (original - paidTotal).clamp(0, original);
    await _db
        .from('debts')
        .update({
          'remaining_amount': nextRemaining,
          'is_closed': nextRemaining <= 0,
        })
        .eq('id', debtId);
  }
}

