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
    return FundContributionModel.fromJson(row);
  }
}
