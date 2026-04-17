import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/transfer/data/models/transfer_model.dart';

class TransferService {
  SupabaseClient get _db => Supabase.instance.client;

  static const String _transferIncomeSourceName = 'Internal Transfer';

  Future<List<TransferModel>> getTransfers(
    String coupleId, {
    String? createdByUserId,
  }) async {
    var query = _db
        .from('transfers')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (createdByUserId != null) {
      query = query.eq('from_user_id', createdByUserId);
    }

    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => TransferModel.fromJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getCoupleMembers(String coupleId) async {
    final rows = await _db
        .from('couple_members')
        .select('user_id')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('joined_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<TransferModel> createTransfer({
    required String coupleId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final transferDate = date.toIso8601String().substring(0, 10);
    final incomeSourceId = await _ensureTransferIncomeSource(coupleId);

    final transferRow = await _db
        .from('transfers')
        .insert({
          'couple_id': coupleId,
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'from_wallet_id': null,
          'to_wallet_id': null,
          'amount': amount,
          'note': note,
          'date': transferDate,
        })
        .select()
        .single();

    final transferId = transferRow['id'] as String;

    try {
      final incomeRow = await _db
          .from('incomes')
          .insert({
            'couple_id': coupleId,
            'user_id': toUserId,
            'wallet_id': null,
            'income_source_id': incomeSourceId,
            'amount': amount,
            'description': note?.trim().isEmpty == true
                ? 'Transfer from partner'
                : note,
            'is_from_transfer': true,
            'linked_transfer_id': transferId,
            'date': transferDate,
          })
          .select('id')
          .single();

      final linkedIncomeId = incomeRow['id'] as String;
      final updatedTransfer = await _db
          .from('transfers')
          .update({'linked_income_id': linkedIncomeId})
          .eq('id', transferId)
          .select()
          .single();
      return TransferModel.fromJson(updatedTransfer);
    } catch (_) {
      await _db.from('transfers').delete().eq('id', transferId);
      rethrow;
    }
  }

  Future<void> deleteTransfer(String transferId) async {
    await _db
        .from('incomes')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('linked_transfer_id', transferId)
        .eq('is_deleted', false);

    await _db
        .from('transfers')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', transferId);
  }

  Future<void> restoreTransfer(String transferId) async {
    await _db
        .from('transfers')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', transferId);
    await _db
        .from('incomes')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('linked_transfer_id', transferId);
  }

  Future<void> updateTransfer({
    required String transferId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final transferDate = date.toIso8601String().substring(0, 10);
    final updatedTransfer = await _db
        .from('transfers')
        .update({
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'from_wallet_id': null,
          'to_wallet_id': null,
          'amount': amount,
          'note': note,
          'date': transferDate,
        })
        .eq('id', transferId)
        .select('linked_income_id, couple_id')
        .single();

    final linkedIncomeId = updatedTransfer['linked_income_id'] as String?;
    if (linkedIncomeId != null) {
      await _db
          .from('incomes')
          .update({
            'user_id': toUserId,
            'wallet_id': null,
            'amount': amount,
            'description': note?.trim().isEmpty == true
                ? 'Transfer from partner'
                : note,
            'date': transferDate,
          })
          .eq('id', linkedIncomeId);
    }
  }

  Future<String> _ensureTransferIncomeSource(String coupleId) async {
    final existing = await _db
        .from('income_sources')
        .select('id')
        .eq('couple_id', coupleId)
        .eq('name', _transferIncomeSourceName)
        .eq('is_deleted', false)
        .limit(1);
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }

    final created = await _db
        .from('income_sources')
        .insert({
          'couple_id': coupleId,
          'name': _transferIncomeSourceName,
          'icon': 'swap_horiz',
          'type': 'other',
        })
        .select('id')
        .single();
    return created['id'] as String;
  }
}
