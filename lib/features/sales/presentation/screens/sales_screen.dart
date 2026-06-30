import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../../../features/products/data/models/product.dart';
import '../../application/sales_cart_notifier.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/cart_table.dart';
import '../widgets/customer_tabs.dart';
import '../widgets/payment_panel.dart';
import '../widgets/product_search_dialog.dart';
import '../widgets/quick_products_panel.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    final product = await ref.read(productRepositoryProvider).fetchByBarcode(query);
    if (product != null) {
      HapticFeedback.lightImpact();
      ref.read(salesCartProvider.notifier).addProduct(product);
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    final matches = await ref.read(productRepositoryProvider).fetchAll(query: query);
    if (matches.length == 1) {
      HapticFeedback.lightImpact();
      ref.read(salesCartProvider.notifier).addProduct(matches.first);
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    if (mounted) {
      await showDialog(context: context, builder: (_) => ProductSearchDialog(initialQuery: query));
    }
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  void _showMobilePaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobilePaymentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobile();
    return _buildDesktop();
  }

  // ─── Desktop layout ───────────────────────────────────────────────────────

  Widget _buildDesktop() {
    final isReturnMode = ref.watch(salesCartProvider).isReturnMode;

    return Focus(
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LiveProductSearchField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Ürün barkodunu okutunuz veya ürün adı yazıp Enter\'a basınız...',
                    prefixIcon: Icon(Icons.qr_code_scanner, size: 18),
                  ),
                  onSubmitted: _onBarcodeSubmitted,
                  onProductSelected: (p) {
                    HapticFeedback.lightImpact();
                    ref.read(salesCartProvider.notifier).addProduct(p);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showDialog(
                    context: context, builder: (_) => const ProductSearchDialog()),
                icon: const Icon(Icons.search),
                label: const Text('Ara'),
              ),
              const SizedBox(width: 8),
              _ReturnModeButton(isActive: isReturnMode),
            ],
          ),
          const SizedBox(height: 12),
          const CustomerTabs(),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: const CartTable(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 580,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 320, child: PaymentPanel()),
                      const SizedBox(height: 12),
                      const Expanded(child: Card(child: QuickProductsPanel())),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile layout ───────────────────────────────────────────────────────

  Widget _buildMobile() {
    final salesState = ref.watch(salesCartProvider);
    final tab = salesState.active;
    final hasItems = tab.items.isNotEmpty;
    final isReturnMode = salesState.isReturnMode;

    return Column(
      children: [
        // Barkod satırı (kompakt)
        Row(
          children: [
            Expanded(
              child: _LiveProductSearchField(
                controller: _barcodeController,
                focusNode: _barcodeFocusNode,
                decoration: InputDecoration(
                  hintText: isReturnMode ? 'İade ürünü barkod veya adı...' : 'Barkod veya ürün adı...',
                  prefixIcon: const Icon(Icons.qr_code_scanner, size: 18),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => showDialog(
                        context: context, builder: (_) => const ProductSearchDialog()),
                  ),
                ),
                onSubmitted: _onBarcodeSubmitted,
                onProductSelected: (p) {
                  HapticFeedback.lightImpact();
                  ref.read(salesCartProvider.notifier).addProduct(p);
                },
              ),
            ),
            const SizedBox(width: 8),
            _ReturnModeButton(isActive: isReturnMode, compact: true),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => openBarcodeScanner(context, _onBarcodeSubmitted),
                  child: const Icon(Icons.camera_alt_outlined, size: 22),
                ),
              ),
            ],
          ],
        ),
        // İade modu banner (mobil)
        if (isReturnMode) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                vertical: AppSizes.space6, horizontal: AppSizes.space8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.undo_rounded, color: AppColors.danger, size: 14),
                SizedBox(width: 4),
                Text(
                  'İADE MODU AKTİF — Sepete eklediğiniz ürünler iade edilecek',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const CustomerTabs(),
        const SizedBox(height: 8),
        // Sepet tablosu — tam genişlik
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: const CartTable(),
            ),
          ),
        ),
        // Hızlı ürünler — sabit yükseklik
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(
              'Hızlı Ürünler',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 196,
          child: Card(
            margin: EdgeInsets.zero,
            child: const QuickProductsPanel(),
          ),
        ),
        const SizedBox(height: 10),
        // Ödeme çubuğu
        _MobilePaymentBar(
          total: tab.total,
          itemCount: tab.items.length,
          hasItems: hasItems,
          isReturnMode: isReturnMode,
          onPay: _showMobilePaymentSheet,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// İade Modu Toggle Butonu
// ---------------------------------------------------------------------------

class _ReturnModeButton extends ConsumerWidget {
  final bool isActive;
  final bool compact;

  const _ReturnModeButton({required this.isActive, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: compact
          ? IconButton(
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : Colors.transparent,
                foregroundColor: isActive ? AppColors.danger : AppColors.textMuted,
                side: BorderSide(
                  color: isActive ? AppColors.danger : AppColors.border,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              tooltip: isActive ? 'İade Modunu Kapat' : 'İade Modu',
              icon: const Icon(Icons.undo_rounded, size: 20),
              onPressed: () => ref.read(salesCartProvider.notifier).toggleReturnMode(),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? AppColors.danger : AppColors.textMuted,
                side: BorderSide(
                  color: isActive ? AppColors.danger : AppColors.border,
                ),
                backgroundColor: isActive ? AppColors.danger.withValues(alpha: 0.08) : null,
              ),
              onPressed: () => ref.read(salesCartProvider.notifier).toggleReturnMode(),
              icon: Icon(
                isActive ? Icons.undo_rounded : Icons.undo_rounded,
                size: 18,
              ),
              label: Text(isActive ? 'İade Modu: Açık' : 'İade Modu'),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: sticky payment bar at the bottom
// ---------------------------------------------------------------------------

class _MobilePaymentBar extends ConsumerWidget {
  final num total;
  final int itemCount;
  final bool hasItems;
  final bool isReturnMode;
  final VoidCallback onPay;

  const _MobilePaymentBar({
    required this.total,
    required this.itemCount,
    required this.hasItems,
    required this.isReturnMode,
    required this.onPay,
  });

  void _onPay() {
    HapticFeedback.mediumImpact();
    onPay();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barColor = isReturnMode ? AppColors.danger.withValues(alpha: 0.06) : AppColors.cardBg;
    final borderColor = isReturnMode ? AppColors.danger.withValues(alpha: 0.5) : AppColors.goldBorder;
    final amountColor = isReturnMode ? AppColors.danger : AppColors.primary;
    final buttonColor = isReturnMode ? AppColors.danger : AppColors.primary;
    final buttonLabel = isReturnMode ? 'İade Al' : 'Ödeme Al';
    final buttonIcon = isReturnMode ? Icons.undo_rounded : Icons.payments_outlined;
    final labelColor = isReturnMode ? AppColors.danger : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: AppSizes.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isReturnMode ? 'İade Tutarı' : 'Toplam',
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                    if (itemCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: amountColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                        ),
                        child: Text(
                          '$itemCount kalem',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: amountColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Ray genişliği hero rakam genişliğine bağlanır (~%40) — sabit px yerine.
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SizeTransition(
                            sizeFactor: anim,
                            axis: Axis.vertical,
                            child: child,
                          ),
                        ),
                        child: Text(
                          formatCurrency(total),
                          key: ValueKey(total),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: amountColor,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // İmza öğesi — hero tutarın altın aksan rayı (design-tokens §4)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.4,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isReturnMode ? AppColors.danger : AppColors.gold,
                            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: hasItems ? _onPay : null,
              icon: Icon(buttonIcon, size: 20),
              label: Text(buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryMid.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: payment bottom sheet
// ---------------------------------------------------------------------------

class _MobilePaymentSheet extends StatelessWidget {
  const _MobilePaymentSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      'Ödeme',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: const PaymentPanel(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Canlı ürün arama alanı
// ---------------------------------------------------------------------------
// Barkod okutma davranışı korunur (onSubmitted): tam barkod okutulunca ürün
// doğrudan sepete eklenir. Kullanıcı harf/rakam yazdıkça (onChanged) girilen
// metni içeren ürünler arama çubuğunun altında açılan listede gösterilir;
// metin uzadıkça liste daralır (sunucu tarafı substring + Türkçe-duyarlı arama).
// Listeden bir ürüne dokununca sepete eklenir, alan temizlenir.
class _LiveProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final bool autofocus;
  final Future<void> Function(String) onSubmitted;
  final void Function(Product) onProductSelected;

  const _LiveProductSearchField({
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onSubmitted,
    required this.onProductSelected,
    this.autofocus = false,
  });

  @override
  ConsumerState<_LiveProductSearchField> createState() =>
      _LiveProductSearchFieldState();
}

class _LiveProductSearchFieldState
    extends ConsumerState<_LiveProductSearchField> {
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
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    // Odak kaybolunca listeyi kapat (sonuca dokunma TapRegion ile korunur).
    if (!widget.focusNode.hasFocus) _portal.hide();
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
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results =
            await ref.read(productRepositoryProvider).fetchAll(query: query);
        if (!mounted || token != _queryToken) return;
        // Kullanıcı bu arada metni değiştirdiyse bu sonucu yok say.
        if (widget.controller.text.trim() != query) return;
        setState(() {
          _results = results.take(40).toList();
          _loading = false;
        });
        if (_results.isNotEmpty && widget.focusNode.hasFocus) {
          _portal.show();
        } else {
          _portal.hide();
        }
      } catch (_) {
        if (!mounted || token != _queryToken) return;
        setState(() {
          _results = [];
          _loading = false;
        });
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
    widget.focusNode.requestFocus();
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
            // Aynı odak grubunda kal: listeye dokunmak TextField odağını
            // düşürmez, böylece kapanmadan seçim işlenir.
            child: TextFieldTapRegion(
              child: SizedBox(
                width: _fieldWidth,
                child: _buildDropdown(),
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) {
              _fieldWidth = constraints.maxWidth;
            }
            return TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              decoration: widget.decoration,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _portal.hide();
                widget.onSubmitted(v);
              },
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
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ürün bulunamadı.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        return InkWell(
                          onTap: () => _select(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.space12,
                                vertical: AppSizes.space8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (p.barcode != null &&
                                          p.barcode!.isNotEmpty)
                                        Text(
                                          '${p.barcode}  ·  Stok: ${formatNumber(p.stockQuantity)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatCurrency(p.price1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
