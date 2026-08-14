import 'label_slot.dart';

// Etiket Havuzu (Supabase `label_pool_items` tablosu, bkz. 0032_label_pool.sql)
// — birden fazla kullanıcının/cihazın (mobil ürün formundaki "Etiket" butonu)
// beslediği, Etiket sayfasındaki "Havuz" sekmesinin "PDF Kaydet" ile tükettiği
// paylaşılan kuyruk. Diğer etiket sekmelerinin (Raf/Tel/Geniş/Ürün) oturum-içi
// `keepAlive` state'inin AKSİNE bu DB'de kalıcıdır.

const String kLabelPoolTypeRaf = 'raf';
const String kLabelPoolTypeTel = 'tel';
const String kLabelPoolTypeGenis = 'genis';
const String kLabelPoolTypeUrun = 'urun';

/// Havuz'daki tek bir kalem (DB satırı). `price` yalnız fiyatlı türlerde
/// (Raf/Tel/Geniş) dolu — 'urun' (Ürün Etiketi, fiyatsız) için `null`.
/// `kontrol`: 0 = henüz PDF'e dönüşmedi (Havuz sayacına dahil), 1 = bir
/// "PDF Kaydet" turunda baskıya alındı (satır SİLİNMEZ, geçmiş kayıt kalır).
class LabelPoolItem {
  final String id;
  final String labelType;
  final String barcode;
  final String productName;
  final num? price;
  final int quantity;
  final int kontrol;
  final DateTime createdAt;

  const LabelPoolItem({
    required this.id,
    required this.labelType,
    required this.barcode,
    required this.productName,
    this.price,
    required this.quantity,
    required this.kontrol,
    required this.createdAt,
  });

  factory LabelPoolItem.fromMap(Map<String, dynamic> map) {
    return LabelPoolItem(
      id: map['id'] as String,
      labelType: map['label_type'] as String,
      barcode: map['barcode'] as String,
      productName: map['product_name'] as String,
      price: map['price'] as num?,
      quantity: map['quantity'] as int,
      kontrol: map['kontrol'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// [items] (Havuz'dan DB sırasıyla çekilmiş, kontrol=0 bekleyen kalemler)
/// adet kadar çoğaltıp [perPage] büyüklüğünde `LabelSlot` sayfalarına böler
/// (son sayfa null-pad) — Raf/Tel/Geniş Havuz PDF'i için ortak (fiyatlı
/// türler). `paginateProductLabels` (product_label_item.dart) ile BİREBİR
/// aynı flatten+chunk deseni, yalnız kaynak/hedef tipi farklı. Kalem yoksa
/// tek boş sayfa döner (önizleme/tutarlılık için).
List<List<LabelSlot?>> paginateLabelPoolItems(
  List<LabelPoolItem> items,
  int perPage,
) {
  final flat = <LabelSlot>[];
  for (final it in items) {
    for (var i = 0; i < it.quantity; i++) {
      flat.add(LabelSlot(
        barcode: it.barcode,
        productName: it.productName,
        price: it.price ?? 0,
        createdAt: it.createdAt,
      ));
    }
  }
  if (flat.isEmpty) {
    return [List<LabelSlot?>.filled(perPage, null)];
  }
  final pages = <List<LabelSlot?>>[];
  for (var start = 0; start < flat.length; start += perPage) {
    final page = List<LabelSlot?>.filled(perPage, null);
    for (var i = 0; i < perPage && start + i < flat.length; i++) {
      page[i] = flat[start + i];
    }
    pages.add(page);
  }
  return pages;
}
