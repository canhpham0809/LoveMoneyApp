import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/transfer/data/models/transfer_model.dart';

class TransferService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<TransferModel>> getTransfers(String coupleId) async {
    final rows = await _db
        .from('transfers')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('date', ascending: false);
    return rows.map((r) => TransferModel.fromJson(r)).toList();
  }

  Future<TransferModel> createTransfer({
    required String coupleId,
    required String fromUserId,
    required String toUserId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final row = await _db
        .from('transfers')
        .insert({
          'couple_id': coupleId,
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'from_wallet_id': fromWalletId,
          'to_wallet_id': toWalletId,
          'amount': amount,
          'note': note,
          'date': date.toIso8601String().substring(0, 10),
        })
        .select()
        .single();
    return TransferModel.fromJson(row);
  }

  Future<void> deleteTransfer(String transferId) async {
    await _db
        .from('transfers')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', transferId);
  }
}
