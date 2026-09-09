import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gorev_item.dart';

class GorevlerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Dünün (bugünden bir önceki takvim günü) satılan ürünlerini, ürün
  /// başına toplam satış adediyle döner — en çok satılan üstte (`ReportRepository
  /// .fetchBestSellers` ile aynı sayfalı çekim + Dart-taraflı aggregation deseni).
  Future<List<GorevItem>> fetchYesterdaySoldProducts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from('sale_items')
          .select('quantity, product_id, sales!inner(sale_date), products(name, barcode)')
          .gte('sales.sale_date', yesterday.toUtc().toIso8601String())
          .lt('sales.sale_date', today.toUtc().toIso8601String())
          .order('product_id')
          .range(from, from + pageSize - 1);
      final list = (page as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      rows.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }

    final agg = <String, _GorevAgg>{};
    for (final row in rows) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;

      final rawProduct = row['products'];
      final product = rawProduct is Map
          ? Map<String, dynamic>.from(rawProduct)
          : rawProduct is List && rawProduct.isNotEmpty
              ? Map<String, dynamic>.from(rawProduct.first as Map)
              : null;
      if (product == null) continue; // silinmiş ürün → atla

      final quantity = (row['quantity'] as num?) ?? 0;
      final existing = agg[productId];
      if (existing == null) {
        agg[productId] = _GorevAgg(
          name: (product['name'] as String?) ?? '-',
          barcode: product['barcode'] as String?,
          quantity: quantity,
        );
      } else {
        existing.quantity += quantity;
      }
    }

    final items = agg.entries
        .map((e) => GorevItem(
              productId: e.key,
              name: e.value.name,
              barcode: e.value.barcode,
              quantity: e.value.quantity,
            ))
        .toList();
    items.sort((a, b) => b.quantity.compareTo(a.quantity));
    return items;
  }

  /// [tarih] (`YYYY-MM-DD`) gününe ait tamamlanma kayıtlarını product_id →
  /// tamamlanma zamanı eşlemesiyle döner (`gorev_tamamlamalar`, cihazlar
  /// arası paylaşılır — bkz. `0035_gorev_tamamlamalar.sql`).
  Future<Map<String, DateTime>> fetchCompletions(String tarih) async {
    final rows = await _client
        .from('gorev_tamamlamalar')
        .select('product_id, completed_at')
        .eq('gorev_tarihi', tarih);
    final map = <String, DateTime>{};
    for (final row in (rows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final productId = m['product_id'] as String?;
      if (productId == null) continue;
      map[productId] = DateTime.parse(m['completed_at'] as String).toLocal();
    }
    return map;
  }

  /// [productId]'yi [tarih] günü için tamamlandı işaretler. `upsert` +
  /// `(product_id, gorev_tarihi)` unique kısıtı → aynı satırın iki kez
  /// tıklanması (çift dokunma/ağ tekrarı) hata vermez, no-op olur.
  Future<void> completeTask(String productId, String tarih) async {
    await _client.from('gorev_tamamlamalar').upsert(
      {'product_id': productId, 'gorev_tarihi': tarih},
      onConflict: 'product_id,gorev_tarihi',
    );
  }

  /// [productId]'nin [tarih] günkü tamamlanma kaydını siler (geri al).
  Future<void> uncompleteTask(String productId, String tarih) async {
    await _client
        .from('gorev_tamamlamalar')
        .delete()
        .eq('product_id', productId)
        .eq('gorev_tarihi', tarih);
  }
}

class _GorevAgg {
  final String name;
  final String? barcode;
  num quantity;

  _GorevAgg({required this.name, required this.barcode, required this.quantity});
}
