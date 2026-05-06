import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/income/data/models/income_model.dart';
import 'package:flutter_app_demo/features/income/data/models/income_source_model.dart';

class IncomeService {
  SupabaseClient get _db => Supabase.instance.client;

  bool _isMissingSortOrderColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('sort_order');
  }

  bool _isMissingIncomeFormColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('show_in_income_form');
  }

  Future<List<IncomeModel>> getIncomes(
    String coupleId, {
    String? createdByUserId,
    int? limit,
    int? offset,
  }) async {
    var query = _db
        .from('incomes')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .or('is_from_transfer.is.null,is_from_transfer.eq.false');

    if (createdByUserId != null) {
      query = query.eq('user_id', createdByUserId);
    }

    final ordered = query.order('created_at', ascending: false);
    final rows = (limit != null && offset != null)
        ? await ordered.range(offset, offset + limit - 1)
        : await ordered;
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
    try {
      final rows = await _db
          .from('income_sources')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order')
          .order('name');
      return rows.map((r) => IncomeSourceModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final rows = await _db
          .from('income_sources')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      return rows.map((r) => IncomeSourceModel.fromJson(r)).toList();
    }
  }

  Future<List<IncomeSourceModel>> getIncomeFormSources(String coupleId) async {
    try {
      final rows = await _db
          .from('income_sources')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .eq('show_in_income_form', true)
          .order('sort_order')
          .order('name');
      return rows.map((r) => IncomeSourceModel.fromJson(r)).toList();
    } catch (e) {
      if (_isMissingIncomeFormColumn(e) || _isMissingSortOrderColumn(e)) {
        final rows = await _db
            .from('income_sources')
            .select()
            .eq('couple_id', coupleId)
            .eq('is_deleted', false)
            .order('name');
        return rows.map((r) => IncomeSourceModel.fromJson(r)).toList();
      }
      rethrow;
    }
  }

  Future<int> _nextSortOrder(String coupleId) async {
    try {
      final rows = await _db
          .from('income_sources')
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

  Future<IncomeSourceModel> createIncomeSource({
    required String coupleId,
    required String name,
    String icon = '💵',
    String type = 'other',
    bool showInIncomeForm = true,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'name': name,
      'icon': icon,
      'type': type,
      'sort_order': await _nextSortOrder(coupleId),
      'show_in_income_form': showInIncomeForm,
    };

    try {
      final row = await _db
          .from('income_sources')
          .insert(payload)
          .select()
          .single();
      return IncomeSourceModel.fromJson(row);
    } catch (e) {
      if (!_isMissingIncomeFormColumn(e) && !_isMissingSortOrderColumn(e)) {
        rethrow;
      }
      payload.remove('sort_order');
      payload.remove('show_in_income_form');
      final row = await _db
          .from('income_sources')
          .insert(payload)
          .select()
          .single();
      return IncomeSourceModel.fromJson(row);
    }
  }

  Future<IncomeSourceModel> updateIncomeSource({
    required String sourceId,
    required String name,
    required String icon,
    required String type,
    required bool isActive,
    bool? showInIncomeForm,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'icon': icon,
      'type': type,
      'is_active': isActive,
    };
    if (showInIncomeForm != null) {
      payload['show_in_income_form'] = showInIncomeForm;
    }
    try {
      final row = await _db
          .from('income_sources')
          .update(payload)
          .eq('id', sourceId)
          .select()
          .single();
      return IncomeSourceModel.fromJson(row);
    } catch (e) {
      if (!_isMissingIncomeFormColumn(e)) rethrow;
      payload.remove('show_in_income_form');
      final row = await _db
          .from('income_sources')
          .update(payload)
          .eq('id', sourceId)
          .select()
          .single();
      return IncomeSourceModel.fromJson(row);
    }
  }

  Future<void> deleteIncomeSource(String sourceId) async {
    await _db
        .from('income_sources')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sourceId);
  }

  Future<void> updateIncomeSourceOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    for (var i = 0; i < orderedIds.length; i++) {
      try {
        await _db
            .from('income_sources')
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
}
