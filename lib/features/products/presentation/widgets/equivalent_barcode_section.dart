import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../application/products_provider.dart';

/// Ürün formu → "Diğer Detaylar" sekmesi EN BAŞI — kullanıcı istediği kadar
/// eşlenik barkod ekleyip çıkarabilir (bkz. 0021_equivalent_barcodes.sql:
/// tedarikçiden farklı barkodla gelen AYNI fiziksel ürünü gruplama).
///
/// Bu widget'ın state'i `_ProductFormScreenState._save()` akışını ETKİLEMEZ —
/// bağımsız repository çağrıları (`linkEquivalentBarcode`/`unlinkEquivalentBarcode`),
/// `Product`/`toInsertMap()` üzerinden gitmez, hemen sunucuya yazılır.
class EquivalentBarcodeSection extends ConsumerStatefulWidget {
  /// null/boş ise ürün henüz kaydedilmemiş — bölüm devre dışı gösterilir.
  final String? productId;

  const EquivalentBarcodeSection({super.key, required this.productId});

  @override
  ConsumerState<EquivalentBarcodeSection> createState() => _EquivalentBarcodeSectionState();
}

class _EquivalentBarcodeSectionState extends ConsumerState<EquivalentBarcodeSection> {
  bool _loading = true;
  List<Product> _members = [];

  bool get _enabled => widget.productId != null && widget.productId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.fetchById(widget.productId!);
      final groupId = product?.equivalentGroupId;
      final members = groupId == null ? <Product>[] : await repo.fetchGroupMembers(groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _unlink(Product p) async {
    try {
      await ref.read(productRepositoryProvider).unlinkEquivalentBarcode(p.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Bağlantı kaldırılamadı: $e')));
    }
  }

  Future<void> _addBarcode() async {
    final selected = await showDialog<Product>(
      context: context,
      builder: (_) => _EquivalentProductPickerDialog(excludeId: widget.productId!),
    );
    if (selected == null) return;
    if (selected.id == widget.productId) return; // kendi kendine bağlama engeli
    try {
      await ref.read(productRepositoryProvider).linkEquivalentBarcode(widget.productId!, selected.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Barkod bağlanamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.link, size: 18, color: AppColors.primary),
              SizedBox(width: AppSizes.space8),
              Text('Eşlenik Barkod',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSizes.space4),
          if (!_enabled)
            const Text(
              'Eşlenik barkod eklemek için önce ürünü kaydedin.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else ...[
            const Text(
              'Aynı fiziksel ürünün farklı tedarikçi barkodlarını bağlayın — stok toplanır, '
              'fiyat en son güncellenen barkoddan alınır.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.space8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.space8),
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_members.isEmpty)
              const Text('Bu ürüne bağlı eşlenik barkod yok.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted))
            else
              Wrap(
                spacing: AppSizes.space8,
                runSpacing: AppSizes.space8,
                children: [
                  for (final m in _members)
                    Chip(
                      label: Text(
                        '${m.barcode ?? '-'} · ${m.name} (${formatNumber(m.stockQuantity)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: m.id == widget.productId
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.goldBg,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _unlink(m),
                    ),
                ],
              ),
            const SizedBox(height: AppSizes.space8),
            OutlinedButton.icon(
              onPressed: _addBarcode,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Barkod Ekle'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+ Barkod Ekle" — barkod/isimle canlı ürün arama diyaloğu. Seçilen ürün
/// çağırana (`EquivalentBarcodeSection._addBarcode`) döner.
class _EquivalentProductPickerDialog extends ConsumerStatefulWidget {
  final String excludeId;

  const _EquivalentProductPickerDialog({required this.excludeId});

  @override
  ConsumerState<_EquivalentProductPickerDialog> createState() => _EquivalentProductPickerDialogState();
}

class _EquivalentProductPickerDialogState extends ConsumerState<_EquivalentProductPickerDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await ref.read(productRepositoryProvider).fetchAll(query: q.trim());
      if (!mounted) return;
      setState(() {
        _results = results.where((p) => p.id != widget.excludeId).take(20).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eşlenik Barkod Ekle'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ürün adı veya barkod ara...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: AppSizes.space8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text('Arama yapın', style: TextStyle(color: AppColors.textMuted)))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = _results[i];
                            return ListTile(
                              dense: true,
                              title: Text(p.name, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                'Barkod: ${p.barcode ?? '-'}  ·  Stok: ${formatNumber(p.stockQuantity)}  ·  ${formatCurrency(p.price1)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => Navigator.of(context).pop(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}
