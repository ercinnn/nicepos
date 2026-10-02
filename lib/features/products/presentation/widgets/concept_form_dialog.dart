import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../sales/application/barcode_cache.dart';
import '../../../sales/application/concept_cache.dart';
import '../../application/concept_products_provider.dart';
import '../../application/products_provider.dart';
import '../../data/models/concept_product.dart';
import '../../data/models/product.dart';
import '../screens/product_form_screen.dart' show nextBarcodeCandidate;
import 'live_product_search_field.dart';

/// Konsept Ürün ekle/düzenle — barkod (C + YYAAGG + sıra, otomatik üretilir),
/// ad, isteğe bağlı konsept fiyatı ve parça listesi (ürün + adet).
/// Kaydedilirse `true` döner.
class ConceptFormDialog extends ConsumerStatefulWidget {
  final ConceptProduct? concept;

  const ConceptFormDialog({super.key, this.concept});

  @override
  ConsumerState<ConceptFormDialog> createState() => _ConceptFormDialogState();
}

class _ConceptFormDialogState extends ConsumerState<ConceptFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  /// Parçalar — sıra korunur (satışta sepete bu sırayla eklenir).
  final List<ConceptProductItem> _items = [];
  final Map<String, TextEditingController> _qtyCtrls = {};

  bool _generating = false;
  bool _saving = false;

  bool get _isEdit => widget.concept != null;

  @override
  void initState() {
    super.initState();
    final c = widget.concept;
    _barcodeCtrl = TextEditingController(text: c?.barcode ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _priceCtrl = TextEditingController(text: c?.price != null ? _fmtNum(c!.price!) : '');
    for (final i in c?.items ?? const <ConceptProductItem>[]) {
      if (i.product == null) continue;
      _items.add(i);
      _qtyCtrls[i.productId] = TextEditingController(text: _fmtNum(i.quantity));
    }
    ref.read(barcodeCacheProvider).ensureLoaded();
    if (!_isEdit) _generateBarcode();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  static num? _parseNum(String text) => num.tryParse(text.trim().replaceAll(',', '.'));

  /// Bugünün önekiyle (C + YYAAGG) henüz kullanılmamış ilk sıra numarası.
  Future<void> _generateBarcode() async {
    setState(() => _generating = true);
    try {
      final prefix = conceptBarcodePrefix(DateTime.now());
      final existing = await ref.read(conceptRepositoryProvider).fetchBarcodesWithPrefix(prefix);
      if (!mounted) return;
      _barcodeCtrl.text = nextBarcodeCandidate(prefix, existing);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Barkod üretilemedi: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _addProduct(Product p) {
    setState(() {
      final index = _items.indexWhere((i) => i.productId == p.id);
      if (index >= 0) {
        final q = _items[index].quantity + 1;
        _items[index] = _items[index].copyWith(quantity: q);
        _qtyCtrls[p.id]!.text = _fmtNum(q);
      } else {
        _items.add(ConceptProductItem(productId: p.id, quantity: 1, product: p));
        _qtyCtrls[p.id] = TextEditingController(text: '1');
      }
    });
    _searchCtrl.clear();
    _searchFocus.requestFocus();
  }

  Future<void> _onSearchSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    var product = ref.read(barcodeCacheProvider).lookup(query);
    if (product == null) {
      try {
        product = await ref.read(productRepositoryProvider).fetchByBarcode(query);
      } catch (_) {}
    }
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$query" barkodlu ürün bulunamadı.')));
      return;
    }
    _addProduct(product);
  }

  void _setQty(int index, num qty) {
    setState(() => _items[index] = _items[index].copyWith(quantity: qty));
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      _qtyCtrls.remove(removed.productId)?.dispose();
    });
  }

  num get _componentsTotal =>
      _items.fold<num>(0, (s, i) => s + (i.product?.price1 ?? 0) * i.quantity);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('En az bir parça ekleyin.')));
      return;
    }
    if (_items.any((i) => i.quantity <= 0)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Parça adetleri 0\'dan büyük olmalı.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final priceText = _priceCtrl.text.trim();
      await ref.read(conceptRepositoryProvider).save(
            id: widget.concept?.id,
            barcode: _barcodeCtrl.text.trim().toUpperCase(),
            name: _nameCtrl.text.trim(),
            price: priceText.isEmpty ? null : _parseNum(priceText),
            items: _items,
          );
      ref.invalidate(conceptProductsProvider);
      ref.invalidate(conceptCacheProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.code == '23505' ? 'Bu barkod başka bir konseptte kullanılıyor.' : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final total = _componentsTotal;
    final price = _parseNum(_priceCtrl.text);
    final diffPct = (price != null && total > 0 && price < total) ? (total - price) / total * 100 : null;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: width < 650 ? 12 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_isEdit ? 'Konsept Düzenle' : 'Yeni Konsept Ürün',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Konsept Barkodu *',
                                helperText: 'C + YYAAGG + sıra no (ör. C261002001)',
                                suffixIcon: _isEdit
                                    ? null
                                    : _generating
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2)),
                                          )
                                        : IconButton(
                                            tooltip: 'Yeniden üret',
                                            onPressed: _generateBarcode,
                                            icon: const Icon(Icons.refresh),
                                          ),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Barkod zorunlu.' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: _priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: const InputDecoration(
                                labelText: 'Konsept Fiyatı',
                                helperText: 'Boş = parça toplamı',
                                suffixText: '₺',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                return _parseNum(v) == null ? 'Geçersiz' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Konsept Adı *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad zorunlu.' : null,
                      ),
                      const SizedBox(height: 20),
                      const Text('Parçalar',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      LiveProductSearchField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onSubmitted: _onSearchSubmitted,
                        onProductSelected: _addProduct,
                        decoration: const InputDecoration(
                          hintText: 'Parça barkodu okutun veya ürün adı yazın...',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Henüz parça eklenmedi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      else
                        for (var k = 0; k < _items.length; k++) _buildItemRow(k),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('Parça toplamı: ${formatCurrency(total)}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    Text('Satış fiyatı: ${formatCurrency(price ?? total)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (diffPct != null)
                      Text('Parçalara %${diffPct.toStringAsFixed(2)} iskonto dağıtılır',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    if (price != null && price > total && total > 0)
                      const Text('Parça fiyatları oranla artırılır',
                          style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Vazgeç'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving || _generating ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    final p = item.product!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${p.barcode ?? '-'} · ${formatCurrency(p.price1)} · Stok ${_fmtNum(p.stockQuantity)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: item.quantity > 1
                ? () {
                    final q = item.quantity - 1;
                    _qtyCtrls[item.productId]!.text = _fmtNum(q);
                    _setQty(index, q);
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          SizedBox(
            width: 52,
            child: TextField(
              controller: _qtyCtrls[item.productId],
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final q = _parseNum(v);
                if (q != null) _setQty(index, q);
              },
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final q = item.quantity + 1;
              _qtyCtrls[item.productId]!.text = _fmtNum(q);
              _setQty(index, q);
            },
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Parçayı çıkar',
            onPressed: () => _removeItem(index),
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
