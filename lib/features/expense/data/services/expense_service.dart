import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';

class ExpenseService {
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

  Future<List<ExpenseModel>> getExpenses(
    String coupleId, {
    String? createdByUserId,
    int? limit,
    int? offset,
  }) async {
    var query = _db
        .from('expenses')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (createdByUserId != null) {
      query = query.eq('user_id', createdByUserId);
    }

    final ordered = query.order('created_at', ascending: false);
    final rows = (limit != null && offset != null)
        ? await ordered.range(offset, offset + limit - 1)
        : await ordered;
    return rows.map((r) => ExpenseModel.fromJson(r)).toList();
  }

  Future<ExpenseModel> createExpense({
    required String coupleId,
    required String userId,
    required String walletId,
    required String categoryId,
    required double amount,
    String? description,
    required DateTime date,
    String? eventId,
  }) async {
    final row = await _db
        .from('expenses')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'wallet_id': walletId,
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date.toIso8601String().substring(0, 10),
          'event_id': eventId,
        })
        .select()
        .single();
    return ExpenseModel.fromJson(row);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db
        .from('expenses')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', expenseId);
  }

  Future<void> updateExpense({
    required String expenseId,
    required String walletId,
    required String categoryId,
    required double amount,
    String? description,
    required DateTime date,
    String? eventId,
  }) async {
    await _db
        .from('expenses')
        .update({
          'wallet_id': walletId,
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date.toIso8601String().substring(0, 10),
          'event_id': eventId,
        })
        .eq('id', expenseId);

    // Sync to linked debt payment or bank loan schedule if this expense is linked
    try {
      final debts = await _db
          .from('debts')
          .select('id, note')
          .eq('is_deleted', false);
      for (final debt in debts) {
        final note = debt['note'] as String?;
        if (note != null && note.trim().startsWith('{')) {
          final data = jsonDecode(note);
          if (data['is_bank_loan'] == true && data['schedule'] is List) {
            bool updated = false;
            for (final item in data['schedule']) {
              final expId = item['expense_id'] as String? ?? item['expenseId'] as String?;
              if (expId == expenseId) {
                item['paid_amount'] = amount;
                item['paidAmount'] = amount;
                updated = true;

                final pid = item['payment_id'] as String? ?? item['paymentId'] as String?;
                if (pid != null && pid.isNotEmpty) {
                  await _db.from('debt_payments').update({
                    'amount': amount,
                    'wallet_id': walletId,
                    'date': date.toIso8601String().substring(0, 10),
                  }).eq('id', pid);
                }
              }
            }
            if (updated) {
              await _db.from('debts').update({'note': jsonEncode(data)}).eq('id', debt['id'] as String);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> restoreExpense(String expenseId) async {
    await _db
        .from('expenses')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', expenseId);
  }

  Future<List<CategoryModel>> getCategories(String coupleId) async {
    try {
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order', ascending: true, nullsFirst: false);
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    }
  }

  Future<List<CategoryModel>> getQuickAddCategories(String coupleId) async {
    try {
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .eq('show_in_quick_add', true)
          .order('sort_order', ascending: true, nullsFirst: false);
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    } catch (e) {
      if (_isMissingQuickAddColumn(e) || _isMissingSortOrderColumn(e)) {
        final rows = await _db
            .from('categories')
            .select()
            .eq('couple_id', coupleId)
            .eq('is_deleted', false)
            .order('name');
        return rows.map((r) => CategoryModel.fromJson(r)).toList();
      }
      rethrow;
    }
  }

  Future<List<CategoryModel>> getExpenseFormCategories(String coupleId) async {
    try {
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .eq('show_in_expense_form', true)
          .order('sort_order', ascending: true, nullsFirst: false);
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    } catch (e) {
      if (_isMissingExpenseFormColumn(e) || _isMissingSortOrderColumn(e)) {
        final rows = await _db
            .from('categories')
            .select()
            .eq('couple_id', coupleId)
            .eq('is_deleted', false)
            .order('name');
        return rows.map((r) => CategoryModel.fromJson(r)).toList();
      }
      rethrow;
    }
  }

  Future<int> _nextCategorySortOrder(String coupleId) async {
    try {
      final rows = await _db
          .from('categories')
          .select('sort_order')
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order', ascending: false, nullsFirst: false)
          .limit(1);
      if (rows.isEmpty) return 0;
      return ((rows.first['sort_order'] as num?)?.toInt() ?? 0) + 1;
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      return 0;
    }
  }

  Future<CategoryModel> createCategory({
    required String coupleId,
    required String name,
    String icon = '💰',
    String color = '#6366F1',
    bool showInQuickAdd = true,
    bool showInExpenseForm = true,
  }) async {
    final payload = {
      'couple_id': coupleId,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': await _nextCategorySortOrder(coupleId),
      'show_in_quick_add': showInQuickAdd,
      'show_in_expense_form': showInExpenseForm,
    };
    try {
      final row = await _db
          .from('categories')
          .insert(payload)
          .select()
          .single();
      return CategoryModel.fromJson(row);
    } catch (e) {
      if (!_isMissingQuickAddColumn(e) &&
          !_isMissingExpenseFormColumn(e) &&
          !_isMissingSortOrderColumn(e)) {
        rethrow;
      }
      payload.remove('sort_order');
      payload.remove('show_in_quick_add');
      payload.remove('show_in_expense_form');
      final row = await _db
          .from('categories')
          .insert(payload)
          .select()
          .single();
      return CategoryModel.fromJson(row);
    }
  }

  Future<CategoryModel> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
    required String color,
    required bool isActive,
    bool? showInQuickAdd,
    bool? showInExpenseForm,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'icon': icon,
      'color': color,
      'is_active': isActive,
    };
    if (showInQuickAdd != null) payload['show_in_quick_add'] = showInQuickAdd;
    if (showInExpenseForm != null) {
      payload['show_in_expense_form'] = showInExpenseForm;
    }

    try {
      final row = await _db
          .from('categories')
          .update(payload)
          .eq('id', categoryId)
          .select()
          .single();
      return CategoryModel.fromJson(row);
    } catch (e) {
      if (!_isMissingQuickAddColumn(e) && !_isMissingExpenseFormColumn(e)) {
        rethrow;
      }
      payload.remove('show_in_quick_add');
      payload.remove('show_in_expense_form');
      final row = await _db
          .from('categories')
          .update(payload)
          .eq('id', categoryId)
          .select()
          .single();
      return CategoryModel.fromJson(row);
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db
        .from('categories')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', categoryId);
  }

  Future<void> updateCategoryOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    final errors = <String>[];
    for (var i = 0; i < orderedIds.length; i++) {
      try {
        await _db
            .from('categories')
            .update({'sort_order': i})
            .eq('id', orderedIds[i])
            .eq('is_deleted', false);
      } catch (e) {
        if (_isMissingSortOrderColumn(e)) {
          return;
        }
        errors.add('ID ${orderedIds[i]}: $e');
      }
    }

    if (errors.isNotEmpty) {
      throw Exception(
        'Cập nhật thứ tự không hoàn toàn:\n${errors.join('\n')}',
      ).toString();
    }
  }
}
