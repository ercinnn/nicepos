import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../products/data/local/product_local_cache_dao.dart';
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
  BarcodeCache(this._repo, this._localCacheDao);

  final ProductRepository _repo;
  final ProductLocalCacheDao _localCacheDao;
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
      // Eşlenik Barkod: gruplu ürünlerin stok/fiyatını TEK toplu sorguyla
      // (N+1 YOK) grup toplamına/en-son-satır fiyatına override et — hangi
      // barkod okutulursa okutulsun sepete grubun güncel değeriyle eklensin
      // (bkz. 0021_equivalent_barcodes.sql, ProductRepository.fetchByBarcode
      // ile AYNI mantık).
      final groupedIds = products
          .where((p) => p.equivalentGroupId != null)
          .map((p) => p.id)
          .toList();
      // `fetchEquivalentAggregates` boş listede zaten erken döner — ayrı bir
      // dallanmaya gerek yok.
      final aggregates = await _repo.fetchEquivalentAggregates(groupedIds);
      for (final p in products) {
        final agg = aggregates[p.id];
        if (agg != null) {
          put(p.copyWith(
            stockQuantity: agg.totalStock,
            price1: agg.groupPrice1,
            price2: agg.groupPrice2,
            purchasePrice: agg.groupPurchasePrice,
          ));
        } else {
          put(p);
        }
      }
      _loaded = true;
    } catch (_) {
      // Ağ başarısız — native'de yerel önbellekten (products_cache) diskten
      // doldur, soğuk açılış + dead-zone'da barkod taraması yine anında
      // çalışsın. Web'de (`!kIsWeb` guard) yalnız ağ fallback'ine düşer.
      if (!kIsWeb) {
        try {
          final cached = await _localCacheDao.searchCached();
          for (final p in cached) {
            put(p);
          }
        } catch (_) {
          // Yerel önbellek de okunamazsa sessizce geç — barkod yolu her
          // tarama başına ayrı ağ fallback'ine düşmeye devam eder.
        }
      }
      _loaded = true;
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
    BarcodeCache(ref.watch(productRepositoryProvider), ref.watch(productLocalCacheDaoProvider));
