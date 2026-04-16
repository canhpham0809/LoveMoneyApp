import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_contribution_model.dart';

class FundService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<FundModel>> getFunds(String coupleId) async {
    final rows = await _db
        .from('funds')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map((r) => FundModel.fromJson(r)).toList();
  }

  Future<FundModel> createFund({
    required String coupleId,
    required String name,
    double? targetAmount,
    DateTime? deadline,
    String? icon,
    String? color,
  }) async {
    final row = await _db
        .from('funds')
        .insert({
          'couple_id': coupleId,
          'name': name,
          'target_amount': targetAmount,
          'deadline': deadline?.toIso8601String().substring(0, 10),
          'icon': icon,
          'color': color,
          'current_amount': 0,
        })
        .select()
        .single();
    return FundModel.fromJson(row);
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

  Future<void> deleteFund(String fundId) async {
    await _db
        .from('funds')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
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

  Future<void> updateContribution({
    required String contributionId,
    required String fundId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final existing = await _db
        .from('fund_contributions')
        .select('amount')
        .eq('id', contributionId)
        .single();
    final previousAmount = (existing['amount'] as num?)?.toDouble() ?? 0;

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
        .select('current_amount')
        .eq('id', fundId)
        .single();
    final currentAmount = (fund['current_amount'] as num?)?.toDouble() ?? 0;
    final nextAmount = currentAmount - previousAmount + amount;
    await _db.from('funds').update({'current_amount': nextAmount}).eq('id', fundId);
  }

  Future<void> deleteContribution({
    required String contributionId,
    required String fundId,
  }) async {
    final existing = await _db
        .from('fund_contributions')
        .select('amount')
        .eq('id', contributionId)
        .single();
    final previousAmount = (existing['amount'] as num?)?.toDouble() ?? 0;

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
    final nextAmount = (currentAmount - previousAmount).clamp(0, double.infinity);
    await _db.from('funds').update({'current_amount': nextAmount}).eq('id', fundId);
  }
}
