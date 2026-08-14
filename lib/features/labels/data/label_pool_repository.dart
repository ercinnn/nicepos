import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/label_pool_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Etiket Havuzu — `label_pool_items` tablosu (bkz. 0032_label_pool.sql).
// ProductRepository/LabelsStorageRepository ile aynı desen: Supabase.instance
// .client doğrudan, ORM yok.
// ═══════════════════════════════════════════════════════════════════════════

class LabelPoolRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Havuza yeni bir kalem ekler (mobil ürün formundaki "Etiket" diyaloğu).
  Future<void> add({
    required String labelType,
    required String barcode,
    required String productName,
    num? price,
    required int quantity,
  }) async {
    await _client.from('label_pool_items').insert({
      'label_type': labelType,
      'barcode': barcode,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
    });
  }

  /// [labelType] için henüz PDF'e alınmamış (kontrol=0) kalemleri, eklenme
  /// sırasıyla döner — Havuz sekmesindeki sayaç + "PDF Kaydet" bunu kullanır.
  Future<List<LabelPoolItem>> fetchPending(String labelType) async {
    final rows = await _client
        .from('label_pool_items')
        .select()
        .eq('label_type', labelType)
        .eq('kontrol', 0)
        .order('created_at');
    return (rows as List)
        .map((row) => LabelPoolItem.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// [ids] kalemlerini kontrol=1 işaretler ("PDF Kaydet" başarıyla bittikten
  /// sonra çağrılır) — satırlar SİLİNMEZ, geçmiş kayıt olarak kalır.
  Future<void> markPrinted(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('label_pool_items').update({'kontrol': 1}).inFilter('id', ids);
  }
}
