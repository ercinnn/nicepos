class StoreTenant {
  final String id;
  final String name;
  final String slug;

  // 'square' (1:1) veya 'portrait' (3:4, varsayılan) — kiracının Online
  // Satış panelinden seçtiği ürün görseli formatı (bkz. 0046 migration).
  final String imageAspect;

  const StoreTenant({
    required this.id,
    required this.name,
    required this.slug,
    this.imageAspect = 'portrait',
  });

  double get imageAspectRatio => imageAspect == 'square' ? 1 : 3 / 4;

  factory StoreTenant.fromMap(Map<String, dynamic> map) {
    return StoreTenant(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      imageAspect: map['storefront_image_aspect'] as String? ?? 'portrait',
    );
  }
}
