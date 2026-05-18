import 'package:equatable/equatable.dart';

class EventModel extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'name': name,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// An event is considered active on the UI if:
  /// - `isActive` is true in the database, AND
  /// - The current date is between `startDate` and `endDate` (inclusive).
  bool isCurrentlyActive(DateTime today) {
    if (!isActive) return false;
    final dateOnly = DateTime(today.year, today.month, today.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return dateOnly.compareTo(start) >= 0 && dateOnly.compareTo(end) <= 0;
  }

  @override
  List<Object?> get props => [
        id,
        coupleId,
        name,
        startDate,
        endDate,
        isActive,
        createdAt,
        updatedAt,
      ];
}
