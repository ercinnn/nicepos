import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/concept_product.dart';
import '../data/repositories/concept_repository.dart';

part 'concept_products_provider.g.dart';

@Riverpod(keepAlive: true)
ConceptRepository conceptRepository(ConceptRepositoryRef ref) => ConceptRepository();

/// Konsept Ürünler sekmesinin listesi — her açılışta taze (autoDispose).
@riverpod
Future<List<ConceptProduct>> conceptProducts(ConceptProductsRef ref) =>
    ref.watch(conceptRepositoryProvider).fetchAll();
