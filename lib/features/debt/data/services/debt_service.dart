import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_payment_model.dart';

class DebtService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<DebtModel>> getDebts(String coupleId) async {
    final rows = await _db
        .from('debts')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('due_date');
    return rows.map((r) => DebtModel.fromJson(r)).toList();
  }

  Future<DebtModel> createDebt({
    required String coupleId,
    required String userId,
    required String debtTypeId,
    required String name,
    required double originalAmount,
    required String creditorName,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
    int? reminderDaysBefore,
  }) async {
    final row = await _db
        .from('debts')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'debt_type_id': debtTypeId,
          'name': name,
          'original_amount': originalAmount,
          'remaining_amount': originalAmount,
          'creditor_name': creditorName,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'due_date': dueDate?.toIso8601String().substring(0, 10),
          'note': note,
          'reminder_days_before': reminderDaysBefore,
          'is_closed': false,
        })
        .select()
        .single();
    return DebtModel.fromJson(row);
  }

  Future<DebtModel> getDebtById(String debtId) async {
    final row = await _db.from('debts').select().eq('id', debtId).single();
    return DebtModel.fromJson(row);
  }

  Future<void> updateDebt({
    required String debtId,
    required String debtTypeId,
    required String name,
    required double originalAmount,
    required String creditorName,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
  }) async {
    await _db
        .from('debts')
        .update({
          'debt_type_id': debtTypeId,
          'name': name,
          'original_amount': originalAmount,
          'creditor_name': creditorName,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'due_date': dueDate?.toIso8601String().substring(0, 10),
          'note': note,
        })
        .eq('id', debtId);
    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deleteDebt(String debtId) async {
    await _db
        .from('debts')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', debtId);
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

  Future<DebtPaymentModel> createPayment({
    required String coupleId,
    required String debtId,
    required String walletId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
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

      await _recalculateDebtRemaining(debtId);

    return DebtPaymentModel.fromJson(row);
  }

  Future<void> updatePayment({
    required String paymentId,
    required String debtId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _db
        .from('debt_payments')
        .update({
          'amount': amount,
          'date': date.toIso8601String().substring(0, 10),
          'note': note,
        })
        .eq('id', paymentId);

    await _recalculateDebtRemaining(debtId);
  }

  Future<void> deletePayment({
    required String paymentId,
    required String debtId,
  }) async {
    await _db
        .from('debt_payments')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', paymentId);

    await _recalculateDebtRemaining(debtId);
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
    await _db.from('debts').update({
      'remaining_amount': nextRemaining,
      'is_closed': nextRemaining <= 0,
    }).eq('id', debtId);
  }
}
