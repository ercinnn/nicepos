import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../products/application/concept_products_provider.dart';
import '../../products/data/models/concept_product.dart';
import '../../products/data/repositories/concept_repository.dart';

part 'concept_cache.g.dart';

/// Konsept barkodu → ConceptProduct bellek indeksi (`BarcodeCache` ile aynı
/// desen). Satış ekranı açılırken bir kez tüm konseptler (parçaları gömülü)
/// çekilir; okutmada ağ beklenmez ve bağlantı sonradan koparsa (dead-zone)
/// daha önce yüklenmiş konseptler çalışmaya devam eder. Miss'te çağıran ağ
/// fallback'i yapıp `put` ile ekler. Konsept kaydedilince/silinince
/// `ref.invalidate(conceptCacheProvider)` ile tazelenir.
class ConceptCache {
  ConceptCache(this._repo);

  final ConceptRepository _repo;
  final Map<String, ConceptProduct> _byBarcode = {};
  bool _loaded = false;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      for (final c in await _repo.fetchAll()) {
        put(c);
      }
      _loaded = true;
    } catch (_) {
      // Ağ yok — her okutma kendi ağ fallback'ine düşer; bir sonraki
      // ensureLoaded tekrar dener (_loaded false kalır).
    } finally {
      _loading = null;
    }
  }

  ConceptProduct? lookup(String barcode) => _byBarcode[barcode.trim().toUpperCase()];

  /// Ad veya barkodda geçen konseptler (Türkçe büyük/küçük harf duyarsız) —
  /// etiket ekranındaki adla canlı aramaya konseptleri de katmak için.
  List<ConceptProduct> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _byBarcode.values
        .where((c) => c.name.toLowerCase().contains(q) || c.barcode.toLowerCase().contains(q))
        .toList();
  }

    void put(ConceptProduct concept) {
    _byBarcode[concept.barcode.trim().toUpperCase()] = concept;
  }
}

@Riverpod(keepAlive: true)
ConceptCache conceptCache(ConceptCacheRef ref) =>
    ConceptCache(ref.watch(conceptRepositoryProvider));
