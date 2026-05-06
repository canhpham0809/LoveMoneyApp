import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_contribution_model.dart';

class FundService {
  SupabaseClient get _db => Supabase.instance.client;
  static const String _fundWithdrawIncomeSourceName = 'Rút quỹ';

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

  bool _isMissingCreatorUserIdColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('creator_user_id');
  }

  Future<List<FundModel>> getFunds(
    String coupleId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final ordered = _db
          .from('funds')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('sort_order')
          .order('created_at');
      final rows = (limit != null && offset != null)
          ? await ordered.range(offset, offset + limit - 1)
          : await ordered;
      return rows.map((r) => FundModel.fromJson(r)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final ordered = _db
          .from('funds')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('name');
      final rows = (limit != null && offset != null)
          ? await ordered.range(offset, offset + limit - 1)
          : await ordered;
      return rows.map((r) => FundModel.fromJson(r)).toList();
    }
  }

  Future<int> _nextSortOrder(String coupleId) async {
    try {
      final rows = await _db
          .from('funds')
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

  Future<FundModel> createFund({
    required String coupleId,
    required String name,
    double? targetAmount,
    DateTime? deadline,
    String? icon,
    String? color,
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Không tìm thấy phiên đăng nhập.');
    }

    final payload = {
      'couple_id': coupleId,
      'creator_user_id': currentUserId,
      'name': name,
      'target_amount': targetAmount,
      'deadline': deadline?.toIso8601String().substring(0, 10),
      'icon': icon,
      'color': color,
      'current_amount': 0,
      'sort_order': await _nextSortOrder(coupleId),
    };

    try {
      final row = await _db.from('funds').insert(payload).select().single();
      return FundModel.fromJson(row);
    } catch (e) {
      if (_isMissingCreatorUserIdColumn(e)) {
        payload.remove('creator_user_id');
      } else if (!_isMissingSortOrderColumn(e)) {
        rethrow;
      }
      payload.remove('sort_order');
      final row = await _db.from('funds').insert(payload).select().single();
      return FundModel.fromJson(row);
    }
  }

  Future<void> updateFundOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;

    for (var i = 0; i < orderedIds.length; i++) {
      try {
        await _db
            .from('funds')
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

  Future<FundModel> getFundById(String fundId) async {
    final row = await _db.from('funds').select().eq('id', fundId).single();
    return FundModel.fromJson(row);
  }

  Future<void> updateFund({
    required String fundId,
    required String name,
    double? targetAmount,
    DateTime? deadline,
    String? icon,
    String? color,
  }) async {
    await _db
        .from('funds')
        .update({
          'name': name,
          'target_amount': targetAmount,
          'deadline': deadline?.toIso8601String().substring(0, 10),
          'icon': icon,
          'color': color,
        })
        .eq('id', fundId);
  }

  Future<double> previewDeleteFundSettlement(String fundId) async {
    final row = await _db
        .from('funds')
        .select('current_amount')
        .eq('id', fundId)
        .single();
    return (row['current_amount'] as num?)?.toDouble() ?? 0;
  }

  Future<void> deleteFund(String fundId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Không tìm thấy phiên đăng nhập.');
    }

    late final Map<String, dynamic> fundRow;
    try {
      fundRow = await _db
          .from('funds')
          .select(
            'couple_id, name, current_amount, creator_user_id, updated_by',
          )
          .eq('id', fundId)
          .single();
    } catch (e) {
      if (!_isMissingCreatorUserIdColumn(e)) rethrow;
      fundRow = await _db
          .from('funds')
          .select('couple_id, name, current_amount, updated_by')
          .eq('id', fundId)
          .single();
    }

    final creatorUserId =
        fundRow['creator_user_id'] as String? ??
        fundRow['updated_by'] as String?;
    if (creatorUserId != null && creatorUserId != currentUserId) {
      throw Exception('Chỉ người tạo quỹ mới có quyền xóa.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final contributionRows = List<Map<String, dynamic>>.from(
      await _db
          .from('fund_contributions')
          .select('id, linked_income_id')
          .eq('fund_id', fundId)
          .eq('is_deleted', false),
    );

    final linkedIncomeIds = contributionRows
        .map((row) => row['linked_income_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (linkedIncomeIds.isNotEmpty) {
      await _db
          .from('incomes')
          .update({'is_deleted': true, 'deleted_at': nowIso})
          .inFilter('id', linkedIncomeIds)
          .eq('is_deleted', false);
    }

    await _db
        .from('fund_contributions')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('fund_id', fundId)
        .eq('is_deleted', false);

    await _db
        .from('funds')
        .update({'is_deleted': true, 'deleted_at': nowIso})
        .eq('id', fundId);
  }

  Future<List<FundContributionModel>> getContributionsByFund({
    required String coupleId,
    required String fundId,
  }) async {
    final rows = await _db
        .from('fund_contributions')
        .select()
        .eq('couple_id', coupleId)
        .eq('fund_id', fundId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows.map((r) => FundContributionModel.fromJson(r)).toList();
  }

  Future<FundContributionModel> createContribution({
    required String coupleId,
    required String userId,
    required String fundId,
    required String walletId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final row = await _db
        .from('fund_contributions')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'fund_id': fundId,
          'wallet_id': walletId,
          'amount': amount,
          'contribution_type': 'contribution',
          'note': note,
          'date': date.toIso8601String().substring(0, 10),
        })
        .select()
        .single();

    final fund = await _db
        .from('funds')
        .select('current_amount')
        .eq('id', fundId)
        .single();
    final currentAmount = (fund['current_amount'] as num?)?.toDouble() ?? 0;
    await _db
        .from('funds')
        .update({'current_amount': currentAmount + amount})
        .eq('id', fundId);

    return FundContributionModel.fromJson(row);
  }

  Future<FundContributionModel> createWithdrawal({
    required String coupleId,
    required String userId,
    required String fundId,
    required String walletId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final fund = await _db
        .from('funds')
        .select('name, current_amount')
        .eq('id', fundId)
        .single();
    final fundName = (fund['name'] as String?)?.trim() ?? 'Quỹ';
    final currentAmount = (fund['current_amount'] as num?)?.toDouble() ?? 0;
    if (amount > currentAmount) {
      throw Exception('Số tiền rút vượt quá số dư quỹ hiện tại.');
    }

    final row = await _db
        .from('fund_contributions')
        .insert({
          'couple_id': coupleId,
          'user_id': userId,
          'fund_id': fundId,
          'wallet_id': walletId,
          'amount': amount,
          'contribution_type': 'withdrawal',
          'note': note,
          'date': date.toIso8601String().substring(0, 10),
        })
        .select()
        .single();

    final contributionId = row['id'] as String;

    try {
      final incomeSourceId = await _ensureFundWithdrawIncomeSource(coupleId);
      final incomeRow = await _db
          .from('incomes')
          .insert({
            'couple_id': coupleId,
            'user_id': userId,
            'wallet_id': walletId,
            'income_source_id': incomeSourceId,
            'amount': amount,
            'description': note?.trim().isNotEmpty == true
                ? note!.trim()
                : 'Rút quỹ: $fundName',
            'is_from_transfer': false,
            'date': date.toIso8601String().substring(0, 10),
          })
          .select('id')
          .single();

      await _db
          .from('fund_contributions')
          .update({'linked_income_id': incomeRow['id'] as String})
          .eq('id', contributionId);

      await _db
          .from('funds')
          .update({'current_amount': currentAmount - amount})
          .eq('id', fundId);

      final updated = await _db
          .from('fund_contributions')
          .select()
          .eq('id', contributionId)
          .single();
      return FundContributionModel.fromJson(updated);
    } catch (_) {
      await _db.from('fund_contributions').delete().eq('id', contributionId);
      rethrow;
    }
  }

  Future<void> updateContribution({
    required String contributionId,
    required String fundId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final existing = await _db
        .from('fund_contributions')
        .select(
          'amount, contribution_type, linked_income_id, wallet_id, user_id',
        )
        .eq('id', contributionId)
        .single();
    final previousAmount = (existing['amount'] as num?)?.toDouble() ?? 0;
    final contributionType =
        (existing['contribution_type'] as String?) ?? 'contribution';
    final linkedIncomeId = existing['linked_income_id'] as String?;
    final walletId = existing['wallet_id'] as String?;
    final userId = existing['user_id'] as String?;

    await _db
        .from('fund_contributions')
        .update({
          'amount': amount,
          'note': note,
          'date': date.toIso8601String().substring(0, 10),
        })
        .eq('id', contributionId);

    final fund = await _db
        .from('funds')
        .select('current_amount, name')
        .eq('id', fundId)
        .single();
    final currentAmount = (fund['current_amount'] as num?)?.toDouble() ?? 0;
    if (contributionType == 'withdrawal') {
      final maxAllowed = currentAmount + previousAmount;
      if (amount > maxAllowed) {
        throw Exception('Số tiền rut vuot qua so du quy hien tai.');
      }
    }

    final signedPrevious = contributionType == 'withdrawal'
        ? -previousAmount
        : previousAmount;
    final signedNext = contributionType == 'withdrawal' ? -amount : amount;
    final nextAmount = currentAmount - signedPrevious + signedNext;
    await _db
        .from('funds')
        .update({'current_amount': nextAmount})
        .eq('id', fundId);

    if (contributionType == 'withdrawal' && linkedIncomeId != null) {
      final fundName = (fund['name'] as String?)?.trim() ?? 'Quỹ';
      await _db
          .from('incomes')
          .update({
            'wallet_id': walletId,
            'user_id': userId,
            'amount': amount,
            'description': note?.trim().isNotEmpty == true
                ? note!.trim()
                : 'Rút quỹ: $fundName',
            'date': date.toIso8601String().substring(0, 10),
          })
          .eq('id', linkedIncomeId)
          .eq('is_deleted', false);
    }
  }

  Future<void> deleteContribution({
    required String contributionId,
    required String fundId,
  }) async {
    final existing = await _db
        .from('fund_contributions')
        .select('amount, contribution_type, linked_income_id')
        .eq('id', contributionId)
        .single();
    final previousAmount = (existing['amount'] as num?)?.toDouble() ?? 0;
    final contributionType =
        (existing['contribution_type'] as String?) ?? 'contribution';
    final linkedIncomeId = existing['linked_income_id'] as String?;

    await _db
        .from('fund_contributions')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', contributionId);

    final fund = await _db
        .from('funds')
        .select('current_amount')
        .eq('id', fundId)
        .single();
    final currentAmount = (fund['current_amount'] as num?)?.toDouble() ?? 0;
    final signedPrevious = contributionType == 'withdrawal'
        ? -previousAmount
        : previousAmount;
    final nextAmount = (currentAmount - signedPrevious).clamp(
      0,
      double.infinity,
    );
    await _db
        .from('funds')
        .update({'current_amount': nextAmount})
        .eq('id', fundId);

    if (contributionType == 'withdrawal' && linkedIncomeId != null) {
      await _db
          .from('incomes')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', linkedIncomeId)
          .eq('is_deleted', false);
    }
  }

  Future<double> previewDeleteContributionImpact(String contributionId) async {
    final row = await _db
        .from('fund_contributions')
        .select('amount, contribution_type')
        .eq('id', contributionId)
        .eq('is_deleted', false)
        .single();

    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final contributionType =
        (row['contribution_type'] as String?) ?? 'contribution';

    if (contributionType == 'withdrawal') {
      return -amount;
    }
    return 0;
  }

  Future<String> _ensureFundWithdrawIncomeSource(String coupleId) async {
    try {
      final existing = await _db
          .from('income_sources')
          .select('id, show_in_income_form')
          .eq('couple_id', coupleId)
          .eq('name', _fundWithdrawIncomeSourceName)
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
            'name': _fundWithdrawIncomeSourceName,
            'icon': 'savings',
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
          .eq('name', _fundWithdrawIncomeSourceName)
          .eq('is_deleted', false)
          .limit(1);

      if (existing.isNotEmpty) {
        return existing.first['id'] as String;
      }

      final created = await _db
          .from('income_sources')
          .insert({
            'couple_id': coupleId,
            'name': _fundWithdrawIncomeSourceName,
            'icon': 'savings',
            'type': 'other',
          })
          .select('id')
          .single();
      return created['id'] as String;
    }
  }
}
