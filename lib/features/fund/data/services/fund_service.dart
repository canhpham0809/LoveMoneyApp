import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_app_demo/features/fund/data/models/fund_contribution_model.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';

class FundService {
  SupabaseClient get _db => Supabase.instance.client;
  final Uuid _uuid = const Uuid();

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
      return rows.map((row) => FundModel.fromJson(row)).toList();
    } catch (e) {
      if (!_isMissingSortOrderColumn(e)) rethrow;
      final ordered = _db
          .from('funds')
          .select()
          .eq('couple_id', coupleId)
          .eq('is_deleted', false)
          .order('created_at');
      final rows = (limit != null && offset != null)
          ? await ordered.range(offset, offset + limit - 1)
          : await ordered;
      return rows.map((row) => FundModel.fromJson(row)).toList();
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
    bool isGold = false,
    Map<String, dynamic>? goldMetadata,
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Không tìm thấy phiên đăng nhập.');
    }

    String dbName = name;
    if (isGold) {
      dbName = '[GOLD]$name|${jsonEncode(goldMetadata ?? {})}';
    }

    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'couple_id': coupleId,
      'creator_user_id': currentUserId,
      'name': dbName,
      'target_amount': targetAmount,
      'deadline': deadline?.toIso8601String().substring(0, 10),
      'icon': icon,
      'color': color,
      'current_amount': 0,
      'is_active': true,
      'is_deleted': false,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sort_order': await _nextSortOrder(coupleId),
    };

    final row = await _createFundRemote(payload);
    return FundModel.fromJson(row);
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
    bool isGold = false,
    Map<String, dynamic>? goldMetadata,
  }) async {
    String dbName = name;
    if (isGold) {
      dbName = '[GOLD]$name|${jsonEncode(goldMetadata ?? {})}';
    }

    await _db
        .from('funds')
        .update({
          'name': dbName,
          'target_amount': targetAmount,
          'deadline': deadline?.toIso8601String().substring(0, 10),
          'icon': icon,
          'color': color,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', fundId);
  }

  Future<void> updateGoldPrice(String fundId, double newPrice) async {
    final fund = await getFundById(fundId);
    if (!fund.isGold) return;

    final nextMeta = Map<String, dynamic>.from(fund.goldMetadata ?? {});
    nextMeta['custom_gold_price'] = newPrice;

    final dbName = '[GOLD]${fund.cleanName}|${jsonEncode(nextMeta)}';

    await _db
        .from('funds')
        .update({
          'name': dbName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
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




    await _deleteFundRemote(fundId, DateTime.now().toUtc().toIso8601String());
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
    return rows.map((row) => FundContributionModel.fromJson(row)).toList();
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
    final now = DateTime.now().toUtc();
    final payload = {
      'id': _uuid.v4(),
      'couple_id': coupleId,
      'user_id': userId,
      'fund_id': fundId,
      'wallet_id': walletId,
      'amount': amount,
      'contribution_type': 'contribution',
      'note': note,
      'date': date.toIso8601String().substring(0, 10),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'is_deleted': false,
    };

    final row = await _createFundContributionRemote(payload);
    await _refreshFundFromRemote(fundId);
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
    final fund = await getFundById(fundId);
    final fundName = fund.name.trim();
    if (fund.isGold) {
      double withdrawGoldQty = 0;
      if (note != null && note.startsWith('[GOLD]')) {
        try {
          final decoded = jsonDecode(note.substring(6));
          if (decoded is Map) {
            final qtyVal = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'];
            if (qtyVal is num) {
              withdrawGoldQty = qtyVal.toDouble();
            }
          }
        } catch (_) {}
      }
      if (withdrawGoldQty > fund.currentGoldQuantity) {
        throw Exception('Số lượng vàng rút (${withdrawGoldQty} chỉ) vượt quá số dư vàng hiện tại của quỹ (${fund.currentGoldQuantity} chỉ).');
      }
    } else {
      if (amount > fund.currentAmount) {
        throw Exception('Số tiền rút vượt quá số dư quỹ hiện tại.');
      }
    }

    final now = DateTime.now().toUtc();
    final payload = {
      'id': _uuid.v4(),
      'couple_id': coupleId,
      'user_id': userId,
      'fund_id': fundId,
      'wallet_id': walletId,
      'amount': amount,
      'contribution_type': 'withdrawal',
      'note': note,
      'date': date.toIso8601String().substring(0, 10),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'is_deleted': false,
      'fund_name': fundName,
    };

    final row = await _createFundContributionRemote(payload);
    await _refreshFundFromRemote(fundId);
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
        .select(
          'amount, contribution_type, linked_income_id, wallet_id, user_id, note',
        )
        .eq('id', contributionId)
        .single();

    final previousAmount = (existing['amount'] as num?)?.toDouble() ?? 0;
    final contributionType =
        (existing['contribution_type'] as String?) ?? 'contribution';
    final linkedIncomeId = existing['linked_income_id'] as String?;
    final walletId = existing['wallet_id'] as String?;
    final userId = existing['user_id'] as String?;

    final fund = await getFundById(fundId);
    final currentAmount = fund.currentAmount;
    if (contributionType == 'withdrawal') {
      if (fund.isGold) {
        double previousGoldQty = 0;
        final prevNote = existing['note'] as String?;
        if (prevNote != null && prevNote.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(prevNote.substring(6));
            if (decoded is Map) {
              final qtyVal = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'];
              if (qtyVal is num) {
                previousGoldQty = qtyVal.toDouble();
              }
            }
          } catch (_) {}
        }

        double newGoldQty = 0;
        if (note != null && note.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(note.substring(6));
            if (decoded is Map) {
              final qtyVal = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'];
              if (qtyVal is num) {
                newGoldQty = qtyVal.toDouble();
              }
            }
          } catch (_) {}
        }

        final maxGoldAllowed = fund.currentGoldQuantity + previousGoldQty;
        if (newGoldQty > maxGoldAllowed) {
          throw Exception('Số lượng vàng rút (${newGoldQty} chỉ) vượt quá số dư vàng hiện tại của quỹ (${maxGoldAllowed} chỉ).');
        }
      } else {
        final maxAllowed = currentAmount + previousAmount;
        if (amount > maxAllowed) {
          throw Exception('Số tiền rút vượt quá số dư quỹ hiện tại.');
        }
      }
    }

    await _db
        .from('fund_contributions')
        .update({
          'amount': amount,
          'note': note,
          'date': date.toIso8601String().substring(0, 10),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', contributionId);

    bool recordAsIncome = true;
    if (note != null) {
      if (note.startsWith('[GOLD]')) {
        try {
          final decoded = jsonDecode(note.substring(6));
          if (decoded is Map) {
            final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
            if (incVal is bool) {
              recordAsIncome = incVal;
            }
          }
        } catch (_) {}
      } else if (note.startsWith('[WITHDRAWAL]')) {
        try {
          final decoded = jsonDecode(note.substring(12));
          if (decoded is Map) {
            final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
            if (incVal is bool) {
              recordAsIncome = incVal;
            }
          }
        } catch (_) {}
      }
    }

    if (contributionType == 'withdrawal') {
      if (recordAsIncome) {
        if (linkedIncomeId != null) {
          await _db
              .from('incomes')
              .update({
                'wallet_id': walletId,
                'user_id': userId,
                'amount': amount,
                'description': note?.trim().isNotEmpty == true
                    ? _cleanWithdrawalNote(note!, fund.cleanName)
                    : 'Rút quỹ: ${fund.cleanName}',
                'date': date.toIso8601String().substring(0, 10),
              })
              .eq('id', linkedIncomeId)
              .eq('is_deleted', false);
        } else {
          final incomeSourceId = await _ensureFundWithdrawIncomeSource(fund.coupleId);
          final incomeRow = await _db
              .from('incomes')
              .insert({
                'couple_id': fund.coupleId,
                'user_id': userId,
                'wallet_id': walletId,
                'income_source_id': incomeSourceId,
                'amount': amount,
                'description': note?.trim().isNotEmpty == true
                    ? _cleanWithdrawalNote(note!, fund.cleanName)
                    : 'Rút quỹ: ${fund.cleanName}',
                'is_from_transfer': false,
                'date': date.toIso8601String().substring(0, 10),
              })
              .select('id')
              .single();
          await _db
              .from('fund_contributions')
              .update({'linked_income_id': incomeRow['id'] as String})
              .eq('id', contributionId);
        }
      } else {
        if (linkedIncomeId != null) {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await _db
              .from('incomes')
              .update({'is_deleted': true, 'deleted_at': nowIso})
              .eq('id', linkedIncomeId);
          await _db
              .from('fund_contributions')
              .update({'linked_income_id': null})
              .eq('id', contributionId);
        }
      }
    }

    await _refreshFundFromRemote(fundId);
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

    final contributionType =
        (existing['contribution_type'] as String?) ?? 'contribution';
    final linkedIncomeId = existing['linked_income_id'] as String?;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _db
        .from('fund_contributions')
        .update({
          'is_deleted': true,
          'deleted_at': nowIso,
          'updated_at': nowIso,
        })
        .eq('id', contributionId);

    if (contributionType == 'withdrawal' && linkedIncomeId != null) {
      await _db
          .from('incomes')
          .update({'is_deleted': true, 'deleted_at': nowIso})
          .eq('id', linkedIncomeId)
          .eq('is_deleted', false);
    }

    await _refreshFundFromRemote(fundId);
  }

  Future<Map<String, dynamic>> _createFundRemote(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _db.from('funds').insert(payload).select().single();
    } catch (e) {
      if (_isMissingCreatorUserIdColumn(e)) {
        payload.remove('creator_user_id');
      } else if (!_isMissingSortOrderColumn(e)) {
        rethrow;
      }
      payload.remove('sort_order');
      return await _db.from('funds').insert(payload).select().single();
    }
  }

  Future<void> _deleteFundRemote(String fundId, String nowIso) async {
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

  Future<Map<String, dynamic>> _createFundContributionRemote(
    Map<String, dynamic> payload,
  ) async {
    final fundName =
        (payload['fund_name'] as String?)?.trim().isNotEmpty == true
            ? payload['fund_name'] as String
            : 'Quỹ';
    payload.remove('fund_name');

    String cleanFundName(String rawName) {
      if (rawName.startsWith('[GOLD]')) {
        final sepIndex = rawName.indexOf('|');
        if (sepIndex != -1) {
          return rawName.substring(6, sepIndex);
        }
        return rawName.substring(6);
      }
      return rawName;
    }
    final cleanName = cleanFundName(fundName);

    final row = await _db
        .from('fund_contributions')
        .insert(payload)
        .select()
        .single();
    final contributionType =
        (payload['contribution_type'] as String?) ?? 'contribution';
    if (contributionType != 'withdrawal') {
      return row;
    }

    final note = payload['note'] as String?;
    bool recordAsIncome = true;
    if (note != null) {
      if (note.startsWith('[GOLD]')) {
        try {
          final decoded = jsonDecode(note.substring(6));
          if (decoded is Map) {
            final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
            if (incVal is bool) {
              recordAsIncome = incVal;
            }
          }
        } catch (_) {}
      } else if (note.startsWith('[WITHDRAWAL]')) {
        try {
          final decoded = jsonDecode(note.substring(12));
          if (decoded is Map) {
            final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
            if (incVal is bool) {
              recordAsIncome = incVal;
            }
          }
        } catch (_) {}
      }
    }

    if (!recordAsIncome) {
      return row;
    }

    final coupleId = payload['couple_id'] as String;
    final userId = payload['user_id'] as String;
    final walletId = payload['wallet_id'] as String;
    final amount = (payload['amount'] as num).toDouble();
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
              ? _cleanWithdrawalNote(note!, cleanName)
              : 'Rút quỹ: $cleanName',
          'is_from_transfer': false,
          'date': payload['date'] as String,
        })
        .select('id')
        .single();

    final linked = await _db
        .from('fund_contributions')
        .update({'linked_income_id': incomeRow['id'] as String})
        .eq('id', row['id'] as String)
        .select()
        .single();
    return linked;
  }

  Future<void> _refreshFundFromRemote(String fundId) async {
    final fund = await getFundById(fundId);
    final rows = await _db
        .from('fund_contributions')
        .select('amount, contribution_type, note')
        .eq('fund_id', fundId)
        .eq('is_deleted', false);

    double totalVnd = 0;
    double totalGold = 0;
    for (final row in rows) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final type = (row['contribution_type'] as String?) ?? 'contribution';
      final note = row['note'] as String?;

      double goldQty = 0;
      if (note != null && note.startsWith('[GOLD]')) {
        try {
          final decoded = jsonDecode(note.substring(6));
          if (decoded is Map) {
            final qtyVal = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'];
            if (qtyVal is num) {
              goldQty = qtyVal.toDouble();
            }
          }
        } catch (_) {}
      }

      if (type == 'contribution') {
        totalVnd += amount;
        totalGold += goldQty;
      } else if (type == 'withdrawal') {
        totalVnd -= amount;
        totalGold -= goldQty;
      }
    }

    if (fund.isGold) {
      final nextMeta = Map<String, dynamic>.from(fund.goldMetadata ?? {});
      nextMeta['total_gold_quantity'] = totalGold < 0 ? 0.0 : totalGold;
      final dbName = '[GOLD]${fund.cleanName}|${jsonEncode(nextMeta)}';

      await _db
          .from('funds')
          .update({
            'name': dbName,
            'current_amount': totalVnd < 0 ? 0.0 : totalVnd,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', fundId);
    } else {
      await _db
          .from('funds')
          .update({
            'current_amount': totalVnd < 0 ? 0.0 : totalVnd,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', fundId);
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
        try {
          final showInIncomeForm =
              (existing.first['show_in_income_form'] as bool?) ?? true;
          if (showInIncomeForm) {
            await _db
                .from('income_sources')
                .update({'show_in_income_form': false})
                .eq('id', id);
          }
        } catch (_) {}
        return id;
      }
    } catch (_) {}

    final payload = <String, dynamic>{
      'couple_id': coupleId,
      'name': _fundWithdrawIncomeSourceName,
      'icon': 'savings',
      'type': 'other',
    };

    try {
      final created = await _db
          .from('income_sources')
          .insert({
            ...payload,
            'show_in_income_form': false,
          })
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        final raceExisting = await _db
            .from('income_sources')
            .select('id')
            .eq('couple_id', coupleId)
            .eq('name', _fundWithdrawIncomeSourceName)
            .eq('is_deleted', false)
            .limit(1);
        if (raceExisting.isNotEmpty) {
          return raceExisting.first['id'] as String;
        }
      }
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
          .insert(payload)
          .select('id')
          .single();
      return created['id'] as String;
    }
  }

  String _cleanWithdrawalNote(String rawNote, String fundName) {
    if (rawNote.startsWith('[GOLD]')) {
      try {
        final decoded = jsonDecode(rawNote.substring(6));
        if (decoded is Map) {
          final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
          final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
          String res = 'Rút $qty chỉ vàng';
          if (userNote != null && userNote.trim().isNotEmpty) {
            res += ' (${userNote.trim()})';
          }
          return res;
        }
      } catch (_) {}
      return rawNote;
    } else if (rawNote.startsWith('[WITHDRAWAL]')) {
      try {
        final decoded = jsonDecode(rawNote.substring(12));
        if (decoded is Map) {
          final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
          if (userNote != null && userNote.trim().isNotEmpty) {
            return userNote.trim();
          }
        }
        return 'Rút quỹ: $fundName';
      } catch (_) {}
      return rawNote;
    }
    return rawNote;
  }
}
