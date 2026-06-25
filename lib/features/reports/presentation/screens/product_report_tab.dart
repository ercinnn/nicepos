import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../sales/presentation/screens/sale_edit_screen.dart';
import '../../application/reports_provider.dart';
import '../../data/models/product_sale_record.dart';

class ProductReportTab extends ConsumerStatefulWidget {
  const ProductReportTab({super.key});

  @override
  ConsumerState<ProductReportTab> createState() => _ProductReportTabState();
}

class _ProductReportTabState extends ConsumerState<ProductReportTab> {
  final _controller = TextEditingController();
  String? _submittedQuery;
  Product? _selectedProduct;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _submittedQuery = q;
      _selectedProduct = null;
    });
  }

  void _selectProduct(Product p) {
    setState(() {
      _selectedProduct = p;
      _submittedQuery = null;
      _controller.clear();
    });
  }

  void _clearSelection() {
    setState(() => _selectedProduct = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ürün Raporları',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Ürün adı, barkod veya stok kodu...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.pageBg,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Ara'),
              onPressed: _search,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _submittedQuery != null
              ? _ProductSearchResults(
                  query: _submittedQuery!,
                  onSelect: _selectProduct,
                )
              : _selectedProduct != null
                  ? _ProductHistory(
                      product: _selectedProduct!,
                      onBack: _clearSelection,
                    )
                  : const Center(
                      child: Text(
                        'Bir ürün arayın, seçin ve satış geçmişini görüntüleyin.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Ürün Arama Sonuçları ──────────────────────────────────────────────────────

class _ProductSearchResults extends ConsumerWidget {
  final String query;
  final void Function(Product) onSelect;

  const _ProductSearchResults({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(
      pagedProductsProvider(ProductsQuery(query: query, pageSize: 30)),
    );

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Text(
              '"$query" ile eşleşen ürün bulunamadı.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return Card(
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, i) {
              final p = products[i];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary, size: 18),
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (p.stockCode != null && p.stockCode!.isNotEmpty)
                      'Kod: ${p.stockCode}',
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      'Barkod: ${p.barcode}',
                    if (p.groupName != null) p.groupName!,
                  ].join('  ·  '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(p.price1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    Text(
                      'Stok: ${p.stockQuantity}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                onTap: () => onSelect(p),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Ürün Geçmişi ─────────────────────────────────────────────────────────────

class _ProductHistory extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback onBack;

  const _ProductHistory({required this.product, required this.onBack});

  @override
  ConsumerState<_ProductHistory> createState() => _ProductHistoryState();
}

class _ProductHistoryState extends ConsumerState<_ProductHistory> {
  Future<void> _openSaleEdit(ProductSaleRecord r) async {
    final repo = SalesRepository();
    final sale = await repo.fetchSaleById(r.saleId);
    final items = await repo.fetchItems(r.saleId);
    if (!context.mounted) return;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleEditScreen(sale: sale, initialItems: items),
    );
    if (updated == true) {
      ref.invalidate(productSalesHistoryProvider(widget.product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(productSalesHistoryProvider(widget.product.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geri butonu + ürün kartı
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Ürün Ara'),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 8),
            Expanded(child: _ProductInfoCard(product: widget.product)),
          ],
        ),
        const SizedBox(height: 16),
        // Geçmiş tablosu
        Expanded(
          child: historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (records) => records.isEmpty
                ? const Center(
                    child: Text(
                      'Bu ürüne ait satış kaydı bulunamadı.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : _SaleHistoryContent(records: records, onRowTap: _openSaleEdit),
          ),
        ),
      ],
    );
  }
}

// ── Ürün Bilgi Kartı ─────────────────────────────────────────────────────────
// Masaüstü: ürün adı + 4 fiyat chip'i yan yana tek satırda
// Mobil: ad üstte, 4 chip altta yatay dağılır (4×chip yan yana taşar)

class _ProductInfoCard extends StatelessWidget {
  final Product product;
  const _ProductInfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    // Ürün adı + bilgi metni
    Widget nameSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.name,
          style: TextStyle(
            fontSize: isMobile ? 13 : 15,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (product.groupName != null || product.stockCode != null)
          Text(
            [
              if (product.groupName != null) product.groupName!,
              if (product.stockCode != null) 'Kod: ${product.stockCode}',
              if (product.barcode != null) 'Barkod: ${product.barcode}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    // 4 fiyat chip'i
    Widget chipsSection = Row(
      children: [
        Expanded(
          child: _PriceChip(
              'Alış', product.purchasePrice, AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PriceChip('Fiyat 1', product.price1, AppColors.primary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PriceChip('Fiyat 2', product.price2, AppColors.pos),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PriceChip(
              'Stok', product.stockQuantity, AppColors.success),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: isMobile
            // Mobil: ad üstte, chip'ler altta — taşma olmaz
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  nameSection,
                  const SizedBox(height: 8),
                  chipsSection,
                ],
              )
            // Masaüstü: yan yana tek satır
            : Row(
                children: [
                  Expanded(child: nameSection),
                  const SizedBox(width: 16),
                  _PriceChip(
                      'Alış', product.purchasePrice, AppColors.textSecondary),
                  const SizedBox(width: 12),
                  _PriceChip('Fiyat 1', product.price1, AppColors.primary),
                  const SizedBox(width: 12),
                  _PriceChip('Fiyat 2', product.price2, AppColors.pos),
                  const SizedBox(width: 12),
                  _PriceChip('Stok', product.stockQuantity, AppColors.success),
                ],
              ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final num value;
  final Color color;

  const _PriceChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            label == 'Stok' ? value.toString() : formatCurrency(value),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Satış Geçmişi İçeriği ────────────────────────────────────────────────────

class _SaleHistoryContent extends StatelessWidget {
  final List<ProductSaleRecord> records;
  final Future<void> Function(ProductSaleRecord) onRowTap;
  const _SaleHistoryContent({required this.records, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final prices = records.map((r) => r.unitPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final avgPrice = prices.fold<num>(0, (a, b) => a + b) / prices.length;
    final totalQty = records.fold<num>(0, (a, r) => a + r.quantity);
    final totalAmount = records.fold<num>(0, (a, r) => a + r.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Özet istatistikler
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _StatChip('Toplam Satış', '${records.length} işlem', AppColors.primary),
            _StatChip('Toplam Miktar', totalQty.toString(), AppColors.textSecondary),
            _StatChip('Toplam Tutar', formatCurrency(totalAmount), AppColors.success),
            _StatChip('Min Birim Fiyat', formatCurrency(minPrice), AppColors.pos),
            _StatChip('Maks Birim Fiyat', formatCurrency(maxPrice), AppColors.danger),
            _StatChip('Ort Birim Fiyat', formatCurrency(avgPrice), AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),
        // Tablo
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppColors.tableHeader),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Tarih')),
                    DataColumn(label: Text('Satış Kodu')),
                    DataColumn(label: Text('Müşteri')),
                    DataColumn(label: Text('Miktar'), numeric: true),
                    DataColumn(label: Text('Birim Fiyat'), numeric: true),
                    DataColumn(label: Text('Toplam'), numeric: true),
                  ],
                  rows: List.generate(records.length, (i) {
                    final r = records[i];
                    return DataRow(
                      onSelectChanged: (_) => onRowTap(r),
                      cells: [
                      DataCell(Text('${i + 1}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12))),
                      DataCell(Text(
                        formatDateTime(r.saleDate),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      )),
                      DataCell(Text(
                        r.saleCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      )),
                      DataCell(Text(
                        r.customerName ?? 'Perakende',
                        style: TextStyle(
                          color: r.customerName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontStyle: r.customerName == null
                              ? FontStyle.italic
                              : null,
                        ),
                      )),
                      DataCell(Text(r.quantity.toString())),
                      DataCell(Text(
                        formatCurrency(r.unitPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                        formatCurrency(r.total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      )),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── İstatistik Chip ───────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
