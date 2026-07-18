/// Ürünler tablosundaki sütun bazlı filtreler (masaüstü, sütun başlığındaki
/// filtre ikonlarından doldurulur). `null` alan = o sütun için filtre yok.
///
/// Bilinçli olarak mutable (bkz. Liste Gir'deki `ExtractedRow` deseniyle
/// aynı yaklaşım) — yalnız UI/sorgu durumu taşır, immutability gerekmez.
class ProductFilters {
  String? barcode;
  String? stockCode;
  String? unit;
  String? groupName;
  String? parentGroupName;
  num? stockMin;
  num? stockMax;
  num? criticalStockMin;
  num? criticalStockMax;
  num? vatMin;
  num? vatMax;
  num? purchaseMin;
  num? purchaseMax;
  num? price1Min;
  num? price1Max;
  num? price2Min;
  num? price2Max;

  /// null=Tümü, 'cok_satan' | 'tukendi' | 'pasif' | 'bos' (boş durum).
  String? status;

  ProductFilters();

  bool get isEmpty =>
      barcode == null &&
      stockCode == null &&
      unit == null &&
      groupName == null &&
      parentGroupName == null &&
      stockMin == null &&
      stockMax == null &&
      criticalStockMin == null &&
      criticalStockMax == null &&
      vatMin == null &&
      vatMax == null &&
      purchaseMin == null &&
      purchaseMax == null &&
      price1Min == null &&
      price1Max == null &&
      price2Min == null &&
      price2Max == null &&
      status == null;

  ProductFilters clone() => ProductFilters()
    ..barcode = barcode
    ..stockCode = stockCode
    ..unit = unit
    ..groupName = groupName
    ..parentGroupName = parentGroupName
    ..stockMin = stockMin
    ..stockMax = stockMax
    ..criticalStockMin = criticalStockMin
    ..criticalStockMax = criticalStockMax
    ..vatMin = vatMin
    ..vatMax = vatMax
    ..purchaseMin = purchaseMin
    ..purchaseMax = purchaseMax
    ..price1Min = price1Min
    ..price1Max = price1Max
    ..price2Min = price2Min
    ..price2Max = price2Max
    ..status = status;
}
