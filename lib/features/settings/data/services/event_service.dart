import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_demo/features/settings/data/models/event_model.dart';

class EventService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<EventModel>> getEvents(String coupleId) async {
    final rows = await _db
        .from('events')
        .select()
        .eq('couple_id', coupleId)
        .order('start_date', ascending: false);
    return rows.map((r) => EventModel.fromJson(r)).toList();
  }

  Future<EventModel> createEvent({
    required String coupleId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
  }) async {
    final row = await _db
        .from('events')
        .insert({
          'couple_id': coupleId,
          'name': name,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_active': isActive,
        })
        .select()
        .single();
    return EventModel.fromJson(row);
  }

  Future<EventModel> updateEvent({
    required String eventId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
  }) async {
    final row = await _db
        .from('events')
        .update({
          'name': name,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
          'is_active': isActive,
        })
        .eq('id', eventId)
        .select()
        .single();
    return EventModel.fromJson(row);
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.from('events').delete().eq('id', eventId);
  }
}
