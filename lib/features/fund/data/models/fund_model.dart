import 'dart:convert';
import 'package:equatable/equatable.dart';

class FundModel extends Equatable {
  final String id;
  final String coupleId;
  final String? creatorUserId;
  final String name;
  final String? icon;
  final int sortOrder;
  final double? targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String? color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  // Gold specific fields
  final bool isGold;
  final String cleanName;
  final Map<String, dynamic>? goldMetadata;

  double get customGoldPrice {
    if (goldMetadata == null) return 15000000.0;
    return ((goldMetadata!['custom_gold_price'] ?? 15000000.0) as num).toDouble();
  }

  double get currentGoldQuantity {
    if (goldMetadata == null) return 0.0;
    return ((goldMetadata!['total_gold_quantity'] ?? 0.0) as num).toDouble();
  }

  const FundModel({
    required this.id,
    required this.coupleId,
    this.creatorUserId,
    required this.name,
    this.icon,
    required this.sortOrder,
    this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.color,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
    this.isGold = false,
    required this.cleanName,
    this.goldMetadata,
  });

  factory FundModel.fromJson(Map<String, dynamic> json) {
    final String rawName = json['name'] as String;
    String name = rawName;
    bool isGold = false;
    Map<String, dynamic>? goldMetadata;

    if (rawName.startsWith('[GOLD]')) {
      final sepIndex = rawName.indexOf('|');
      if (sepIndex != -1) {
        name = rawName.substring(6, sepIndex);
        final metaStr = rawName.substring(sepIndex + 1);
        try {
          goldMetadata = jsonDecode(metaStr) as Map<String, dynamic>;
          isGold = true;
        } catch (_) {}
      } else {
        name = rawName.substring(6);
        isGold = true;
      }
    }

    return FundModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      creatorUserId:
          json['creator_user_id'] as String? ??
          json['user_id'] as String? ??
          json['updated_by'] as String?,
      name: rawName,
      icon: json['icon'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      targetAmount: json['target_amount'] != null
          ? (json['target_amount'] as num).toDouble()
          : null,
      currentAmount: (json['current_amount'] as num).toDouble(),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      color: json['color'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      isGold: isGold,
      cleanName: name,
      goldMetadata: goldMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'creator_user_id': creatorUserId,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  FundModel copyWith({
    String? id,
    String? coupleId,
    String? creatorUserId,
    String? name,
    String? icon,
    int? sortOrder,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isDeleted,
    DateTime? deletedAt,
    bool? isGold,
    String? cleanName,
    Map<String, dynamic>? goldMetadata,
  }) {
    return FundModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      isGold: isGold ?? this.isGold,
      cleanName: cleanName ?? this.cleanName,
      goldMetadata: goldMetadata ?? this.goldMetadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    coupleId,
    creatorUserId,
    name,
    icon,
    sortOrder,
    targetAmount,
    currentAmount,
    deadline,
    color,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
    isGold,
    cleanName,
    goldMetadata,
  ];
}
