import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/income/data/models/income_model.dart';
import 'package:flutter_app_demo/features/income/data/models/income_source_model.dart';

class IncomeService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<IncomeModel>> getIncomes(String coupleId) async {
    final rows = await _db
        .from('incomes')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
      .order('created_at', ascending: false);
    return rows.map((r) => IncomeModel.fromJson(r)).toList();
  }

  Future<IncomeModel> createIncome({
    required String coupleId,
    required String userId,
    required String walletId,
    required String incomeSourceId,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    final row = await _db
        .from('incomes')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'wallet_id': walletId,
          'income_source_id': incomeSourceId,
          'amount': amount,
          'description': description,
          'is_from_transfer': false,
          'date': date.toIso8601String().substring(0, 10),
        })
        .select()
        .single();
    return IncomeModel.fromJson(row);
  }

  Future<void> deleteIncome(String incomeId) async {
    await _db
        .from('incomes')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', incomeId);
  }

  Future<void> updateIncome({
    required String incomeId,
    required String walletId,
    required String incomeSourceId,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    await _db
        .from('incomes')
        .update({
          'wallet_id': walletId,
          'income_source_id': incomeSourceId,
          'amount': amount,
          'description': description,
          'date': date.toIso8601String().substring(0, 10),
        })
        .eq('id', incomeId);
  }

        Future<void> restoreIncome(String incomeId) async {
          await _db
          .from('incomes')
          .update({'is_deleted': false, 'deleted_at': null})
          .eq('id', incomeId);
        }

  Future<List<IncomeSourceModel>> getIncomeSources(String coupleId) async {
    final rows = await _db
        .from('income_sources')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map((r) => IncomeSourceModel.fromJson(r)).toList();
  }

  Future<IncomeSourceModel> createIncomeSource({
    required String coupleId,
    required String name,
    String icon = '💵',
    String type = 'other',
  }) async {
    final row = await _db
        .from('income_sources')
        .insert({
          'couple_id': coupleId,
          'name': name,
          'icon': icon,
          'type': type,
        })
        .select()
        .single();
    return IncomeSourceModel.fromJson(row);
  }
}
