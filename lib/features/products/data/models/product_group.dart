class ProductGroup {
  final String id;
  final String name;
  final String? parentGroupId;
  final String? parentGroupName;
  final bool showOnSalesPage;
  final bool showOnPriceList;
  final int productCount;

  const ProductGroup({
    required this.id,
    required this.name,
    this.parentGroupId,
    this.parentGroupName,
    this.showOnSalesPage = false,
    this.showOnPriceList = false,
    this.productCount = 0,
  });

  factory ProductGroup.fromMap(Map<String, dynamic> map) {
    return ProductGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      parentGroupId: map['parent_group_id'] as String?,
      parentGroupName: map['parent_group_name'] as String?,
      showOnSalesPage: map['show_on_sales_page'] as bool? ?? false,
      showOnPriceList: map['show_on_price_list'] as bool? ?? false,
      productCount: (map['product_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'parent_group_id': parentGroupId,
      'show_on_sales_page': showOnSalesPage,
      'show_on_price_list': showOnPriceList,
    };
  }
}
