import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../../../features/products/data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/sale_item.dart';
import '../../data/repositories/sales_repository.dart';

class SaleEditScreen extends ConsumerStatefulWidget {
  final Sale sale;
  final List<SaleItem> initialItems;

  const SaleEditScreen({
    super.key,
    required this.sale,
    required this.initialItems,
  });

  @override
  ConsumerState<SaleEditScreen> createState() => _SaleEditScreenState();
}

class _SaleEditScreenState extends ConsumerState<SaleEditScreen> {
  late List<SaleItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  num get _total => _items.fold<num>(0, (sum, item) => sum + item.total);

  Future<void> _addMiscItem() async {
    final nameController = TextEditingController(text: 'Muhtelif');
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Muhtelif Ürün'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Birim Fiyat'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Miktar'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final price = num.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
    final qty = num.tryParse(qtyController.text) ?? 1;
    final name = nameController.text.trim().isEmpty ? 'Muhtelif' : nameController.text.trim();

    setState(() {
      _items.add(SaleItem(
        productId: null,
        productName: name,
        quantity: qty,
        unitPrice: price,
        discountValue: 0,
        total: price * qty,
      ));
    });
  }

  Future<void> _addProduct() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => const _ProductPickerDialog(),
    );
    if (product == null) return;

    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      final old = _items[existing];
      final newQty = old.quantity + 1;
      setState(() {
        _items[existing] = SaleItem(
          id: old.id,
          saleId: old.saleId,
          productId: old.productId,
          productName: old.productName,
          quantity: newQty,
          unitPrice: old.unitPrice,
          discountValue: old.discountValue,
          total: (old.unitPrice * newQty) - old.discountValue,
          note: old.note,
        );
      });
    } else {
      setState(() {
        _items.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.price1,
          discountValue: 0,
          total: product.price1,
        ));
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _changeQuantity(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.productName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: const InputDecoration(labelText: 'Miktar'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final val = num.tryParse(controller.text);
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      final old = _items[index];
      _items[index] = SaleItem(
        id: old.id,
        saleId: old.saleId,
        productId: old.productId,
        productName: old.productName,
        quantity: result,
        unitPrice: old.unitPrice,
        discountValue: old.discountValue,
        total: (old.unitPrice * result) - old.discountValue,
        note: old.note,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = SalesRepository();
      final remainingDebt = (widget.sale.totalAmount - widget.sale.cashAmount - widget.sale.cardAmount)
          .clamp(0, double.infinity);
      await repo.updateSale(
        saleId: widget.sale.id,
        oldItems: widget.initialItems,
        items: _items,
        totalAmount: _total,
        discountPercent: widget.sale.discountPercent,
        paidAmount: widget.sale.paidAmount,
        cashAmount: widget.sale.cashAmount,
        cardAmount: widget.sale.cardAmount,
        remainingDebt: remainingDebt,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobile(context);
    // ── Masaüstü: geniş dialog ────────────────────────────────────────────────
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Satış Düzenle — ${widget.sale.saleCode}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.sale.customerName ?? 'Perakende',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Ürün yok. Eklemek için aşağıdaki butona tıklayın.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(label: Text('Ürün')),
                            DataColumn(label: Text('Miktar'), numeric: true),
                            DataColumn(label: Text('Birim Fiyat'), numeric: true),
                            DataColumn(label: Text('Toplam'), numeric: true),
                            DataColumn(label: Text('')),
                          ],
                          rows: List.generate(_items.length, (i) {
                            final item = _items[i];
                            return DataRow(cells: [
                              DataCell(
                                SizedBox(
                                  width: 200,
                                  child: Text(
                                    item.productName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                InkWell(
                                  onTap: () => _changeQuantity(i),
                                  child: Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(formatCurrency(item.unitPrice))),
                              DataCell(Text(
                                formatCurrency(item.total),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              )),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: AppColors.danger,
                                  tooltip: 'Kaldır',
                                  onPressed: () => _removeItem(i),
                                ),
                              ),
                            ]);
                          }),
                        ),
                      ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ürün Ekle'),
                    onPressed: _saving ? null : _addProduct,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Muhtelif'),
                    onPressed: _saving ? null : _addMiscItem,
                  ),
                  const Spacer(),
                  Text(
                    'Toplam: ',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                  Text(
                    formatCurrency(_total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobil: tam ekran dialog ─────────────────────────────────────────────────
  // DataTable mobilde küçük ekranlara sığmaz; kart listesiyle değiştirilir.
  // Miktar alanına dokunulduğunda dialog açılır (masaüstüyle aynı mantık).
  Widget _buildMobile(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _saving ? null : () => Navigator.pop(context, false),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Satış Düzenle — ${widget.sale.saleCode}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                widget.sale.customerName ?? 'Perakende',
                style: const TextStyle(fontSize: 12, color: AppColors.goldLight),
              ),
            ],
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.primary),
                  child: const Text('Kaydet',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Ürün listesi ─────────────────────────────────────────────────
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Ürün yok.\nEklemek için aşağıdaki butonları kullanın.',
                          style: TextStyle(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          // Ürün adı
                          title: Text(
                            item.productName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Miktar + birim fiyat — dokunarak miktar düzenlenebilir
                          subtitle: GestureDetector(
                            onTap: () => _changeQuantity(i),
                            child: Text(
                              'Miktar: ${item.quantity}  ·  Birim: ${formatCurrency(item.unitPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Satır toplamı
                              Text(
                                formatCurrency(item.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Sil
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppColors.danger,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // ── Alt çubuk: Ürün Ekle · Muhtelif · Toplam ────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.pageBg,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ürün ekle / muhtelif satırı
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ürün Ekle'),
                          onPressed: _saving ? null : _addProduct,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Muhtelif'),
                          onPressed: _saving ? null : _addMiscItem,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Toplam + Kaydet
                  Row(
                    children: [
                      const Text(
                        'Toplam: ',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                      Text(
                        formatCurrency(_total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerDialog extends ConsumerStatefulWidget {
  const _ProductPickerDialog();

  @override
  ConsumerState<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends ConsumerState<_ProductPickerDialog> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
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
      title: const Text('Ürün Seç'),
      content: SizedBox(
        width: 480,
        height: 440,
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
                          separatorBuilder: (context2, index2) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = _results[i];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text('${p.barcode ?? '-'} · Stok: ${p.stockQuantity}'),
                              trailing: Text(formatCurrency(p.price1)),
                              onTap: () => Navigator.pop(ctx, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}
