import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/store_product.dart';
import '../../state/cart_provider.dart';
import '../../state/catalog_provider.dart';
import '../../state/tenant_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/store_app_bar.dart';
import '../../widgets/store_breadcrumb.dart';

final _productByIdProvider = FutureProvider.family<StoreProduct?, String>((
  ref,
  id,
) async {
  final tenantId = ref.watch(currentTenantProvider).id;
  return ref
      .watch(storeRepositoryProvider)
      .fetchProductById(id, tenantId: tenantId);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  bool _justAdded = false;

  // İlgili ürünler (§ "İlgili Ürünler") — mevcut ürün id'sine göre yalnız
  // bir kez alınır ve önbelleklenir (FutureBuilder her setState'te yeniden
  // sorgu atmasın diye). Yeni bir Riverpod provider EKLENMEZ (state/**
  // kapsam dışı) — mantık ekran içinde tutulur.
  String? _relatedForProductId;
  Future<List<StoreProduct>>? _relatedFuture;

  Future<List<StoreProduct>> _relatedProducts(StoreProduct product) {
    if (_relatedForProductId == product.id && _relatedFuture != null) {
      return _relatedFuture!;
    }
    _relatedForProductId = product.id;
    final tenantId = ref.read(currentTenantProvider).id;
    _relatedFuture = ref
        .read(storeRepositoryProvider)
        .fetchProducts(tenantId: tenantId, groupId: product.groupId)
        .then((list) => list.where((p) => p.id != product.id).toList());
    return _relatedFuture!;
  }

  void _handleAddToCart(StoreProduct product) {
    ref.read(cartProvider.notifier).add(product, quantity: _quantity);
    setState(() => _justAdded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} sepete eklendi (x$_quantity)'),
        action: SnackBarAction(
          label: 'Sepete Git',
          onPressed: () => context.go('/sepet'),
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _justAdded = false);
    });
  }

  void _openZoom(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productByIdProvider(widget.productId));

    return Scaffold(
      appBar: const StoreAppBar(),
      body: productAsync.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => Center(child: Text('Ürün yüklenemedi: $e')),
        data: (product) {
          if (product == null) {
            return const Center(
              child: Text('Ürün bulunamadı veya online satışta değil.'),
            );
          }
          final categoriesAsync = ref.watch(categoriesProvider);
          final categoryName = categoriesAsync.maybeWhen(
            data: (categories) {
              if (product.groupId == null) return null;
              for (final category in categories) {
                if (category.id == product.groupId) return category.name;
              }
              return null;
            },
            orElse: () => null,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StoreBreadcrumb(
                      segments: [
                        BreadcrumbSegment(
                          label: 'Anasayfa',
                          onTap: () => context.go('/'),
                        ),
                        if (categoryName != null)
                          BreadcrumbSegment(
                            label: categoryName,
                            onTap: () {
                              ref.read(catalogFilterProvider.notifier).state =
                                  const CatalogFilter().copyWith(
                                    groupId: product.groupId,
                                  );
                              context.go('/');
                            },
                          ),
                        BreadcrumbSegment(label: product.name),
                      ],
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 640;
                        final image = AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: StoreColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: product.imageUrl != null
                                ? GestureDetector(
                                    onTap: () => _openZoom(product.imageUrl!),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: CachedNetworkImage(
                                        imageUrl: product.imageUrl!,
                                        fit: BoxFit.cover,
                                        fadeInDuration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        placeholder: (context, url) =>
                                            const SkeletonImage(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.image_not_supported_outlined,
                                              size: 48,
                                              color: StoreColors.textMuted,
                                            ),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                    color: StoreColors.textMuted,
                                  ),
                          ),
                        );
                        final info = _ProductInfo(
                          product: product,
                          quantity: _quantity,
                          justAdded: _justAdded,
                          onQuantityChanged: (q) =>
                              setState(() => _quantity = q),
                          onAddToCart: () => _handleAddToCart(product),
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              image,
                              const SizedBox(height: 20),
                              info,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: image),
                            const SizedBox(width: 32),
                            Expanded(child: info),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32), // space.xxxl
                    _RelatedProductsSection(
                      future: product.groupId == null
                          ? null
                          : _relatedProducts(product),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Ürün verisi sunucudan gelirken tam sayfa boyutunu taklit eden skeleton —
// bare CircularProgressIndicator yerine (design-tokens.md §5).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              const image = SkeletonImage(aspectRatio: 1);
              final info = StoreShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 22, width: 240),
                    SizedBox(height: 12),
                    SkeletonBox(height: 26, width: 120),
                    SizedBox(height: 24),
                    SkeletonBox(height: 48),
                  ],
                ),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 20), info],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: image),
                  const SizedBox(width: 32),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Aynı kategorideki diğer ürünler — mevcut ürünü hariç tutar. Kategori yoksa
// (product.groupId == null) bölüm hiç gösterilmez.
class _RelatedProductsSection extends ConsumerWidget {
  final Future<List<StoreProduct>>? future;

  const _RelatedProductsSection({required this.future});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<StoreProduct>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _RelatedShell(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  const SizedBox(width: 180, child: SkeletonProductCard()),
            ),
          );
        }
        final related = snapshot.data ?? const [];
        if (related.isEmpty) return const SizedBox.shrink();
        return _RelatedShell(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = related[i];
              return SizedBox(
                width: 180,
                child: ProductCard(
                  product: item,
                  onAddToCart: () {
                    ref.read(cartProvider.notifier).add(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.name} sepete eklendi'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RelatedShell extends StatelessWidget {
  final Widget child;

  const _RelatedShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İlgili Ürünler',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            color: StoreColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12), // space.md
        SizedBox(height: 250, child: child),
      ],
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final StoreProduct product;
  final int quantity;
  final bool justAdded;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;

  const _ProductInfo({
    required this.product,
    required this.quantity,
    required this.justAdded,
    required this.onQuantityChanged,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: StoreColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (!product.inStock)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Şu an stokta yok',
              style: TextStyle(
                color: StoreColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Text(
          formatCurrency(product.price),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: StoreColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'KDV dahil, %${product.vatRate.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, color: StoreColors.textMuted),
        ),
        if (product.description != null &&
            product.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            product.description!,
            style: const TextStyle(
              fontSize: 14,
              color: StoreColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            _QuantityStepper(
              quantity: quantity,
              onChanged: onQuantityChanged,
              enabled: product.inStock,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: product.inStock ? onAddToCart : null,
                icon: Icon(
                  justAdded ? Icons.check : Icons.add_shopping_cart_outlined,
                ),
                label: Text(justAdded ? 'Sepete Eklendi' : 'Sepete Ekle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Stok-farkında adım sayacı — yalnız mevcut boolean `inStock` alanına göre
// (sayısal stok modelde yok). Tükendiyse her iki buton da devre dışı.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled
              ? StoreColors.border
              : StoreColors.border.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: enabled && quantity > 1
                ? () => onChanged(quantity - 1)
                : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? StoreColors.textPrimary : StoreColors.textMuted,
              ),
            ),
          ),
          IconButton(
            onPressed: enabled ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
