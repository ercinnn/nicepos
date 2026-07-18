import 'package:flutter/material.dart';

/// Liste Gir'de kullanıcının dikdörtgenle işaretleyebileceği 4 sabit sütun
/// tipi. Renkler kullanıcı isteğiyle birebir: kırmızı=barkod, sarı=ürün adı,
/// mavi=adet, yeşil=alış fiyatı — design-tokens paletiyle eşleşmez, bilinçli
/// olarak literal renk (kullanıcının kendi rengi).
enum ColumnType {
  barcode('Barkod', Color(0xFFE53935)),
  name('Ürün Adı', Color(0xFFFDD835)),
  quantity('Adet', Color(0xFF1E88E5)),
  purchasePrice('Alış Fiyatı', Color(0xFF43A047));

  final String label;
  final Color color;

  const ColumnType(this.label, this.color);
}
