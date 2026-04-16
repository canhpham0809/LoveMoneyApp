import 'package:equatable/equatable.dart';

class DebtEntity extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String debtTypeId;
  final String name;
  final double originalAmount;
  final double remainingAmount;
  final String creditorName;
  final DateTime startDate;
  final DateTime? dueDate;
  final int? reminderDaysBefore;
  final String? note;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const DebtEntity({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.debtTypeId,
    required this.name,
    required this.originalAmount,
    required this.remainingAmount,
    required this.creditorName,
    required this.startDate,
    this.dueDate,
    this.reminderDaysBefore,
    this.note,
    required this.isClosed,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  @override
  List<Object?> get props => [
    id,
    coupleId,
    userId,
    debtTypeId,
    name,
    originalAmount,
    remainingAmount,
    creditorName,
    startDate,
    dueDate,
    reminderDaysBefore,
    note,
    isClosed,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
