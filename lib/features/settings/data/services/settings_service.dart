import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, dynamic>> createCouple({
    required String name,
    String currency = 'VND',
    String language = 'vi',
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Không có phiên đăng nhập hợp lệ.');
    }

    await _db.from('couples').insert({
      'name': name,
      'currency': currency,
      'language': language,
    });

    final membership = await _db
        .from('couple_members')
        .select('couple_id')
        .eq('user_id', uid)
        .eq('is_deleted', false)
        .order('joined_at', ascending: false)
        .limit(1)
        .single();

    final coupleId = membership['couple_id'] as String;
    return getCoupleSettings(coupleId);
  }

  Future<Map<String, dynamic>> getCoupleSettings(String coupleId) async {
    final row = await _db
        .from('couples')
        .select(
          'id, name, currency, language, monthly_budget_amount, invite_code',
        )
        .eq('id', coupleId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateCoupleSettings(
    String coupleId,
    Map<String, dynamic> data,
  ) async {
    final row = await _db
        .from('couples')
        .update(data)
        .eq('id', coupleId)
        .select(
          'id, name, currency, language, monthly_budget_amount, invite_code',
        )
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<String> joinCoupleByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Mã couple không được để trống.');
    }

    final result = await _db.rpc(
      'join_couple_by_code',
      params: {'p_code': normalized},
    );
    return result as String;
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return {};
    final row = await _db
        .from('users')
        .select('id, email, display_name, avatar_url')
        .eq('id', uid)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String displayName,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Không có phiên đăng nhập hợp lệ.');
    }
    final row = await _db
        .from('users')
        .update({'display_name': displayName.trim()})
        .eq('id', uid)
        .select('id, email, display_name, avatar_url')
        .single();
    return Map<String, dynamic>.from(row);
  }
}
