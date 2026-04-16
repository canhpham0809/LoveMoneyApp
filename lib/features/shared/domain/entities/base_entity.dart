class BaseEntity {
  const BaseEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
}
