import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../products/data/models/product.dart';
import '../../products/data/repositories/product_repository.dart';
import '../../products/application/products_provider.dart';

part 'barcode_cache.g.dart';

/// Barkod → Product bellek içi indeksi. Satış ekranı açılırken bir kez tüm
/// ürünler çekilip barkoda göre indekslenir; barkod okutulunca ağ turu beklemeden
/// anında sepete ekleme yapılabilir.
///
/// `keepAlive` bir provider'da tutulur → her satış ekranı açılışında yeniden
/// çekilmez. Fiyat/stok tazeliği: sepete eklenen değer ekleme anındaki cache
/// değeridir (POS için kabul edilebilir). Cache miss'te ağ fallback'i devreye
/// girer ve bulunan ürün cache'e yazılır (yeni/bilinmeyen barkod da çalışır).
class BarcodeCache {
  BarcodeCache(this._repo);

  final ProductRepository _repo;
  final Map<String, Product> _byBarcode = {};
  bool _loaded = false;
  Future<void>? _loading;

  /// Ürünleri bir kez prefetch eder ve barkod indeksini kurar. Tekrarlı
  /// çağrılarda tek bir yükleme paylaşılır; yükleme bitince tekrar tetiklenmez.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final products = await _repo.fetchAll();
      for (final p in products) {
        put(p);
      }
      _loaded = true;
    } catch (_) {
      // Yükleme başarısızsa sessizce geç — barkod yolu ağ fallback'ine düşer.
    } finally {
      _loading = null;
    }
  }

  /// Cache hit ise ürünü döndürür; miss ise null (çağıran ağ fallback'i yapar).
  Product? lookup(String barcode) {
    final key = barcode.trim();
    if (key.isEmpty) return null;
    return _byBarcode[key];
  }

  /// Yeni okunan/bulunan ürünü cache'e ekler (fallback'te bulunanlar dahil).
  void put(Product product) {
    final b = product.barcode;
    if (b != null && b.trim().isNotEmpty) {
      _byBarcode[b.trim()] = product;
    }
  }
}

@Riverpod(keepAlive: true)
BarcodeCache barcodeCache(BarcodeCacheRef ref) =>
    BarcodeCache(ref.watch(productRepositoryProvider));
