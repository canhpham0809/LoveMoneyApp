import 'package:equatable/equatable.dart';

class WalletModel extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const WalletModel({
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

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
      isDefault: json['is_default'] as bool,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'is_default': isDefault,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

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
