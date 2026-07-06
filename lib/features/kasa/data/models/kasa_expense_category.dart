/// Kasa gider kategorisi. `kasa_expense_categories` tablosunun karşılığı.
/// ORM yoktur — `fromMap()` + `toInsertMap()` deseni kullanılır.
class KasaExpenseCategory {
  final String id;

  /// Kategori adı (ör. "Kira", "Elektrik"). DB'de benzersizdir.
  final String name;

  /// Pasif kategoriler listede gizlenir.
  final bool isActive;

  const KasaExpenseCategory({
    this.id = '',
    required this.name,
    this.isActive = true,
  });

  factory KasaExpenseCategory.fromMap(Map<String, dynamic> map) {
    return KasaExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'is_active': isActive,
    };
  }
}
