import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/store_product.dart';
import '../../state/cart_provider.dart';
import '../../widgets/store_app_bar.dart';

final _productByIdProvider = FutureProvider.family<StoreProduct?, String>((ref, id) async {
  return ref.watch(storeRepositoryProvider).fetchProductById(id);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productByIdProvider(widget.productId));

    return Scaffold(
      appBar: const StoreAppBar(),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ürün yüklenemedi: $e')),
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Ürün bulunamadı veya online satışta değil.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
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
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: StoreColors.textMuted,
                                ),
                              )
                            : const Icon(Icons.image_not_supported_outlined, size: 48, color: StoreColors.textMuted),
                      ),
                    );
                    final info = _ProductInfo(
                      product: product,
                      quantity: _quantity,
                      onQuantityChanged: (q) => setState(() => _quantity = q),
                      onAddToCart: () {
                        ref.read(cartProvider.notifier).add(product, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product.name} sepete eklendi (x$_quantity)')),
                        );
                        context.go('/sepet');
                      },
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
                        Expanded(child: image),
                        const SizedBox(width: 32),
                        Expanded(child: info),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final StoreProduct product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;

  const _ProductInfo({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: StoreColors.textPrimary)),
        const SizedBox(height: 8),
        if (!product.inStock)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Şu an stokta yok', style: TextStyle(color: StoreColors.danger, fontWeight: FontWeight.w600)),
          ),
        Text(formatCurrency(product.price), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StoreColors.navy)),
        const SizedBox(height: 4),
        Text('KDV dahil, %${product.vatRate.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: StoreColors.textMuted)),
        if (product.description != null && product.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(product.description!, style: const TextStyle(fontSize: 14, color: StoreColors.textPrimary, height: 1.5)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            _QuantityStepper(quantity: quantity, onChanged: onQuantityChanged),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: product.inStock ? onAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Sepete Ekle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: StoreColors.border), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(width: 28, child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
