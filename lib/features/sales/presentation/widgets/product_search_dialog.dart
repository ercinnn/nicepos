import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../features/products/data/models/product.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../application/sales_cart_notifier.dart';

/// Ürün adı / barkod / stok kodu ile arayıp sepete ekler.
class ProductSearchDialog extends ConsumerStatefulWidget {
  final String initialQuery;

  const ProductSearchDialog({super.key, this.initialQuery = ''});

  @override
  ConsumerState<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends ConsumerState<ProductSearchDialog> {
  late TextEditingController _controller;
  List<Product> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await ref.read(productRepositoryProvider).fetchAll(query: query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ürün Ara'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ürün adı, barkod, stok kodu...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Ürün bulunamadı.'))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = _results[index];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text('${p.barcode ?? '-'} · Stok: ${p.stockQuantity}'),
                              trailing: Text(formatCurrency(p.price1)),
                              onTap: () {
                                ref.read(salesCartProvider.notifier).addProduct(p);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }
}
