import 'dart:convert';
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
  final Map<String, dynamic>? goldMetadata;

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
    this.goldMetadata,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final String rawName = json['name'] as String;
    String name = rawName;
    String type = json['type'] as String;
    Map<String, dynamic>? goldMetadata;

    if (rawName.startsWith('[GOLD]')) {
      final sepIndex = rawName.indexOf('|');
      if (sepIndex != -1) {
        name = rawName.substring(6, sepIndex);
        final metaStr = rawName.substring(sepIndex + 1);
        try {
          goldMetadata = jsonDecode(metaStr) as Map<String, dynamic>;
          type = 'gold';
        } catch (_) {}
      } else {
        name = rawName.substring(6);
        type = 'gold';
      }
    }

    return WalletModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: name,
      type: type,
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
      goldMetadata: goldMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    String dbName = name;
    String dbType = type;
    if (type == 'gold') {
      dbType = 'other';
      dbName = '[GOLD]$name|${jsonEncode(goldMetadata ?? {})}';
    }
    return {
      'id': id,
      'couple_id': coupleId,
      'name': dbName,
      'type': dbType,
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

  WalletModel copyWith({
    String? id,
    String? coupleId,
    String? name,
    String? type,
    double? balance,
    String? currency,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isDeleted,
    DateTime? deletedAt,
    Map<String, dynamic>? goldMetadata,
  }) {
    return WalletModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      goldMetadata: goldMetadata ?? this.goldMetadata,
    );
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
    goldMetadata,
  ];
}
