class StoreCategory {
  final String id;
  final String name;
  final String? parentGroupId;

  const StoreCategory({
    required this.id,
    required this.name,
    this.parentGroupId,
  });

  factory StoreCategory.fromMap(Map<String, dynamic> map) {
    return StoreCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      parentGroupId: map['parent_group_id'] as String?,
    );
  }
}
