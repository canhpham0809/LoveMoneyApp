import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';

class ExpenseService {
  SupabaseClient get _db => Supabase.instance.client;

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
  }) async {
    var query = _db
        .from('expenses')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (createdByUserId != null) {
      query = query.eq('user_id', createdByUserId);
    }

    final rows = await query.order('created_at', ascending: false);
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
  }) async {
    await _db
        .from('expenses')
        .update({
          'wallet_id': walletId,
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date.toIso8601String().substring(0, 10),
        })
        .eq('id', expenseId);
  }

  Future<void> restoreExpense(String expenseId) async {
    await _db
        .from('expenses')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', expenseId);
  }

  Future<List<CategoryModel>> getCategories(String coupleId) async {
    final rows = await _db
        .from('categories')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map((r) => CategoryModel.fromJson(r)).toList();
  }

  Future<List<CategoryModel>> getQuickAddCategories(String coupleId) async {
    try {
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .eq('show_in_quick_add', true)
          .order('name');
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingQuickAddColumn(e)) rethrow;
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
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
          .order('name');
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingExpenseFormColumn(e)) rethrow;
      final rows = await _db
          .from('categories')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      return rows.map((r) => CategoryModel.fromJson(r)).toList();
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
      'sort_order': 0,
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
      if (!_isMissingQuickAddColumn(e) && !_isMissingExpenseFormColumn(e)) {
        rethrow;
      }
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
}
