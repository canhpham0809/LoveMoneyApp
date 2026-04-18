import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/transfer/data/models/transfer_model.dart';

class TransferService {
  SupabaseClient get _db => Supabase.instance.client;

  static const String _transferIncomeSourceName = 'Internal Transfer';

  bool _isMissingIncomeFormColumn(Object error) {
    return error is PostgrestException &&
        error.code == '42703' &&
        error.message.contains('show_in_income_form');
  }

  Future<List<TransferModel>> getTransfers(
    String coupleId, {
    String? viewerUserId,
    String? partnerUserId,
  }) async {
    var query = _db
        .from('transfers')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_deleted', false);

    if (viewerUserId != null) {
      if (partnerUserId != null) {
        query = query.or(
          'and(from_user_id.eq.$viewerUserId,to_user_id.eq.$partnerUserId),and(from_user_id.eq.$partnerUserId,to_user_id.eq.$viewerUserId)',
        );
      } else {
        query = query.or(
          'from_user_id.eq.$viewerUserId,to_user_id.eq.$viewerUserId',
        );
      }
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
    String? fromWalletId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final transferDate = date.toIso8601String().substring(0, 10);
    final incomeSourceId = await _ensureTransferIncomeSource(coupleId);
    final effectiveFromWalletId =
        fromWalletId ?? await _resolveDefaultWalletId(coupleId);
    if (effectiveFromWalletId == null) {
      throw Exception('Chua co vi mac dinh de chuyen tien.');
    }

    final transferRow = await _db
        .from('transfers')
        .insert({
          'couple_id': coupleId,
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'from_wallet_id': effectiveFromWalletId,
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
            'description': note?.trim().isEmpty == true ? null : note,
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

  Future<double> previewDeleteTransferImpact(String transferId) async {
    final row = await _db
        .from('transfers')
        .select('amount')
        .eq('id', transferId)
        .eq('is_deleted', false)
        .single();
    return (row['amount'] as num?)?.toDouble() ?? 0;
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
    String? fromWalletId,
    required double amount,
    String? note,
    required DateTime date,
  }) async {
    final existing = await _db
        .from('transfers')
        .select('couple_id, from_wallet_id')
        .eq('id', transferId)
        .single();
    final coupleId = existing['couple_id'] as String;
    final effectiveFromWalletId =
        fromWalletId ??
        (existing['from_wallet_id'] as String?) ??
        await _resolveDefaultWalletId(coupleId);
    if (effectiveFromWalletId == null) {
      throw Exception('Chua co vi mac dinh de chuyen tien.');
    }

    final transferDate = date.toIso8601String().substring(0, 10);
    final updatedTransfer = await _db
        .from('transfers')
        .update({
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'from_wallet_id': effectiveFromWalletId,
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
            'description': note?.trim().isEmpty == true ? null : note,
            'date': transferDate,
          })
          .eq('id', linkedIncomeId);
    }
  }

  Future<String> _ensureTransferIncomeSource(String coupleId) async {
    try {
      final existing = await _db
          .from('income_sources')
          .select('id, show_in_income_form')
          .eq('couple_id', coupleId)
          .eq('name', _transferIncomeSourceName)
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
            'name': _transferIncomeSourceName,
            'icon': 'swap_horiz',
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

  Future<String?> _resolveDefaultWalletId(String coupleId) async {
    final rows = await _db
        .from('wallets')
        .select('id, is_default')
        .eq('couple_id', coupleId)
        .eq('is_deleted', false)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }
}
