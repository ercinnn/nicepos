import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/products_provider.dart';
import '../../data/local/product_local_cache_dao.dart';
import '../../data/models/product.dart';

// ---------------------------------------------------------------------------
// Canlı ürün arama alanı — Satış ekranıyla PAYLAŞILAN bileşen (bkz.
// sales_screen.dart, Analiz sayfası).
// ---------------------------------------------------------------------------
// Barkod okutma davranışı korunur (onSubmitted): tam barkod okutulunca ürün
// doğrudan işlenir. Kullanıcı harf/rakam yazdıkça (onChanged) girilen metni
// içeren ürünler arama çubuğunun altında açılan listede gösterilir; metin
// uzadıkça liste daralır (sunucu tarafı substring + Türkçe-duyarlı arama).
// Listeden bir ürüne dokununca seçilir, alan temizlenir.
class LiveProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final bool autofocus;
  final Future<void> Function(String) onSubmitted;
  final void Function(Product) onProductSelected;

  const LiveProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onSubmitted,
    required this.onProductSelected,
    this.autofocus = false,
  });

  @override
  ConsumerState<LiveProductSearchField> createState() =>
      _LiveProductSearchFieldState();
}

class _LiveProductSearchFieldState
    extends ConsumerState<LiveProductSearchField> {
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
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      List<Product> results;
      try {
        results = await ref.read(productRepositoryProvider).fetchAll(query: query);
      } catch (_) {
        // Ağ başarısız — native'de yerel önbellekten (products_cache) aynı
        // arama fallback'i (offline'da canlı öneri listesi boş kalmasın diye).
        try {
          results = kIsWeb
              ? const []
              : await ref.read(productLocalCacheDaoProvider).searchCached(query: query);
        } catch (_) {
          results = const [];
        }
      }
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
