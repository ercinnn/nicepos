class Company {
  final String id;
  final String name;
  final DateTime? createdAt;

  const Company({
    required this.id,
    required this.name,
    this.createdAt,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
    };
  }
}
