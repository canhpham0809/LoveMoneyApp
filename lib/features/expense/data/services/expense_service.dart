import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';

class ExpenseService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<ExpenseModel>> getExpenses(String coupleId) async {
    final rows = await _db
        .from('expenses')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
      .order('created_at', ascending: false);
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

  Future<CategoryModel> createCategory({
    required String coupleId,
    required String name,
    String icon = '💰',
    String color = '#6366F1',
  }) async {
    final row = await _db
        .from('categories')
        .insert({
          'couple_id': coupleId,
          'name': name,
          'icon': icon,
          'color': color,
          'sort_order': 0,
        })
        .select()
        .single();
    return CategoryModel.fromJson(row);
  }
}
