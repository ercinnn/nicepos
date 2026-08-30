class StoreTenant {
  final String id;
  final String name;
  final String slug;

  const StoreTenant({required this.id, required this.name, required this.slug});

  factory StoreTenant.fromMap(Map<String, dynamic> map) {
    return StoreTenant(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
    );
  }
}
