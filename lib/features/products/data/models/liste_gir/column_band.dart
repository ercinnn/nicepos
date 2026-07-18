import 'column_type.dart';

/// Kullanıcının çizdiği bir sütun bandı — yalnız X-aralığı taşır (yükseklik
/// her zaman tam sayfa boyu, KARAR: sütun başına tek dikdörtgen).
class ColumnBand {
  final ColumnType type;
  double left;
  double right;

  ColumnBand({required this.type, required this.left, required this.right});

  double get lo => left <= right ? left : right;
  double get hi => left <= right ? right : left;

  bool contains(double x) => x >= lo && x <= hi;
}
