import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/wallet/data/models/wallet_model.dart';

class WalletService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<WalletModel>> getWallets(String coupleId) async {
    final rows = await _db
        .from('wallets')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map((r) => WalletModel.fromJson(r)).toList();
  }

  Future<WalletModel> createWallet({
    required String coupleId,
    required String name,
    required String type,
    required String currency,
    bool isDefault = false,
    Map<String, dynamic>? goldMetadata,
  }) async {
    String dbName = name;
    String dbType = type;
    double initialBalance = 0;
    if (type == 'gold') {
      dbType = 'other';
      dbName = '[GOLD]$name|${jsonEncode(goldMetadata ?? {})}';
      initialBalance = ((goldMetadata?['rounds'] as List?) ?? []).fold<double>(
        0,
        (sum, item) => sum + ((item['total_price'] ?? item['total_amount'] ?? 0) as num).toDouble(),
      );
    }

    final row = await _db
        .from('wallets')
        .insert({
          'couple_id': coupleId,
          'name': dbName,
          'type': dbType,
          'currency': currency,
          'is_default': isDefault,
          'balance': initialBalance,
        })
        .select()
        .single();
    return WalletModel.fromJson(row);
  }

  Future<WalletModel> updateWallet(
    String walletId,
    Map<String, dynamic> data,
  ) async {
    final row = await _db
        .from('wallets')
        .update(data)
        .eq('id', walletId)
        .select()
        .single();
    return WalletModel.fromJson(row);
  }

  Future<void> deleteWallet(String walletId) async {
    await _db
        .from('wallets')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', walletId);
  }

  /// Computed balances from the wallet_balances view.
  Future<List<Map<String, dynamic>>> getWalletBalances(String coupleId) async {
    final rows = await _db
        .from('wallet_balances')
        .select()
        .eq('couple_id', coupleId);
    return List<Map<String, dynamic>>.from(rows);
  }
}
