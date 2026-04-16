import 'package:equatable/equatable.dart';

class IncomeSourceEntity extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String icon;
  final String
  type; // salary, investment, bonus, freelance, rental, gift, other
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const IncomeSourceEntity({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.icon,
    required this.type,
    required this.isActive,
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
    name,
    icon,
    type,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
