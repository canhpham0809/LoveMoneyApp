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
    return DebtPaymentModel.fromJson(row);
  }
}
