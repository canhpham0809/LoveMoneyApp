import 'package:equatable/equatable.dart';

class WalletEntity extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String type; // cash, bank, ewallet, other
  final double balance;
  final String currency;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const WalletEntity({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    required this.isDefault,
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
    type,
    balance,
    currency,
    isDefault,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
