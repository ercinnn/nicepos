import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Online Satış kontrol paneli — hangi ürünlerin storefront'ta (Cloudflare
// Pages'teki ayrı Flutter web uygulaması, aynı Supabase projesi) göründüğünü
// yönetir. Ürün-DB ilişkisi products.is_online_active — ürün formundaki
// "Online Aç" anahtarıyla AYNI alan; bu ekran toplu/hızlı yönetim sağlar.
// ═══════════════════════════════════════════════════════════════════════════
class OnlineSatisScreen extends ConsumerStatefulWidget {
  const OnlineSatisScreen({super.key});

  @override
  ConsumerState<OnlineSatisScreen> createState() => _OnlineSatisScreenState();
}

class _OnlineSatisScreenState extends ConsumerState<OnlineSatisScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToOnline(Product product) async {
    if (product.isOnlineActive) return;
    await ref.read(productRepositoryProvider).setOnlineActive(product.id, true);
    ref.invalidate(onlineActiveProductsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} online satışa eklendi')),
      );
    }
  }

  Future<void> _removeFromOnline(Product product) async {
    await ref.read(productRepositoryProvider).setOnlineActive(product.id, false);
    ref.invalidate(onlineActiveProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final onlineProductsAsync = ref.watch(onlineActiveProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Online Satış',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ürün ara ve online mağazaya (storefront) ekle. Aynı işlem Ürünler '
          'sayfasındaki ürün detayından "Online Aç" anahtarıyla da yapılabilir.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _OnlineProductSearchField(
          controller: _searchController,
          onProductSelected: _addToOnline,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'Online Mağazadaki Ürünler',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            onlineProductsAsync.maybeWhen(
              data: (list) => Text('(${list.length})', style: const TextStyle(color: AppColors.textMuted)),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: onlineProductsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (products) {
              if (products.isEmpty) {
                return const Center(
                  child: Text('Henüz online satışa açılmış ürün yok', style: TextStyle(color: AppColors.textMuted)),
                );
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) => _OnlineProductCard(
                  product: products[i],
                  onRemove: () => _removeFromOnline(products[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OnlineProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onRemove;

  const _OnlineProductCard({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: product.imageUrl != null
                      ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const _ImagePlaceholder())
                      : const _ImagePlaceholder(),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      tooltip: 'Online satıştan kaldır',
                      onPressed: onRemove,
                      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(product.price1),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageBg,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 28),
    );
  }
}

// ---------------------------------------------------------------------------
// Canlı ürün arama — sales_screen.dart'taki _LiveProductSearchField'ın
// sadeleştirilmiş hali (barkod-okutup-sepete-ekle semantiği YOK, yalnız
// yazarak arayıp seçme). Ayrı dosyada tutulur — sales_screen.dart'a dokunmadan.
// ---------------------------------------------------------------------------
class _OnlineProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final void Function(Product) onProductSelected;

  const _OnlineProductSearchField({required this.controller, required this.onProductSelected});

  @override
  ConsumerState<_OnlineProductSearchField> createState() => _OnlineProductSearchFieldState();
}

class _OnlineProductSearchFieldState extends ConsumerState<_OnlineProductSearchField> {
  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  Timer? _debounce;
  List<Product> _results = [];
  bool _loading = false;
  double _fieldWidth = 320;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _portal.hide();
  }

  void _onChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _results = []);
      _portal.hide();
      return;
    }
    final token = ++_queryToken;
    setState(() => _loading = true);
    if (!_portal.isShowing) _portal.show();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      List<Product> results;
      try {
        results = await ref.read(productRepositoryProvider).fetchAll(query: query);
      } catch (_) {
        results = const [];
      }
      if (!mounted || token != _queryToken) return;
      if (widget.controller.text.trim() != query) return;
      setState(() {
        _results = results.take(30).toList();
        _loading = false;
      });
      if (_results.isNotEmpty && _focusNode.hasFocus) {
        _portal.show();
      } else {
        _portal.hide();
      }
    });
  }

  void _select(Product product) {
    widget.onProductSelected(product);
    widget.controller.clear();
    _debounce?.cancel();
    _queryToken++;
    setState(() {
      _results = [];
      _loading = false;
    });
    _portal.hide();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: TextFieldTapRegion(
              child: SizedBox(width: _fieldWidth, child: _buildDropdown()),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) _fieldWidth = constraints.maxWidth;
            return TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Ürün adı veya barkod ile ara...',
                isDense: true,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      shadowColor: Colors.black26,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loading && _results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sonuç bulunamadı', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (context, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        return ListTile(
                          dense: true,
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(formatCurrency(p.price1), style: const TextStyle(fontSize: 12)),
                          trailing: p.isOnlineActive
                              ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                              : null,
                          onTap: () => _select(p),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
