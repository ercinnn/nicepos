import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/product.dart';
import '../../application/product_columns_provider.dart';
import '../../application/products_provider.dart';
import '../widgets/excel_import_dialog.dart';
import '../widgets/excel_export.dart';

// ── Ekran ─────────────────────────────────────────────────────────────────────

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  final _searchController = TextEditingController();
  String? _selectedGroupId;
  String _query = '';
  int _page = 0;

  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIds.clear();
    });
    try {
      final rows = await ref.read(productRepositoryProvider).fetchPaged(
            query: _query,
            groupId: _selectedGroupId,
            page: _page,
            pageSize: kProductPageSize,
          );
      if (!mounted) return;
      setState(() {
        _products = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Kolon seçici dialog ──────────────────────────────────────────────────────

  Future<void> _showColumnPicker() async {
    final current = ref.read(productColumnsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ColumnPickerDialog(
        selected: Set.from(current),
        onChanged: (col, visible) =>
            ref.read(productColumnsProvider.notifier).toggle(col, visible),
        onReset: () => ref.read(productColumnsProvider.notifier).reset(),
      ),
    );
  }

  // ── Ürün özet dialog ─────────────────────────────────────────────────────────

  Future<void> _showSummary() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ProductSummaryDialog(
        query: _query,
        groupId: _selectedGroupId,
      ),
    );
  }

  // ── Silme ────────────────────────────────────────────────────────────────────

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('"${p.name}" ürününü silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final prev = List<Product>.from(_products);
    setState(() {
      _products = _products.where((x) => x.id != p.id).toList();
      _selectedIds.remove(p.id);
    });

    try {
      await ref.read(productRepositoryProvider).delete(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${p.name}" silindi')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _products = prev);
      final msg = e.toString().contains('foreign key') ||
              e.toString().contains('violates')
          ? '"${p.name}" silinemedi: Bu ürüne ait satış kaydı bulunuyor.'
          : '"${p.name}" silinemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(msg)));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seçilenleri Sil'),
        content: Text(
          '$count ürünü silmek istediğinize emin misiniz?\n\n'
          'Satış kaydı bulunan ürünler silinemeyecek, atlanacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ids = Set<String>.from(_selectedIds);
    final repo = ref.read(productRepositoryProvider);
    int deleted = 0, skipped = 0;

    for (final id in ids) {
      try {
        await repo.delete(id);
        deleted++;
      } catch (_) {
        skipped++;
      }
    }

    if (!mounted) return;
    setState(() {
      _products =
          _products.where((p) => !ids.contains(p.id) || skipped > 0 && ids.contains(p.id)).toList();
      _selectedIds.clear();
    });
    await _loadProducts();
    if (!mounted) return;
    final msg = skipped == 0
        ? '$deleted ürün silindi.'
        : '$deleted ürün silindi, $skipped ürün silinemedi (satış kaydı mevcut).';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: skipped > 0 ? AppColors.warning : null,
    ));
  }

  // ── Seçim yardımcıları ───────────────────────────────────────────────────────

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _toggleSelectAll() {
    final pageIds = _displayProducts.map((p) => p.id).toSet();
    final allSel = pageIds.every(_selectedIds.contains);
    setState(() {
      allSel ? _selectedIds.removeAll(pageIds) : _selectedIds.addAll(pageIds);
    });
  }

  bool get _hasMore => _products.length > kProductPageSize;
  List<Product> get _displayProducts => _products.take(kProductPageSize).toList();
  bool get _allSelected {
    final ids = _displayProducts.map((p) => p.id).toSet();
    return ids.isNotEmpty && ids.every(_selectedIds.contains);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobile(context);
    return _buildDesktop(context);
  }

  // ─── Mobil layout ────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    final groupsAsync = ref.watch(productGroupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık + Ürün Özet + Yeni Ürün
        Row(
          children: [
            const Text('Ürünler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Ürün Özet butonu — masaüstüyle aynı işlevi mobilde de sunar
            IconButton(
              onPressed: _showSummary,
              icon: const Icon(Icons.summarize_outlined),
              tooltip: 'Ürün Özet',
              color: AppColors.primary,
            ),
            ElevatedButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Yeni'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Arama
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Ürün adı, barkod, stok kodu...',
            prefixIcon: Icon(Icons.search, size: 18),
            isDense: true,
          ),
          onChanged: (v) {
            setState(() { _query = v; _page = 0; _products = []; });
            _loadProducts();
          },
        ),
        const SizedBox(height: 8),
        // Grup filtresi
        groupsAsync.when(
          data: (groups) => DropdownButtonFormField<String?>(
            initialValue: _selectedGroupId,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Tüm gruplar'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tüm gruplar')),
              ...groups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
            ],
            onChanged: (v) {
              setState(() { _selectedGroupId = v; _page = 0; _products = []; });
              _loadProducts();
            },
          ),
          loading: () => const SizedBox(height: 40),
          error: (_, _) => const SizedBox(),
        ),
        const SizedBox(height: 8),
        // Liste
        Expanded(
          child: _loading && _products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Hata: $_error'))
                  : _displayProducts.isEmpty
                      ? const Center(child: Text('Ürün bulunamadı.'))
                      : ListView.separated(
                          itemCount: _displayProducts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ProductMobileCard(
                            product: _displayProducts[i],
                            onDelete: _deleteProduct,
                          ),
                        ),
        ),
        const SizedBox(height: 8),
        // Sayfalama
        _buildPagination(),
      ],
    );
  }

  // ─── Masaüstü layout ─────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    final groupsAsync = ref.watch(productGroupsProvider);
    final selCount = _selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Ürünler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                final all = await ref.read(productRepositoryProvider).fetchAll(
                      query: _query, groupId: _selectedGroupId);
                final result = await exportProductsToExcel(all);
                if (result != null && mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Excel kaydedildi: $result')));
                }
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Excel Aktar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await showDialog(
                    context: context, builder: (_) => const ExcelImportDialog());
                if (!mounted) return;
                ref.invalidate(productGroupsProvider);
                await _loadProducts();
              },
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Excel İçe Aktar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Ürün'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Ürün adı, barkod, stok kodu...',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (v) {
                  setState(() { _query = v; _page = 0; _products = []; });
                  _loadProducts();
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 240,
              child: groupsAsync.when(
                data: (groups) => DropdownButtonFormField<String?>(
                  initialValue: _selectedGroupId,
                  decoration: const InputDecoration(labelText: 'Tüm gruplar'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tüm gruplar')),
                    ...groups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                  ],
                  onChanged: (v) {
                    setState(() { _selectedGroupId = v; _page = 0; _products = []; });
                    _loadProducts();
                  },
                ),
                loading: () => const SizedBox(height: 40),
                error: (_, _) => const SizedBox(),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _showColumnPicker,
              icon: const Icon(Icons.view_column_outlined, size: 18),
              label: Text('Kolonlar (${ref.watch(productColumnsProvider).length})'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _showSummary,
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('Ürün Özet'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: selCount > 0
              ? Container(
                  key: const ValueKey('selection-bar'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('$selCount ürün seçildi',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedIds.clear()),
                        child: const Text('Seçimi Temizle'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: Text('$selCount Ürünü Sil'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger, foregroundColor: Colors.white, elevation: 0),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no-selection')),
        ),
        Expanded(
          child: Card(
            child: _loading && _products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Hata: $_error'))
                    : _displayProducts.isEmpty
                        ? const Center(child: Text('Ürün bulunamadı.'))
                        : _ProductsTable(
                            products: _displayProducts,
                            visibleColumns: ref.watch(productColumnsProvider),
                            selectedIds: _selectedIds,
                            allSelected: _allSelected,
                            onDelete: _deleteProduct,
                            onToggleSelect: _toggleSelect,
                            onToggleSelectAll: _toggleSelectAll,
                          ),
          ),
        ),
        const SizedBox(height: 8),
        _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _page > 0 && !_loading
              ? () { setState(() { _page--; _products = []; }); _loadProducts(); }
              : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Önceki'),
        ),
        const SizedBox(width: 16),
        Text('Sayfa ${_page + 1}', style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: _hasMore && !_loading
              ? () { setState(() { _page++; _products = []; }); _loadProducts(); }
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Sonraki'),
        ),
      ],
    );
  }
}

// ── Kolon Seçici Dialog ───────────────────────────────────────────────────────

class _ColumnPickerDialog extends StatefulWidget {
  final Set<ProductColumn> selected;
  final void Function(ProductColumn col, bool visible) onChanged;
  final VoidCallback onReset;

  const _ColumnPickerDialog({
    required this.selected,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<_ColumnPickerDialog> createState() => _ColumnPickerDialogState();
}

class _ColumnPickerDialogState extends State<_ColumnPickerDialog> {
  late Set<ProductColumn> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.view_column_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Kolon Seçimi'),
          const Spacer(),
          TextButton(
            onPressed: () {
              widget.onReset();
              setState(() => _selected = Set.from(defaultProductColumns));
            },
            child: const Text('Varsayılan'),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ProductColumn.values.map((col) {
            return CheckboxListTile(
              dense: true,
              title: Text(col.label,
                  style: const TextStyle(fontSize: 14)),
              value: _selected.contains(col),
              activeColor: AppColors.primary,
              checkColor: AppColors.goldLight,
              onChanged: (v) {
                final visible = v == true;
                widget.onChanged(col, visible);
                setState(() => visible
                    ? _selected.add(col)
                    : _selected.remove(col));
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

// ── Ürün Özet Dialog ──────────────────────────────────────────────────────────

class _ProductSummaryDialog extends ConsumerStatefulWidget {
  final String query;
  final String? groupId;

  const _ProductSummaryDialog({required this.query, this.groupId});

  @override
  ConsumerState<_ProductSummaryDialog> createState() =>
      _ProductSummaryDialogState();
}

class _ProductSummaryDialogState extends ConsumerState<_ProductSummaryDialog> {
  bool _loading = true;
  String? _error;
  int _count = 0;
  num _quantity = 0;
  num _cost = 0;
  num _sales = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await ref.read(productRepositoryProvider).fetchAll(
            query: widget.query,
            groupId: widget.groupId,
          );
      num quantity = 0, cost = 0, sales = 0;
      for (final p in products) {
        quantity += p.stockQuantity;
        cost += p.purchasePrice * p.stockQuantity;
        sales += p.price1 * p.stockQuantity;
      }
      if (!mounted) return;
      setState(() {
        _count = products.length;
        _quantity = quantity;
        _cost = cost;
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.summarize_outlined, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Ürün Özet'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text('Özet hesaplanamadı: $_error',
                    style: const TextStyle(color: AppColors.danger))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SummaryRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Toplam listelenen ürün',
                        value: formatNumber(_count),
                      ),
                      _SummaryRow(
                        icon: Icons.layers_outlined,
                        label: 'Listelenen parça sayısı',
                        value: formatNumber(_quantity),
                      ),
                      _SummaryRow(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Toplam ürün maliyeti',
                        value: formatCurrency(_cost),
                      ),
                      _SummaryRow(
                        icon: Icons.sell_outlined,
                        label: 'Toplam ürün satış tutarı',
                        value: formatCurrency(_sales),
                      ),
                    ],
                  ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dinamik Tablo ─────────────────────────────────────────────────────────────

class _ProductsTable extends StatelessWidget {
  final List<Product> products;
  final Set<ProductColumn> visibleColumns;
  final Set<String> selectedIds;
  final bool allSelected;
  final Future<void> Function(Product) onDelete;
  final void Function(String id) onToggleSelect;
  final VoidCallback onToggleSelectAll;

  const _ProductsTable({
    required this.products,
    required this.visibleColumns,
    required this.selectedIds,
    required this.allSelected,
    required this.onDelete,
    required this.onToggleSelect,
    required this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: _buildColumns(),
          rows: List.generate(products.length, (i) {
            final p = products[i];
            final selected = selectedIds.contains(p.id);
            return DataRow(
              selected: selected,
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary.withValues(alpha: 0.06);
                }
                return null;
              }),
              cells: _buildCells(context, p, i, selected),
            );
          }),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      // Sabit: Checkbox
      DataColumn(
        label: Checkbox(
          value: allSelected,
          tristate: selectedIds.isNotEmpty && !allSelected,
          onChanged: (_) => onToggleSelectAll(),
          activeColor: AppColors.primary,
        ),
      ),
      // Sabit: Sıra
      const DataColumn(label: Text('#')),
      // Sabit: Ürün Adı
      const DataColumn(label: Text('Ürün Adı')),
      // Dinamik kolonlar
      ...ProductColumn.values
          .where((c) => visibleColumns.contains(c))
          .map((c) => DataColumn(label: Text(c.label))),
      // Sabit: İşlem
      const DataColumn(label: Text('İşlem')),
    ];
  }

  List<DataCell> _buildCells(
      BuildContext context, Product p, int i, bool selected) {
    return [
      // Sabit: Checkbox
      DataCell(Checkbox(
        value: selected,
        onChanged: (_) => onToggleSelect(p.id),
        activeColor: AppColors.primary,
      )),
      // Sabit: Sıra
      DataCell(Text('${i + 1}',
          style: const TextStyle(color: AppColors.textMuted))),
      // Sabit: Ürün Adı
      DataCell(SizedBox(
        width: 220,
        child: Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      )),
      // Dinamik hücreler
      ...ProductColumn.values
          .where((c) => visibleColumns.contains(c))
          .map((c) => _buildCell(context, c, p)),
      // Sabit: İşlem
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => context.go('/products/${p.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.danger),
            onPressed: () => onDelete(p),
          ),
        ],
      )),
    ];
  }

  DataCell _buildCell(BuildContext context, ProductColumn col, Product p) {
    switch (col) {
      case ProductColumn.gorsel:
        return DataCell(p.imageUrl == null
            ? const Icon(Icons.image_not_supported_outlined,
                color: AppColors.textMuted, size: 22)
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(p.imageUrl!,
                    width: 32, height: 32, fit: BoxFit.cover),
              ));
      case ProductColumn.barkod:
        return DataCell(SelectableText(p.barcode ?? '-',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)));
      case ProductColumn.stokKodu:
        return DataCell(Text(p.stockCode ?? '-'));
      case ProductColumn.ustGrup:
        return DataCell(Text(p.parentGroupName ?? '-',
            style: const TextStyle(color: AppColors.textSecondary)));
      case ProductColumn.grupAdi:
        return DataCell(Text(p.groupName ?? '-',
            style: const TextStyle(color: AppColors.textSecondary)));
      case ProductColumn.stok:
        return DataCell(Text(p.stockQuantity.toString()));
      case ProductColumn.kritikStok:
        return DataCell(Text(p.criticalStock.toString()));
      case ProductColumn.birim:
        return DataCell(Text(p.unit));
      case ProductColumn.kdv:
        return DataCell(Text('%${p.vatRate}'));
      case ProductColumn.alis:
        return DataCell(Text(formatCurrency(p.purchasePrice)));
      case ProductColumn.fiyat1:
        return DataCell(Text(formatCurrency(p.price1),
            style: const TextStyle(fontWeight: FontWeight.w600)));
      case ProductColumn.fiyat2:
        return DataCell(Text(formatCurrency(p.price2)));
    }
  }
}

// ── Mobil ürün kartı ──────────────────────────────────────────────────────────
//
// Sol: ürün adı (üst) + barkod (alt)
// Sağ: Stok · Alış · Fiyat 1

class _ProductMobileCard extends StatelessWidget {
  final Product product;
  final Future<void> Function(Product) onDelete;

  const _ProductMobileCard({required this.product, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onTap: () => context.go('/products/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sol: ad + barkod
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    p.barcode ?? '-',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sağ: üç değer sütunu
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoChip(label: 'Stok', value: p.stockQuantity.toString()),
                const SizedBox(height: 3),
                _InfoChip(label: 'Alış', value: formatCurrency(p.purchasePrice)),
                const SizedBox(height: 3),
                _InfoChip(
                  label: 'Fiyat',
                  value: formatCurrency(p.price1),
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoChip({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            color: highlight ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
