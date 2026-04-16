import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';

class QuickAddResult {
  final bool success;
  final bool fallbackRequired;
  final String input;
  final double? parsedAmount;
  final String? suggestedCategoryId;
  final String? suggestedCategoryName;
  final ExpenseModel? expense;

  const QuickAddResult({
    required this.success,
    required this.fallbackRequired,
    required this.input,
    this.parsedAmount,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.expense,
  });
}

class QuickAddService {
  SupabaseClient get _db => Supabase.instance.client;

  static final RegExp _inputPattern = RegExp(
    r'^\s*([0-9]+(?:[\.,][0-9]+)?)\s*(k|tr)?\s*(.*)$',
    caseSensitive: false,
  );

  static const Map<String, List<String>> _categoryKeywordMap = {
    'food': ['an', 'com', 'breakfast', 'lunch', 'dinner', 'coffee', 'tra sua'],
    'transport': ['xang', 'grab', 'taxi', 'xe bus', 'parking'],
    'utilities': ['dien', 'nuoc', 'internet', 'wifi', 'electricity'],
    'shopping': ['mua sam', 'shop', 'mall', 'sieu thi'],
    'health': ['thuoc', 'benh vien', 'kham', 'health'],
  };

  Future<QuickAddResult> quickAddExpense({
    required String coupleId,
    required String userId,
    required String input,
    String? forcedCategoryId,
    String? forcedCategoryName,
  }) async {
    final parsed = _parseInput(input);
    if (parsed == null) {
      return QuickAddResult(
        success: false,
        fallbackRequired: true,
        input: input,
      );
    }

    final wallets = await _db
        .from('wallets')
        .select('id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true)
        .limit(1);

    if (wallets.isEmpty) {
      return QuickAddResult(
        success: false,
        fallbackRequired: true,
        input: input,
        parsedAmount: parsed.amount,
      );
    }

    final categories = await _db
        .from('categories')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .eq('is_active', true)
        .order('name');

    if (categories.isEmpty) {
      return QuickAddResult(
        success: false,
        fallbackRequired: true,
        input: input,
        parsedAmount: parsed.amount,
      );
    }

    final categoryList = List<Map<String, dynamic>>.from(categories);
    final suggestedCategory = forcedCategoryId != null
        ? categoryList.firstWhere(
            (c) => c['id'] == forcedCategoryId,
            orElse: () => categoryList.first,
          )
        : _suggestCategory(
            description: parsed.description,
            categories: categoryList,
          );

    final row = await _db
        .from('expenses')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'wallet_id': wallets.first['id'] as String,
          'category_id': suggestedCategory['id'] as String,
          'amount': parsed.amount,
          'description': parsed.description.isEmpty ? null : parsed.description,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        })
        .select()
        .single();

    return QuickAddResult(
      success: true,
      fallbackRequired: false,
      input: input,
      parsedAmount: parsed.amount,
      suggestedCategoryId: suggestedCategory['id'] as String,
      suggestedCategoryName:
          forcedCategoryName ?? (suggestedCategory['name'] as String),
      expense: ExpenseModel.fromJson(row),
    );
  }

  _ParsedQuickInput? _parseInput(String input) {
    final match = _inputPattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final numberRaw = (match.group(1) ?? '').replaceAll(',', '.');
    final unit = (match.group(2) ?? '').toLowerCase();
    final description = (match.group(3) ?? '').trim();
    final base = double.tryParse(numberRaw);
    if (base == null || base <= 0) {
      return null;
    }

    double multiplier = 1;
    if (unit == 'k') {
      multiplier = 1000;
    } else if (unit == 'tr') {
      multiplier = 1000000;
    }

    return _ParsedQuickInput(
      amount: base * multiplier,
      description: description,
    );
  }

  Map<String, dynamic> _suggestCategory({
    required String description,
    required List<Map<String, dynamic>> categories,
  }) {
    if (description.isNotEmpty) {
      final text = description.toLowerCase();

      for (final category in categories) {
        final name = (category['name'] as String).toLowerCase();
        if (text.contains(name)) {
          return category;
        }
      }

      for (final entry in _categoryKeywordMap.entries) {
        if (!entry.value.any(text.contains)) {
          continue;
        }
        final mapped = categories.where((category) {
          final name = (category['name'] as String).toLowerCase();
          return name.contains(entry.key) || entry.value.any(name.contains);
        });
        if (mapped.isNotEmpty) {
          return mapped.first;
        }
      }
    }

    return categories.first;
  }
}

class _ParsedQuickInput {
  final double amount;
  final String description;

  const _ParsedQuickInput({required this.amount, required this.description});
}
