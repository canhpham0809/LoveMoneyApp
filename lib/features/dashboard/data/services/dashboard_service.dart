import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  SupabaseClient get _db => Supabase.instance.client;

  /// Returns wallet balances from the computed view.
  Future<List<Map<String, dynamic>>> getWalletBalances(String coupleId) async {
    final rows = await _db
        .from('wallet_balances')
        .select()
        .eq('couple_id', coupleId);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Total income for the current month.
  Future<double> getMonthlyIncome(String coupleId) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('incomes')
        .select('amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    return rows.fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Total expense for the current month.
  Future<double> getMonthlyExpense(String coupleId) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('expenses')
        .select('amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    return rows.fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Recent transactions (latest 20 across expense, income, transfer).
  Future<List<Map<String, dynamic>>> getRecentTransactions(
    String coupleId,
  ) async {
    final categories = await _db
        .from('categories')
        .select('id, name')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);
    final categoryNameById = {
      for (final c in categories) c['id'] as String: c['name'] as String,
    };

    final expenses = await _db
        .from('expenses')
      .select('id, amount, date, description, category_id, category_name, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
      .order('created_at', ascending: false)
        .limit(10);
    final incomes = await _db
        .from('incomes')
      .select('id, amount, date, description, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
      .order('created_at', ascending: false)
        .limit(10);
    final transfers = await _db
        .from('transfers')
      .select('id, amount, date, note, created_at')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
      .order('created_at', ascending: false)
        .limit(10);

    final normalizedExpenses = expenses.map((e) {
      final categoryId = e['category_id'] as String?;
      return {
        ...e,
        'type': 'expense',
        'resolved_category_name': categoryId == null
            ? (e['category_name'] as String?)
            : (categoryNameById[categoryId] ?? (e['category_name'] as String?)),
      };
    });

    final combined = [
      ...normalizedExpenses,
      ...incomes.map((i) => {...i, 'type': 'income'}),
      ...transfers.map((t) => {...t, 'type': 'transfer'}),
    ];
    DateTime parseCreatedAt(Map<String, dynamic> tx) {
      final value = tx['created_at'] as String?;
      if (value == null || value.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    combined.sort((a, b) => parseCreatedAt(b).compareTo(parseCreatedAt(a)));
    return combined.take(20).toList();
  }

  /// Expense breakdown by category for the current month.
  Future<List<Map<String, dynamic>>> getCategoryBreakdown(
    String coupleId,
  ) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final rows = await _db
        .from('expenses')
        .select('category_name, amount')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10));
    // Group by category client-side
    final Map<String, double> map = {};
    for (final r in rows) {
      final cat = (r['category_name'] as String?) ?? 'Other';
      map[cat] = (map[cat] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }
    return map.entries
        .map((e) => {'category': e.key, 'amount': e.value})
        .toList()
      ..sort(
        (a, b) => (b['amount']! as double).compareTo(a['amount']! as double),
      );
  }
}
