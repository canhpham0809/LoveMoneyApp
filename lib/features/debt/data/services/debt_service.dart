import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_payment_model.dart';

class DebtService {
  SupabaseClient get _db => Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  static const String _debtInitIncomeSource = 'Nhận tiền nợ';
  static const String _debtRepaymentIncomeSource = 'Thu hồi cho mượn';
  static const String _debtLendExpenseCategory = 'Cho mượn nợ';
  static const String _debtPaymentExpenseCategory = 'Trả nợ gốc & lãi';

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

  bool _isMissingDebtKindColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('debt_kind');
  }

  Future<List<DebtModel>> getDebts(
    String coupleId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final ordered = _db
          .from('debts')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order')
          .order('created_at');
      final rows = (limit != null && offset != null)
          ? await ordered.range(offset, offset + limit - 1)
          : await ordered;
      return rows.map((row) => DebtModel.fromJson(row)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final ordered = _db
          .from('debts')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('created_at');
      final rows = (limit != null && offset != null)
          ? await ordered.range(offset, offset + limit - 1)
          : await ordered;
      return rows.map((row) => DebtModel.fromJson(row)).toList();
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
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
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
      'is_deleted': false,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
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

    final insertedDebtId = row['id'] as String;
    String? createdIncomeId;
    String? createdExpenseId;

    try {
      final defaultWalletId = await _resolveDefaultWalletId(coupleId);

      if (debtKind == 'debt' && recordToIncome) {
        if (defaultWalletId == null) {
          throw Exception('Chưa có ví mặc định để ghi nhận thu nhập từ nợ.');
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
              'description': _resolveDebtDescription(name, note, 'Nhận nợ'),
              'is_from_transfer': false,
              'date': startDate.toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        createdIncomeId = incomeRow['id'] as String;
      }

      if (debtKind == 'lend' && recordToExpense) {
        if (defaultWalletId == null) {
          throw Exception('Chưa có ví mặc định để ghi nhận cho mượn.');
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
              'description': _resolveDebtDescription(name, note, 'Cho mượn'),
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
            .eq('id', insertedDebtId);
      }

      final updated = await _db
          .from('debts')
          .select()
          .eq('id', insertedDebtId)
          .single();
      return DebtModel.fromJson(updated);
    } catch (_) {
      if (createdIncomeId != null) {
        await _db.from('incomes').delete().eq('id', createdIncomeId);
      }
      if (createdExpenseId != null) {
        await _db.from('expenses').delete().eq('id', createdExpenseId);
      }
      await _db.from('debts').delete().eq('id', insertedDebtId);
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
        .select('couple_id, user_id, linked_income_id, linked_expense_id, note, original_amount')
        .eq('id', debtId)
        .single();
    var linkedIncomeId = existingDebt['linked_income_id'] as String?;
    var linkedExpenseId = existingDebt['linked_expense_id'] as String?;
    final existingNoteStr = existingDebt['note'] as String?;
    String? nextNoteStr = note;
    if (note != null && note.trim().startsWith('{')) {
      nextNoteStr = note;
    } else if (existingNoteStr != null && existingNoteStr.trim().startsWith('{')) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(existingNoteStr));
        if (data['is_bank_loan'] == true) {
          final oldOriginal = (existingDebt['original_amount'] as num?)?.toDouble() ?? originalAmount;
          if (oldOriginal != originalAmount) {
            final bankLoan = BankLoanInfo.fromJson(data);
            final regeneratedSchedule = recalculateSchedule(
              originalAmount: originalAmount,
              totalMonths: bankLoan.totalMonths,
              startDate: startDate,
              repaymentDay: bankLoan.repaymentDay,
              interestRules: bankLoan.interestRules,
              existingSchedule: bankLoan.schedule,
            );
            final updatedBankLoan = BankLoanInfo(
              totalMonths: bankLoan.totalMonths,
              repaymentDay: bankLoan.repaymentDay,
              interestRules: bankLoan.interestRules,
              schedule: regeneratedSchedule,
            );
            nextNoteStr = jsonEncode(updatedBankLoan.toJson());
          }
        } else {
          data['user_note'] = note;
          nextNoteStr = jsonEncode(data);
        }
      } catch (_) {}
    }

    // Compute the sum of all increments to prevent double-counting in ledger
    double incrementsTotal = 0;
    if (existingNoteStr != null && existingNoteStr.trim().startsWith('{')) {
      try {
        final data = jsonDecode(existingNoteStr);
        if (data['increments'] is List) {
          for (final inc in data['increments']) {
            incrementsTotal += ((inc['amount'] as num?)?.toDouble() ?? 0);
          }
        }
      } catch (_) {}
    }
    final baseAmount = (originalAmount - incrementsTotal).clamp(0.0, double.infinity);

    final dateIso = startDate.toIso8601String().substring(0, 10);
    final incomeDescription = _resolveDebtDescription(name, note, 'Nhận nợ');
    final expenseDescription = _resolveDebtDescription(name, note, 'Cho mượn');

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
          'note': nextNoteStr,
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
                'amount': baseAmount,
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
              'user_id': _db.auth.currentUser!.id,
              'wallet_id': defaultWalletId,
              'income_source_id': incomeSourceId,
              'amount': baseAmount,
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
                'amount': baseAmount,
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
              'user_id': _db.auth.currentUser!.id,
              'wallet_id': defaultWalletId,
              'category_id': categoryId,
              'amount': baseAmount,
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

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final debt = await _db
        .from('debts')
        .select('couple_id, user_id, name, linked_income_id, linked_expense_id, note')
        .eq('id', debtId)
        .single();

    final note = debt['note'] as String?;
    final extraIncomeIds = <String>[];
    final extraExpenseIds = <String>[];
    if (note != null && note.trim().startsWith('{')) {
      try {
        final data = jsonDecode(note);
        if (data['increments'] is List) {
          for (final inc in data['increments']) {
            if (inc['linked_income_id'] is String) {
              extraIncomeIds.add(inc['linked_income_id'] as String);
            }
            if (inc['linked_expense_id'] is String) {
              extraExpenseIds.add(inc['linked_expense_id'] as String);
            }
          }
        }
        if (data['is_bank_loan'] == true && data['schedule'] is List) {
          for (final item in data['schedule']) {
            if (item['expense_id'] is String) {
              extraExpenseIds.add(item['expense_id'] as String);
            }
          }
        }
      } catch (_) {}
    }

    // Cả hai partner đều có quyền xóa nợ


    final paymentRows = List<Map<String, dynamic>>.from(
      await _db
          .from('debt_payments')
          .select('id, linked_income_id')
          .eq('debt_id', debtId)
          .eq('is_deleted', false),
    );

    final incomeIdsToDelete = <String>{
      if (debt['linked_income_id'] is String)
        debt['linked_income_id'] as String,
      ...paymentRows
          .map((row) => row['linked_income_id'] as String?)
          .whereType<String>(),
      ...extraIncomeIds,
    };

    if (incomeIdsToDelete.isNotEmpty) {
      await _db
          .from('incomes')
          .update({'is_deleted': true, 'deleted_at': nowIso})
          .inFilter('id', incomeIdsToDelete.toList())
          .eq('is_deleted', false);
    }

    final expenseIdsToDelete = <String>{
      if (debt['linked_expense_id'] is String)
        debt['linked_expense_id'] as String,
      ...extraExpenseIds,
    };

    if (expenseIdsToDelete.isNotEmpty) {
      for (final expId in expenseIdsToDelete) {
        await _db
            .from('expenses')
            .update({'is_deleted': true, 'deleted_at': nowIso})
            .eq('id', expId)
            .eq('is_deleted', false);
      }
    }

    await _db
        .from('debt_payments')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('debt_id', debtId)
        .eq('is_deleted', false);

    await _db
        .from('debts')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('id', debtId);
  }

  Future<double> previewDeleteDebtImpact(String debtId) async {
    final debt = await _db
        .from('debts')
        .select('linked_income_id, linked_expense_id, note')
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

    final note = debtRow['note'] as String?;
    double extraIncomeTotal = 0;
    double extraExpenseTotal = 0;
    if (note != null && note.trim().startsWith('{')) {
      try {
        final data = jsonDecode(note);
        if (data['increments'] is List) {
          final incIncomeIds = <String>[];
          final incExpenseIds = <String>[];
          for (final inc in data['increments']) {
            if (inc['linked_income_id'] is String) {
              incIncomeIds.add(inc['linked_income_id'] as String);
            }
            if (inc['linked_expense_id'] is String) {
              incExpenseIds.add(inc['linked_expense_id'] as String);
            }
          }
          if (incIncomeIds.isNotEmpty) {
            extraIncomeTotal = await _getActiveIncomeTotalByIds(incIncomeIds);
          }
          if (incExpenseIds.isNotEmpty) {
            extraExpenseTotal = await _getActiveExpenseTotalByIds(incExpenseIds);
          }
        }
      } catch (_) {}
    }

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

    return linkedExpenseAmount +
        extraExpenseTotal +
        paymentExpenseTotal -
        (linkedIncomeAmount + extraIncomeTotal + paymentIncomeTotal);
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
    return rows.map((row) => DebtPaymentModel.fromJson(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getDebtTypes(String coupleId) async {
    try {
      final rows = await _db
          .from('debt_types')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order')
          .order('name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final rows = await _db
          .from('debt_types')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  Future<int> _nextDebtTypeSortOrder(String coupleId) async {
    try {
      final rows = await _db
          .from('debt_types')
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

  Future<Map<String, dynamic>> createDebtType({
    required String coupleId,
    required String name,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'name': name,
      'sort_order': await _nextDebtTypeSortOrder(coupleId),
    };
    late final Map<String, dynamic> row;
    try {
      row = await _db.from('debt_types').insert(payload).select().single();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      payload.remove('sort_order');
      row = await _db.from('debt_types').insert(payload).select().single();
    }
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

  Future<void> updateDebtTypeOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    for (var i = 0; i < orderedIds.length; i++) {
      try {
        await _db
            .from('debt_types')
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

  Future<DebtPaymentModel> createPayment({
    required String coupleId,
    required String debtId,
    required String walletId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final paymentId = _uuid.v4();

    final debt = await _db
        .from('debts')
        .select('id, couple_id, user_id, debt_kind, name')
        .eq('id', debtId)
        .single();
    final debtKind = (debt['debt_kind'] as String?) ?? 'debt';

    final row = await _db
        .from('debt_payments')
        .insert({
          'id': paymentId,
          'couple_id': coupleId,
          'debt_id': debtId,
          'wallet_id': walletId,
          'amount': amount,
          'date': date.toIso8601String().substring(0, 10),
          'note': note,
        })
        .select()
        .single();

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
            'user_id': _db.auth.currentUser!.id,
            'wallet_id': walletId,
            'income_source_id': incomeSourceId,
            'amount': amount,
            'description': note?.trim().isNotEmpty == true
                ? note!.trim()
                : 'Thu hồi nợ: ${debt['name'] as String}',
            'is_from_transfer': false,
            'date': date.toIso8601String().substring(0, 10),
          })
          .select('id')
          .single();

      await _db
          .from('debt_payments')
          .update({'linked_income_id': incomeRow['id'] as String})
          .eq('id', row['id'] as String);
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
          : 'Thu hồi nợ: ${debt['name'] as String}';
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
              'user_id': _db.auth.currentUser!.id,
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
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existingPayment = await _db
        .from('debt_payments')
        .select('linked_income_id')
        .eq('id', paymentId)
        .single();

    String? debtKind;
    try {
      final debtRow = await _db
          .from('debts')
          .select('debt_kind')
          .eq('id', debtId)
          .single();
      debtKind = debtRow['debt_kind'] as String?;
    } catch (e) {
      if (!_isMissingDebtKindColumn(e)) rethrow;
      debtKind = 'debt';
    }

    await _db
        .from('debt_payments')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('id', paymentId);

    if (debtKind == 'lend' && existingPayment['linked_income_id'] != null) {
      await _db
          .from('incomes')
          .update({'is_deleted': true, 'deleted_at': nowIso})
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

  Future<void> updateSplitBillNote({
    required String debtId,
    required String note,
  }) async {
    await _db
        .from('debts')
        .update({
          'note': note,
        })
        .eq('id', debtId);
    await _recalculateDebtRemaining(debtId);
  }

  String _resolveDebtDescription(String name, String? note, String defaultPrefix) {
    if (note != null && note.trim().startsWith('{')) {
      try {
        final data = jsonDecode(note);
        if (data['is_split'] == true) {
          final userNote = data['user_note'] as String?;
          if (userNote != null && userNote.trim().isNotEmpty) {
            return userNote.trim();
          }
          return '$defaultPrefix: $name';
        }
      } catch (_) {}
    }
    return note?.trim().isNotEmpty == true ? note!.trim() : '$defaultPrefix: $name';
  }

  Future<void> increaseDebt({
    required String debtId,
    required double incrementAmount,
    required DateTime date,
    required bool recordTransaction,
    String? note,
  }) async {
    final debt = await _db
        .from('debts')
        .select()
        .eq('id', debtId)
        .single();

    final currentOriginal = (debt['original_amount'] as num).toDouble();
    final newOriginal = currentOriginal + incrementAmount;

    String? linkedIncomeId;
    String? linkedExpenseId;
    final coupleId = debt['couple_id'] as String;
    final userId = _db.auth.currentUser!.id;
    final debtKind = debt['debt_kind'] as String? ?? 'debt';
    final name = debt['name'] as String;

    final defaultWalletId = await _resolveDefaultWalletId(coupleId);
    if (recordTransaction) {
      if (defaultWalletId == null) {
        throw Exception('Chưa có ví mặc định để ghi nhận giao dịch.');
      }
      final dateIso = date.toIso8601String().substring(0, 10);
      if (debtKind == 'debt') {
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
              'amount': incrementAmount,
              'description': note?.trim().isNotEmpty == true
                  ? note!.trim()
                  : 'Nợ thêm: $name',
              'is_from_transfer': false,
              'date': dateIso,
            })
            .select('id')
            .single();
        linkedIncomeId = incomeRow['id'] as String;
      } else {
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
              'amount': incrementAmount,
              'description': note?.trim().isNotEmpty == true
                  ? note!.trim()
                  : 'Cho mượn thêm: $name',
              'date': dateIso,
            })
            .select('id')
            .single();
        linkedExpenseId = expenseRow['id'] as String;
      }
    }

    final existingNote = debt['note'] as String?;
    Map<String, dynamic> noteData = {};
    if (existingNote != null && existingNote.trim().startsWith('{')) {
      try {
        noteData = jsonDecode(existingNote);
      } catch (_) {
        noteData = {'user_note': existingNote};
      }
    } else {
      noteData = {'user_note': existingNote};
    }

    final incrementsList = List<dynamic>.from(noteData['increments'] ?? []);
    incrementsList.add({
      'amount': incrementAmount,
      'date': date.toIso8601String().substring(0, 10),
      'note': note?.trim(),
      'linked_income_id': linkedIncomeId,
      'linked_expense_id': linkedExpenseId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    noteData['increments'] = incrementsList;

    await _db
        .from('debts')
        .update({
          'original_amount': newOriginal,
          'note': jsonEncode(noteData),
        })
        .eq('id', debtId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deleteIncrement(String debtId, int index) async {
    final debt = await _db
        .from('debts')
        .select('original_amount, note')
        .eq('id', debtId)
        .single();

    final note = debt['note'] as String?;
    if (note == null || !note.trim().startsWith('{')) return;

    final data = Map<String, dynamic>.from(jsonDecode(note));
    if (data['increments'] is! List) return;

    final incrementsList = List<Map<String, dynamic>>.from(
        (data['increments'] as List).map((e) => Map<String, dynamic>.from(e)));
    if (index < 0 || index >= incrementsList.length) return;

    final removed = incrementsList.removeAt(index);
    data['increments'] = incrementsList;

    final currentOriginal = (debt['original_amount'] as num).toDouble();
    final newOriginal = (currentOriginal - (removed['amount'] as num).toDouble())
        .clamp(0.0, currentOriginal);

    final linkedIncomeId = removed['linked_income_id'] as String?;
    final linkedExpenseId = removed['linked_expense_id'] as String?;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await _db
        .from('debts')
        .update({
          'original_amount': newOriginal,
          'note': jsonEncode(data),
        })
        .eq('id', debtId);

    if (linkedIncomeId != null) {
      await _db
          .from('incomes')
          .update({'is_deleted': true, 'deleted_at': nowIso})
          .eq('id', linkedIncomeId)
          .eq('is_deleted', false);
    }
    if (linkedExpenseId != null) {
      await _db
          .from('expenses')
          .update({'is_deleted': true, 'deleted_at': nowIso})
          .eq('id', linkedExpenseId)
          .eq('is_deleted', false);
    }

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> updateIncrement({
    required String debtId,
    required int index,
    required double newAmount,
    required DateTime date,
    required String? note,
    required bool recordTransaction,
  }) async {
    final debt = await _db
        .from('debts')
        .select('name, original_amount, note, couple_id, user_id, debt_kind')
        .eq('id', debtId)
        .single();

    final existingNote = debt['note'] as String?;
    if (existingNote == null || !existingNote.trim().startsWith('{')) return;

    final data = Map<String, dynamic>.from(jsonDecode(existingNote));
    if (data['increments'] is! List) return;

    final incrementsList = List<Map<String, dynamic>>.from(
        (data['increments'] as List).map((e) => Map<String, dynamic>.from(e)));
    if (index < 0 || index >= incrementsList.length) return;

    final oldIncrement = incrementsList[index];
    final oldAmount = (oldIncrement['amount'] as num).toDouble();
    var linkedIncomeId = oldIncrement['linked_income_id'] as String?;
    var linkedExpenseId = oldIncrement['linked_expense_id'] as String?;
    final dateIso = date.toIso8601String().substring(0, 10);
    final isLend = debt['debt_kind'] == 'lend';
    final name = debt['name'] as String? ?? '';
    final coupleId = debt['couple_id'] as String;
    final userId = debt['user_id'] as String;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final wasRecorded = isLend ? linkedExpenseId != null : linkedIncomeId != null;

    if (recordTransaction) {
      if (wasRecorded) {
        if (linkedIncomeId != null) {
          final description = note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Nợ thêm: $name';
          await _db
              .from('incomes')
              .update({
                'amount': newAmount,
                'date': dateIso,
                'description': description,
              })
              .eq('id', linkedIncomeId)
              .eq('is_deleted', false);
        }
        if (linkedExpenseId != null) {
          final description = note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Cho mượn thêm: $name';
          await _db
              .from('expenses')
              .update({
                'amount': newAmount,
                'date': dateIso,
                'description': description,
              })
              .eq('id', linkedExpenseId)
              .eq('is_deleted', false);
        }
      } else {
        final defaultWalletId = await _resolveDefaultWalletId(coupleId);
        if (defaultWalletId == null) {
          throw Exception('Chưa có ví mặc định để ghi nhận giao dịch.');
        }
        if (!isLend) {
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
                'amount': newAmount,
                'description': note?.trim().isNotEmpty == true
                    ? note!.trim()
                    : 'Nợ thêm: $name',
                'is_from_transfer': false,
                'date': dateIso,
              })
              .select('id')
              .single();
          linkedIncomeId = incomeRow['id'] as String;
        } else {
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
                'amount': newAmount,
                'description': note?.trim().isNotEmpty == true
                    ? note!.trim()
                    : 'Cho mượn thêm: $name',
                'date': dateIso,
              })
              .select('id')
              .single();
          linkedExpenseId = expenseRow['id'] as String;
        }
      }
    } else {
      if (wasRecorded) {
        if (linkedIncomeId != null) {
          await _db
              .from('incomes')
              .update({'is_deleted': true, 'deleted_at': nowIso})
              .eq('id', linkedIncomeId)
              .eq('is_deleted', false);
          linkedIncomeId = null;
        }
        if (linkedExpenseId != null) {
          await _db
              .from('expenses')
              .update({'is_deleted': true, 'deleted_at': nowIso})
              .eq('id', linkedExpenseId)
              .eq('is_deleted', false);
          linkedExpenseId = null;
        }
      }
    }

    // Update the values in the JSON structure
    oldIncrement['amount'] = newAmount;
    oldIncrement['date'] = dateIso;
    oldIncrement['note'] = note?.trim();
    oldIncrement['linked_income_id'] = linkedIncomeId;
    oldIncrement['linked_expense_id'] = linkedExpenseId;
    oldIncrement['created_at'] ??= DateTime.now().toUtc().toIso8601String();

    // Calculate new total original amount
    final currentOriginal = (debt['original_amount'] as num).toDouble();
    final newOriginal = (currentOriginal - oldAmount + newAmount).clamp(0.0, double.infinity);

    // Update the database record
    await _db
        .from('debts')
        .update({
          'original_amount': newOriginal,
          'note': jsonEncode(data),
        })
        .eq('id', debtId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<double> previewDeleteIncrementImpact({
    String? linkedIncomeId,
    String? linkedExpenseId,
  }) async {
    if (linkedIncomeId != null) {
      final amount = await _getActiveIncomeAmount(linkedIncomeId);
      return -amount;
    }
    if (linkedExpenseId != null) {
      final amount = await _getActiveExpenseAmount(linkedExpenseId);
      return amount;
    }
    return 0;
  }

  Future<double> _getActiveExpenseTotalByIds(List<String> expenseIds) async {
    if (expenseIds.isEmpty) return 0;
    final rows = await _db
        .from('expenses')
        .select('amount')
        .inFilter('id', expenseIds)
        .eq('is_deleted', false);
    return rows.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<void> _recalculateDebtRemaining(String debtId) async {
    final debtRow = await _db
        .from('debts')
        .select('original_amount, note')
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

    // Also account for pre-paid periods in bank loan schedule (isPaid=true but no paymentId)
    double prePaidPrincipal = 0.0;
    final noteStr = debtRow['note'] as String?;
    if (noteStr != null && noteStr.trim().startsWith('{')) {
      try {
        final data = jsonDecode(noteStr);
        if (data['is_bank_loan'] == true && data['schedule'] is List) {
          for (final item in data['schedule'] as List) {
            final isPaid = item['is_paid'] as bool? ?? false;
            final paymentId = item['payment_id'] as String?;
            if (isPaid && paymentId == null) {
              // Pre-paid period without a real debt_payment record
              prePaidPrincipal += ((item['principal'] as num?)?.toDouble() ?? 0);
              prePaidPrincipal += ((item['early_principal'] as num?)?.toDouble() ?? 0);
            }
          }
        }
      } catch (_) {}
    }

    final nextRemaining = (original - paidTotal - prePaidPrincipal).clamp(0, original);
    await _db
        .from('debts')
        .update({
          'remaining_amount': nextRemaining,
          'is_closed': nextRemaining <= 0,
        })
        .eq('id', debtId);
  }

  static double getInterestRateForMonth(int month, List<InterestRateRule> rules) {
    for (final rule in rules) {
      if (month >= rule.fromMonth && month <= rule.toMonth) {
        return rule.rate;
      }
    }
    if (rules.isNotEmpty) {
      final sortedRules = List<InterestRateRule>.from(rules);
      sortedRules.sort((a, b) => b.toMonth.compareTo(a.toMonth));
      return sortedRules.first.rate;
    }
    return 10.0;
  }

  static List<RepaymentScheduleItem> generateInitialSchedule({
    required double originalAmount,
    required int totalMonths,
    required DateTime startDate,
    required int repaymentDay,
    required List<InterestRateRule> interestRules,
  }) {
    final schedule = <RepaymentScheduleItem>[];
    double remainingPrincipal = originalAmount;
    final standardPrincipal = ((originalAmount / totalMonths) / 1000.0).ceil() * 1000.0;

    for (var i = 1; i <= totalMonths; i++) {
      final dueDate = DateTime(startDate.year, startDate.month + i, repaymentDay);
      final prevDueDate = (i == 1)
          ? startDate
          : DateTime(startDate.year, startDate.month + i - 1, repaymentDay);
      final days = dueDate.difference(prevDueDate).inDays;
      final rate = getInterestRateForMonth(i, interestRules);
      final interest = remainingPrincipal * (rate / 100.0 / 365.0) * days;

      double principal;
      if (i == totalMonths) {
        principal = remainingPrincipal;
      } else {
        principal = standardPrincipal < remainingPrincipal ? standardPrincipal : (remainingPrincipal > 0 ? remainingPrincipal : 0.0);
      }

      schedule.add(RepaymentScheduleItem(
        monthIndex: i,
        dueDate: dueDate,
        principal: principal,
        interest: interest,
        rate: rate,
      ));

      remainingPrincipal -= principal;
    }
    return schedule;
  }

  static List<RepaymentScheduleItem> recalculateSchedule({
    required double originalAmount,
    required int totalMonths,
    required DateTime startDate,
    required int repaymentDay,
    required List<InterestRateRule> interestRules,
    required List<RepaymentScheduleItem> existingSchedule,
  }) {
    final paidItems = existingSchedule.where((e) => e.isPaid).toList();
    paidItems.sort((a, b) => a.monthIndex.compareTo(b.monthIndex));

    final lastPaidIndex = paidItems.isEmpty ? 0 : paidItems.last.monthIndex;

    double remainingPrincipal = originalAmount;
    for (final item in paidItems) {
      remainingPrincipal -= (item.principal + item.earlyPrincipal);
    }
    remainingPrincipal = remainingPrincipal.clamp(0.0, double.infinity);

    final remainingMonths = totalMonths - lastPaidIndex;
    final newStandardPrincipal = remainingMonths > 0
        ? ((remainingPrincipal / remainingMonths) / 1000.0).ceil() * 1000.0
        : 0.0;

    final newSchedule = <RepaymentScheduleItem>[];
    newSchedule.addAll(paidItems);

    double runningPrincipal = remainingPrincipal;
    for (var i = lastPaidIndex + 1; i <= totalMonths; i++) {
      final dueDate = DateTime(startDate.year, startDate.month + i, repaymentDay);
      final prevDueDate = (i == 1)
          ? startDate
          : DateTime(startDate.year, startDate.month + i - 1, repaymentDay);
      final days = dueDate.difference(prevDueDate).inDays;
      final rate = getInterestRateForMonth(i, interestRules);
      final interest = runningPrincipal * (rate / 100.0 / 365.0) * days;

      double principal;
      if (i == totalMonths) {
        principal = runningPrincipal;
      } else {
        principal = newStandardPrincipal < runningPrincipal ? newStandardPrincipal : (runningPrincipal > 0 ? runningPrincipal : 0.0);
      }

      newSchedule.add(RepaymentScheduleItem(
        monthIndex: i,
        dueDate: dueDate,
        principal: principal,
        interest: interest,
        rate: rate,
      ));

      runningPrincipal -= principal;
    }

    newSchedule.sort((a, b) => a.monthIndex.compareTo(b.monthIndex));
    return newSchedule;
  }

  Future<void> payBankLoanMonth({
    required String coupleId,
    required String debtId,
    required int monthIndex,
    required String walletId,
    required DateTime paymentDate,
    required bool recordExpense,
    required double extraPrincipal,
    required double penaltyFee,
    String? note,
  }) async {
    final debt = await getDebtById(debtId);
    final bankLoan = debt.bankLoanInfo;
    if (bankLoan == null) {
      throw Exception('Khoản nợ không phải là vay trả góp ngân hàng.');
    }

    final schedule = List<RepaymentScheduleItem>.from(bankLoan.schedule);
    final idx = schedule.indexWhere((e) => e.monthIndex == monthIndex);
    if (idx < 0) {
      throw Exception('Không tìm thấy kỳ hạn thanh toán thứ $monthIndex.');
    }

    final item = schedule[idx];
    if (item.isPaid) {
      throw Exception('Kỳ hạn thanh toán thứ $monthIndex đã được trả.');
    }

    final principalPaid = item.principal + extraPrincipal;
    final paymentId = _uuid.v4();
    final dateStr = paymentDate.toIso8601String().substring(0, 10);

    await _db.from('debt_payments').insert({
      'id': paymentId,
      'couple_id': coupleId,
      'debt_id': debtId,
      'wallet_id': walletId,
      'amount': principalPaid,
      'date': dateStr,
      'note': note ?? 'Thanh toán kỳ $monthIndex (Gốc: ${formatVnd(principalPaid)})',
    });

    String? expenseId;
    if (recordExpense) {
      final categoryId = await _ensureExpenseCategory(
        coupleId,
        _debtPaymentExpenseCategory,
        icon: 'payments',
        color: '#EF4444',
      );

      final totalExpense = item.principal + item.interest + extraPrincipal + penaltyFee;
      final extraDesc = extraPrincipal > 0 ? ' (Gốc trả thêm: ${formatVnd(extraPrincipal)})' : '';
      final penaltyDesc = penaltyFee > 0 ? ' (Phí phạt: ${formatVnd(penaltyFee)})' : '';
      final expenseDesc = 'Trả gốc & lãi kỳ $monthIndex: ${debt.name}$extraDesc$penaltyDesc';

      final expenseRow = await _db.from('expenses').insert({
        'couple_id': coupleId,
        'user_id': _db.auth.currentUser!.id,
        'wallet_id': walletId,
        'category_id': categoryId,
        'amount': totalExpense,
        'description': note?.trim().isNotEmpty == true ? note : expenseDesc,
        'date': dateStr,
      }).select('id').single();
      expenseId = expenseRow['id'] as String;
    }

    final updatedItem = item.copyWith(
      isPaid: true,
      paidAmount: item.principal + item.interest + extraPrincipal,
      paidDate: paymentDate,
      paymentId: paymentId,
      expenseId: expenseId,
      earlyPrincipal: extraPrincipal,
      penaltyFee: penaltyFee,
    );
    schedule[idx] = updatedItem;

    final regeneratedSchedule = recalculateSchedule(
      originalAmount: debt.originalAmount,
      totalMonths: bankLoan.totalMonths,
      startDate: debt.startDate,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: bankLoan.interestRules,
      existingSchedule: schedule,
    );

    final updatedBankLoan = BankLoanInfo(
      totalMonths: bankLoan.totalMonths,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: bankLoan.interestRules,
      schedule: regeneratedSchedule,
    );

    await _db.from('debts').update({
      'note': jsonEncode(updatedBankLoan.toJson()),
    }).eq('id', debtId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deleteBankLoanPayment({
    required String debtId,
    required int monthIndex,
  }) async {
    final debt = await getDebtById(debtId);
    final bankLoan = debt.bankLoanInfo;
    if (bankLoan == null) {
      throw Exception('Khoản nợ không phải là vay trả góp ngân hàng.');
    }

    final schedule = List<RepaymentScheduleItem>.from(bankLoan.schedule);
    final idx = schedule.indexWhere((e) => e.monthIndex == monthIndex);
    if (idx < 0) {
      throw Exception('Không tìm thấy kỳ hạn thanh toán thứ $monthIndex.');
    }

    final item = schedule[idx];
    if (!item.isPaid) {
      throw Exception('Kỳ hạn thanh toán thứ $monthIndex chưa được trả.');
    }

    final paymentId = item.paymentId;
    final expenseId = item.expenseId;

    if (paymentId != null) {
      await _db.from('debt_payments').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', paymentId);
    }

    if (expenseId != null) {
      await _db.from('expenses').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', expenseId);
    }

    final updatedItem = RepaymentScheduleItem(
      monthIndex: item.monthIndex,
      dueDate: item.dueDate,
      principal: item.principal,
      interest: item.interest,
      rate: item.rate,
      isPaid: false,
      paidAmount: 0.0,
      paidDate: null,
      paymentId: null,
      expenseId: null,
      earlyPrincipal: 0.0,
      penaltyFee: 0.0,
    );
    schedule[idx] = updatedItem;

    final regeneratedSchedule = recalculateSchedule(
      originalAmount: debt.originalAmount,
      totalMonths: bankLoan.totalMonths,
      startDate: debt.startDate,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: bankLoan.interestRules,
      existingSchedule: schedule,
    );

    final updatedBankLoan = BankLoanInfo(
      totalMonths: bankLoan.totalMonths,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: bankLoan.interestRules,
      schedule: regeneratedSchedule,
    );

    await _db.from('debts').update({
      'note': jsonEncode(updatedBankLoan.toJson()),
    }).eq('id', debtId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> updateBankLoanInterestRules({
    required String debtId,
    required List<InterestRateRule> newRules,
  }) async {
    final debt = await getDebtById(debtId);
    final bankLoan = debt.bankLoanInfo;
    if (bankLoan == null) {
      throw Exception('Khoản nợ không phải là vay trả góp ngân hàng.');
    }

    final regeneratedSchedule = recalculateSchedule(
      originalAmount: debt.originalAmount,
      totalMonths: bankLoan.totalMonths,
      startDate: debt.startDate,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: newRules,
      existingSchedule: bankLoan.schedule,
    );

    final updatedBankLoan = BankLoanInfo(
      totalMonths: bankLoan.totalMonths,
      repaymentDay: bankLoan.repaymentDay,
      interestRules: newRules,
      schedule: regeneratedSchedule,
    );

    await _db.from('debts').update({
      'note': jsonEncode(updatedBankLoan.toJson()),
    }).eq('id', debtId);
  }
}
