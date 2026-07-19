import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/product.dart';
import '../../data/models/product_filters.dart';
import '../../data/models/equivalent_aggregate.dart';
import '../../application/product_columns_provider.dart';
import '../../application/products_provider.dart';
import '../widgets/excel_import_dialog.dart';
import '../widgets/excel_export.dart';
import '../../../sales/presentation/widgets/barcode_scanner_modal.dart';

// ── Sağ üst köşe bildirimi (2sn otomatik kaybolur) ─────────────────────────────
// `SnackBar` varsayılan olarak alt köşede çıkar; "Ürün güncellendi" bildirimi
// için sağ üstte kısa ömürlü bir `OverlayEntry` kullanılır (bu ekrana özgü,
// başka yerde ihtiyaç doğarsa `core/widgets`'a taşınabilir).
void _showTopRightToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: AppSizes.space16 + MediaQuery.of(ctx).padding.top,
      right: AppSizes.space16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space16, vertical: AppSizes.space12),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: AppSizes.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: AppSizes.space8),
              Text(message,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () {
    if (entry.mounted) entry.remove();
  });
}

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

  // Sütun başlığı filtre ikonlarından doldurulur (bkz. _ProductsTable).
  // Mutable — Liste Gir'deki ExtractedRow ile aynı desen.
  final ProductFilters _filters = ProductFilters();

  // Sütun başlığına dokununca sıralama (Ürün Adı A-Z/Z-A, sayısal sütunlar
  // büyükten küçüğe/küçükten büyüğe) — server-side (bkz. ProductRepository
  // sortColumn/sortAscending), sayfalamayla doğru çalışsın diye.
  String _sortColumn = 'name';
  bool _sortAscending = true;

  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selectedIds = {};

  // Ürün başına "Durum" (Çok Satan/Tükendi/Pasif) — bkz. `_loadStatuses`.
  Map<String, String?> _statuses = {};

  // Eşlenik Barkod: ürün başına grup toplamı — bkz. `_loadEquivalents`.
  // Yalnız bir gruba ait ürünler burada anahtar içerir (bkz. 0021 migration).
  Map<String, EquivalentAggregate> _equivalents = {};

  // Arama kutusu debounce'u (250ms) — projedeki diğer canlı aramalarla aynı
  // desen (bkz. sales_screen.dart `_LiveProductSearchField`). Durum sütunu
  // eklendiğinden beri her yükleme 2 ardışık sorgu attığı için (ürünler +
  // durum), debounce OLMADAN her tuş vuruşu bu maliyeti tekrarlardı.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() { _query = v; _page = 0; _products = []; });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _loadProducts);
  }

  // Sütun başlığı filtre dialoglarından çağrılır — `mutate` ilgili alan(lar)ı
  // değiştirir, sayfa sıfırlanıp sunucudan yeniden yüklenir (server-side
  // filtre: sayfalama ile birlikte doğru çalışması için `fetchPaged`
  // sorgusunun bir parçası — yalnız o an yüklü sayfayı süzmek YANLIŞ olurdu).
  void _applyFilterChange(void Function(ProductFilters) mutate) {
    setState(() {
      mutate(_filters);
      _page = 0;
      _products = [];
    });
    _loadProducts();
  }

  // Sütun başlığına dokununca çağrılır (bkz. _ProductsTable onSort).
  void _onSortChanged(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _page = 0;
      _products = [];
    });
    _loadProducts();
  }

  void _clearAllFilters() {
    _applyFilterChange((f) {
      f.barcode = null;
      f.stockCode = null;
      f.unit = null;
      f.groupName = null;
      f.parentGroupName = null;
      f.stockMin = null;
      f.stockMax = null;
      f.criticalStockMin = null;
      f.criticalStockMax = null;
      f.vatMin = null;
      f.vatMax = null;
      f.purchaseMin = null;
      f.purchaseMax = null;
      f.price1Min = null;
      f.price1Max = null;
      f.price2Min = null;
      f.price2Max = null;
      f.status = null;
    });
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
            filters: _filters,
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            page: _page,
            pageSize: kProductPageSize,
          );
      if (!mounted) return;
      setState(() {
        _products = rows;
        _loading = false;
      });
      _loadStatuses();
      _loadEquivalents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // "Durum" bilgisini o an listelenen ürünler için ayrıca çeker (ana ürün
  // sorgusunu yavaşlatmamak için — bkz. `ProductRepository.fetchStatuses`).
  Future<void> _loadStatuses() async {
    final ids = _products.map((p) => p.id).toList();
    try {
      final statuses = await ref.read(productRepositoryProvider).fetchStatuses(ids);
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (_) {
      // Durum bilgisi ikincil — sessizce yoksay, liste yine gösterilir.
    }
  }

  // Eşlenik Barkod grup toplamlarını o an listelenen ürünler için ayrıca
  // çeker (bkz. `_loadStatuses` ile aynı desen — ana ürün sorgusunu yavaşlatmaz).
  Future<void> _loadEquivalents() async {
    final ids = _products.map((p) => p.id).toList();
    try {
      final equivalents =
          await ref.read(productRepositoryProvider).fetchEquivalentAggregates(ids);
      if (!mounted) return;
      setState(() => _equivalents = equivalents);
    } catch (_) {
      // Agregat bilgisi ikincil — sessizce yoksay, liste yine gösterilir.
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
        filters: _filters,
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
          SnackBar(backgroundColor: AppColors.danger, content: Text(msg)));
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
      backgroundColor: skipped > 0 ? AppColors.danger : null,
    ));
  }

  // ── Satır içi güncelleme (tablodan doğrudan düzenleme) ──────────────────────

  Future<void> _updateProduct(Product updated) async {
    await ref.read(productRepositoryProvider).update(updated.id, updated);
    if (!mounted) return;
    setState(() {
      final idx = _products.indexWhere((x) => x.id == updated.id);
      if (idx != -1) _products[idx] = updated;
    });
    _showTopRightToast(context, 'Ürün güncellendi');
    // Stok/fiyat değişimi Durum'u etkileyebilir (Tükendi/Pasif) → tazele.
    _loadStatuses();
    // Eşlenik Barkod: bu satır bir gruptaysa, düzenleme onu grubun en son
    // güncellenen (dolayısıyla "esas" fiyatı belirleyen) satırı yapmış olabilir.
    // _equivalents cache'i tazelenmezse Fiyat 1/Stok hücreleri (agg.groupPrice1
    // üzerinden gösterilir) yeniden aratılana kadar eski değeri göstermeye devam eder.
    if (updated.equivalentGroupId != null) _loadEquivalents();
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
            Text('Ürünler', style: Theme.of(context).textTheme.titleLarge),
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
        const SizedBox(height: AppSizes.space12),
        // Arama
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Ürün adı, barkod, stok kodu...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            // Kamera ile barkod okutma — yalnızca mobil + native
            // (web'de kamera modalı açılamaz, masaüstünde gizli).
            suffixIcon: (!kIsWeb && context.isMobile)
                ? IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    color: AppColors.primary,
                    tooltip: 'Barkod tara',
                    onPressed: () => openBarcodeScanner(context, (value) {
                      _searchController.text = value.trim();
                      setState(() {
                        _query = value.trim();
                        _page = 0;
                        _products = [];
                      });
                      _loadProducts();
                    }),
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: AppSizes.space8),
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
        const SizedBox(height: AppSizes.space8),
        // Liste
        Expanded(
          child: _loading && _products.isEmpty
              ? const SkeletonList(itemCount: 8)
              : _error != null
                  ? Center(child: Text('Hata: $_error'))
                  : _displayProducts.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Ürün bulunamadı',
                          message: 'Aramanızı değiştirin veya yeni ürün ekleyin',
                        )
                      : ListView.separated(
                          itemCount: _displayProducts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ProductMobileCard(
                            product: _displayProducts[i],
                            onDelete: _deleteProduct,
                            equivalent: _equivalents[_displayProducts[i].id],
                            onEquivalentChanged: _loadProducts,
                          ),
                        ),
        ),
        const SizedBox(height: AppSizes.space8),
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
            Text('Ürünler', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                final all = await ref.read(productRepositoryProvider).fetchAll(
                      query: _query, groupId: _selectedGroupId, filters: _filters,
                      sortColumn: _sortColumn, sortAscending: _sortAscending);
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
            const SizedBox(width: AppSizes.space8),
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
            const SizedBox(width: AppSizes.space8),
            ElevatedButton.icon(
              onPressed: () => context.go('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Ürün'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
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
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
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
            const SizedBox(width: AppSizes.space12),
            OutlinedButton.icon(
              onPressed: _showColumnPicker,
              icon: const Icon(Icons.view_column_outlined, size: 18),
              label: Text('Kolonlar (${ref.watch(productColumnsProvider).length})'),
            ),
            const SizedBox(width: AppSizes.space12),
            OutlinedButton.icon(
              onPressed: _showSummary,
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('Ürün Özet'),
            ),
            if (!_filters.isEmpty) ...[
              const SizedBox(width: AppSizes.space12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.space8, vertical: AppSizes.space4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.filter_alt, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSizes.space4),
                  const Text('Sütun filtresi aktif', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(width: AppSizes.space4),
                  InkWell(
                    onTap: _clearAllFilters,
                    child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                  ),
                ]),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: selCount > 0
              ? Container(
                  key: const ValueKey('selection-bar'),
                  margin: const EdgeInsets.only(bottom: AppSizes.space8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space16, vertical: AppSizes.space8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box, color: AppColors.primary, size: 18),
                      const SizedBox(width: AppSizes.space8),
                      Text('$selCount ürün seçildi',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedIds.clear()),
                        child: const Text('Seçimi Temizle'),
                      ),
                      const SizedBox(width: AppSizes.space8),
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
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppSizes.cardDecoration(),
            child: _loading && _products.isEmpty
                ? const SkeletonList(itemCount: 10)
                : _error != null
                    ? Center(child: Text('Hata: $_error'))
                    : _displayProducts.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Ürün bulunamadı',
                            message: 'Aramanızı değiştirin veya yeni ürün ekleyin',
                          )
                        : _ProductsTable(
                            products: _displayProducts,
                            visibleColumns: ref.watch(productColumnsProvider),
                            selectedIds: _selectedIds,
                            allSelected: _allSelected,
                            statuses: _statuses,
                            equivalents: _equivalents,
                            onEquivalentChanged: _loadProducts,
                            filters: _filters,
                            onFilterApply: _applyFilterChange,
                            sortColumn: _sortColumn,
                            sortAscending: _sortAscending,
                            onSortChanged: _onSortChanged,
                            onDelete: _deleteProduct,
                            onUpdate: _updateProduct,
                            onToggleSelect: _toggleSelect,
                            onToggleSelectAll: _toggleSelectAll,
                          ),
          ),
        ),
        const SizedBox(height: AppSizes.space8),
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
        const SizedBox(width: AppSizes.space16),
        Text('Sayfa ${_page + 1}',
            style: const TextStyle(
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: AppSizes.space16),
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
          const SizedBox(width: AppSizes.space8),
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
  final ProductFilters filters;

  const _ProductSummaryDialog({required this.query, this.groupId, required this.filters});

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
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.fetchAll(
            query: widget.query,
            groupId: widget.groupId,
            filters: widget.filters,
          );
      // Eşlenik Barkod: gruplu ürünler Ürün Özet'te TEKİL sayılır (grubun
      // toplam stoğu + en-son-satır fiyatı, çift sayım YOK) — bkz.
      // 0021_equivalent_barcodes.sql. Grupsuz ürünler eskisi gibi kendi
      // ham değerleriyle sayılır.
      final ids = products.map((p) => p.id).toList();
      final aggregates = await repo.fetchEquivalentAggregates(ids);
      final countedGroups = <String>{};
      int count = 0;
      num quantity = 0, cost = 0, sales = 0;
      for (final p in products) {
        final agg = aggregates[p.id];
        if (agg == null) {
          quantity += p.stockQuantity;
          cost += p.purchasePrice * p.stockQuantity;
          sales += p.price1 * p.stockQuantity;
          count++;
        } else if (countedGroups.add(p.equivalentGroupId!)) {
          quantity += agg.totalStock;
          cost += agg.groupPurchasePrice * agg.totalStock;
          sales += agg.groupPrice1 * agg.totalStock;
          count++;
        }
      }
      if (!mounted) return;
      setState(() {
        _count = count;
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
      margin: const EdgeInsets.only(bottom: AppSizes.space8),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12, vertical: AppSizes.space12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSizes.space8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// Durum filtre dialogunda "Tümü" (value=null) seçimini "dialog kapatıldı,
// hiçbir şey seçilmedi" (showDialog'un doğal null dönüşü) durumundan ayırt
// etmek için ince bir sarmalayıcı.
class _StatusChoice {
  final String? value;
  const _StatusChoice(this.value);
}

// ── Dinamik Tablo ─────────────────────────────────────────────────────────────

class _ProductsTable extends StatefulWidget {
  final List<Product> products;
  final Set<ProductColumn> visibleColumns;
  final Set<String> selectedIds;
  final bool allSelected;
  final Map<String, String?> statuses;
  final Map<String, EquivalentAggregate> equivalents;
  final VoidCallback onEquivalentChanged;
  final ProductFilters filters;
  final void Function(void Function(ProductFilters)) onFilterApply;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String column, bool ascending) onSortChanged;
  final Future<void> Function(Product) onDelete;
  final Future<void> Function(Product) onUpdate;
  final void Function(String id) onToggleSelect;
  final VoidCallback onToggleSelectAll;

  const _ProductsTable({
    required this.products,
    required this.visibleColumns,
    required this.selectedIds,
    required this.allSelected,
    required this.statuses,
    required this.equivalents,
    required this.onEquivalentChanged,
    required this.filters,
    required this.onFilterApply,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortChanged,
    required this.onDelete,
    required this.onUpdate,
    required this.onToggleSelect,
    required this.onToggleSelectAll,
  });

  @override
  State<_ProductsTable> createState() => _ProductsTableState();
}

/// Satır başına düzenlenebilir alanların denetleyicileri (ad/stok/alış/fiyat1).
/// Kaydedilmemiş kullanıcı girdisini tutar; "Güncelle"ye basılana kadar
/// sunucuya YAZILMAZ.
class _RowControllers {
  final TextEditingController name;
  final TextEditingController stock;
  final TextEditingController purchase;
  final TextEditingController price1;

  _RowControllers(Product p)
      : name = TextEditingController(text: p.name),
        stock = TextEditingController(text: _fmtNum(p.stockQuantity)),
        purchase = TextEditingController(text: _fmtNum(p.purchasePrice)),
        price1 = TextEditingController(text: _fmtNum(p.price1));

  void dispose() {
    name.dispose();
    stock.dispose();
    purchase.dispose();
    price1.dispose();
  }
}

String _fmtNum(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

num? _parseNum(String s) => num.tryParse(s.trim().replaceAll(',', '.'));

final _decimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  TextInputFormatter.withFunction(
    (o, n) => RegExp(r'[.,]').allMatches(n.text).length > 1 ? o : n,
  ),
];

class _ProductsTableState extends State<_ProductsTable> {
  final Map<String, _RowControllers> _rowCtrls = {};
  final Set<String> _savingIds = {};

  // Yalnız DOKUNULAN satır düzenleme moduna geçer (performans: `DataTable`
  // sanallaştırma yapmadığı için sayfadaki TÜM satırları her zaman canlı
  // `TextField` yapmak (50 satır × 4 hane) ilk açılışı gözle görülür
  // yavaşlatıyordu. Artık varsayılan görünüm ucuz `Text`; bir hücreye
  // dokunulunca YALNIZ o satır için kontrolcü kurulur ve `TextField`'a döner.
  final Set<String> _editingIds = {};

  _RowControllers _ctrlsFor(Product p) =>
      _rowCtrls.putIfAbsent(p.id, () => _RowControllers(p));

  void _enterEdit(Product p) {
    setState(() {
      _ctrlsFor(p); // kontrolcüleri GÜNCEL ürün değerleriyle kur
      _editingIds.add(p.id);
    });
  }

  void _exitEdit(String id) {
    setState(() {
      _editingIds.remove(id);
      _rowCtrls.remove(id)?.dispose();
    });
  }

  @override
  void didUpdateWidget(covariant _ProductsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sayfa/arama/filtre değişince artık listede olmayan satırların
    // kontrolcülerini temizle (bellek sızıntısı olmasın). Hâlâ listede olan
    // satırlar dokunulmaz — kaydedilmemiş kullanıcı girdisi korunur.
    final currentIds = widget.products.map((p) => p.id).toSet();
    final stale = _rowCtrls.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in stale) {
      _rowCtrls.remove(id)?.dispose();
      _editingIds.remove(id);
    }
  }

  @override
  void dispose() {
    for (final c in _rowCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onGuncelle(Product p) async {
    // Enter tuşu / satır dışına tıklama gibi birden fazla tetikleyici aynı
    // anda ateşleyebilir (bkz. _cell — her hane kendi TapRegion.onTapOutside'ı
    // ile çağırır) — satır zaten kapandıysa veya kayıt sürüyorsa yinelenen
    // çağrıyı sessizce yoksay.
    if (!_editingIds.contains(p.id) || _savingIds.contains(p.id)) return;
    final ctrls = _ctrlsFor(p);
    final name = ctrls.name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün adı boş olamaz')));
      return;
    }
    final updated = p.copyWith(
      name: name,
      stockQuantity: _parseNum(ctrls.stock.text) ?? p.stockQuantity,
      purchasePrice: _parseNum(ctrls.purchase.text) ?? p.purchasePrice,
      price1: _parseNum(ctrls.price1.text) ?? p.price1,
    );
    setState(() => _savingIds.add(p.id));
    try {
      await widget.onUpdate(updated);
      if (mounted) _exitEdit(p.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('"${p.name}" güncellenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          // Sütunlar arası boşluk yarıya indirildi (varsayılan 56 → 28) ve
          // hücre fontu bir kademe küçültüldü (tema varsayılanı 13 → 12) —
          // sidebar daralmasıyla birlikte tablonun ekrana sığması için.
          columnSpacing: 28,
          dataTextStyle: const TextStyle(fontSize: 12),
          // Tablo başlığı: altın zemin (token §5) + type.utility
          headingRowColor: WidgetStateProperty.all(AppColors.goldBg),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
          sortColumnIndex: _sortColumnIndex,
          sortAscending: widget.sortAscending,
          columns: _buildColumns(),
          rows: List.generate(widget.products.length, (i) {
            final p = widget.products[i];
            final selected = widget.selectedIds.contains(p.id);
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
          value: widget.allSelected,
          tristate: widget.selectedIds.isNotEmpty && !widget.allSelected,
          onChanged: (_) => widget.onToggleSelectAll(),
          activeColor: AppColors.primary,
        ),
      ),
      // Sabit: Durum (Çok Satan / Tükendi / Pasif) — filtrelenebilir (dropdown).
      DataColumn(
        label: _headerWithFilter(
          context,
          'Durum',
          active: widget.filters.status != null,
          onTap: () => _showStatusFilterDialog(context),
        ),
      ),
      // Sabit: Sıra
      const DataColumn(label: Text('#')),
      // Sabit: Ürün Adı — alfabetik sıralanabilir (A-Z / Z-A).
      DataColumn(
        label: const Text('Ürün Adı'),
        onSort: (columnIndex, ascending) => widget.onSortChanged('name', ascending),
      ),
      // Dinamik kolonlar — sayısal olanlar sağa dayalı (tarama kolaylığı),
      // her biri (Görsel hariç) sütun başlığında filtre ikonu taşır; sayısal
      // olanlar + Barkod ayrıca sıralanabilir (bkz. _dbColumnFor).
      ...ProductColumn.values
          .where((c) => widget.visibleColumns.contains(c))
          .map((c) => DataColumn(
                label: c == ProductColumn.gorsel
                    ? Text(c.label)
                    : _headerWithFilter(
                        context,
                        c.label,
                        active: _isColumnFilterActive(c),
                        onTap: () => _showColumnFilterDialog(context, c),
                      ),
                numeric: _isNumericColumn(c),
                onSort: _dbColumnFor(c) == null
                    ? null
                    : (columnIndex, ascending) => widget.onSortChanged(_dbColumnFor(c)!, ascending),
              )),
      // Sabit: İşlem
      const DataColumn(label: Text('İşlem')),
    ];
  }

  // Sıralanabilir sütun → gerçek `products` sütun adı (bkz.
  // ProductRepository.sortableColumns). null = sıralanamaz (Görsel, Stok
  // Kodu, Üst Grup, Grup Adı, Birim — kapsam dışı, istenirse eklenir).
  static String? _dbColumnFor(ProductColumn c) {
    switch (c) {
      case ProductColumn.barkod:
        return 'barcode';
      case ProductColumn.stok:
        return 'stock_quantity';
      case ProductColumn.kritikStok:
        return 'critical_stock';
      case ProductColumn.kdv:
        return 'vat_rate';
      case ProductColumn.alis:
        return 'purchase_price';
      case ProductColumn.fiyat1:
        return 'price1';
      case ProductColumn.fiyat2:
        return 'price2';
      case ProductColumn.gorsel:
      case ProductColumn.stokKodu:
      case ProductColumn.ustGrup:
      case ProductColumn.grupAdi:
      case ProductColumn.birim:
        return null;
    }
  }

  // `widget.sortColumn`'a karşılık gelen DataColumn indeksi — sabit
  // kolonlar 0-3 (checkbox/durum/#/ürün adı), dinamik kolonlar 4'ten başlar.
  int? get _sortColumnIndex {
    if (widget.sortColumn == 'name') return 3;
    final dynamicCols = ProductColumn.values.where((c) => widget.visibleColumns.contains(c)).toList();
    final idx = dynamicCols.indexWhere((c) => _dbColumnFor(c) == widget.sortColumn);
    return idx == -1 ? null : 4 + idx;
  }

  // Başlık metni + küçük filtre ikonu; aktif filtreli sütunlarda ikon
  // vurgulanır (dolu + primary renk).
  Widget _headerWithFilter(BuildContext context, String label, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 3),
        Icon(
          active ? Icons.filter_alt : Icons.filter_alt_outlined,
          size: 13,
          color: active ? AppColors.primary : AppColors.textMuted,
        ),
      ]),
    );
  }

  bool _isColumnFilterActive(ProductColumn c) {
    final f = widget.filters;
    switch (c) {
      case ProductColumn.gorsel:
        return false;
      case ProductColumn.barkod:
        return f.barcode != null;
      case ProductColumn.stokKodu:
        return f.stockCode != null;
      case ProductColumn.ustGrup:
        return f.parentGroupName != null;
      case ProductColumn.grupAdi:
        return f.groupName != null;
      case ProductColumn.birim:
        return f.unit != null;
      case ProductColumn.stok:
        return f.stockMin != null || f.stockMax != null;
      case ProductColumn.kritikStok:
        return f.criticalStockMin != null || f.criticalStockMax != null;
      case ProductColumn.kdv:
        return f.vatMin != null || f.vatMax != null;
      case ProductColumn.alis:
        return f.purchaseMin != null || f.purchaseMax != null;
      case ProductColumn.fiyat1:
        return f.price1Min != null || f.price1Max != null;
      case ProductColumn.fiyat2:
        return f.price2Min != null || f.price2Max != null;
    }
  }

  Future<void> _showColumnFilterDialog(BuildContext context, ProductColumn c) async {
    final f = widget.filters;
    switch (c) {
      case ProductColumn.gorsel:
        return;
      case ProductColumn.barkod:
        // Barkod "içerir" değil BİREBİR eşleşme — "002" yazınca yalnız
        // barkodu tam olarak "002" olan ürün gelsin, "8698...002..." gibi
        // içinde 002 geçen tüm barkodlar DEĞİL (kullanıcı isteği).
        return _showTextFilterDialog(context,
            title: c.label, currentValue: f.barcode, hint: 'Tam barkod (birebir eşleşme)...',
            apply: (v) => (f) => f.barcode = v);
      case ProductColumn.stokKodu:
        return _showTextFilterDialog(context, title: c.label, currentValue: f.stockCode, apply: (v) => (f) => f.stockCode = v);
      case ProductColumn.ustGrup:
        return _showTextFilterDialog(context, title: c.label, currentValue: f.parentGroupName, apply: (v) => (f) => f.parentGroupName = v);
      case ProductColumn.grupAdi:
        return _showTextFilterDialog(context, title: c.label, currentValue: f.groupName, apply: (v) => (f) => f.groupName = v);
      case ProductColumn.birim:
        return _showTextFilterDialog(context, title: c.label, currentValue: f.unit, apply: (v) => (f) => f.unit = v);
      case ProductColumn.stok:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.stockMin, currentMax: f.stockMax,
            apply: (min, max) => (f) { f.stockMin = min; f.stockMax = max; });
      case ProductColumn.kritikStok:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.criticalStockMin, currentMax: f.criticalStockMax,
            apply: (min, max) => (f) { f.criticalStockMin = min; f.criticalStockMax = max; });
      case ProductColumn.kdv:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.vatMin, currentMax: f.vatMax,
            apply: (min, max) => (f) { f.vatMin = min; f.vatMax = max; });
      case ProductColumn.alis:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.purchaseMin, currentMax: f.purchaseMax,
            apply: (min, max) => (f) { f.purchaseMin = min; f.purchaseMax = max; });
      case ProductColumn.fiyat1:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.price1Min, currentMax: f.price1Max,
            apply: (min, max) => (f) { f.price1Min = min; f.price1Max = max; });
      case ProductColumn.fiyat2:
        return _showRangeFilterDialog(context,
            title: c.label, currentMin: f.price2Min, currentMax: f.price2Max,
            apply: (min, max) => (f) { f.price2Min = min; f.price2Max = max; });
    }
  }

  // Metin filtresi (Stok Kodu, Birim, Üst Grup, Grup Adı: "içerir"; Barkod:
  // birebir eşleşme — `hint` ile ayırt edilir).
  Future<void> _showTextFilterDialog(
    BuildContext context, {
    required String title,
    required String? currentValue,
    required void Function(ProductFilters) Function(String?) apply,
    String hint = 'İçerir...',
  }) async {
    final ctrl = TextEditingController(text: currentValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Filtrele'),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          if (currentValue != null)
            TextButton(onPressed: () => Navigator.of(ctx).pop(''), child: const Text('Temizle')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Uygula')),
        ],
      ),
    );
    if (result == null) return; // Vazgeç
    final trimmed = result.trim();
    widget.onFilterApply(apply(trimmed.isEmpty ? null : trimmed));
  }

  // Min/Maks sayısal aralık filtresi (Stok, Kritik Stok, KDV, Alış, Fiyat 1/2).
  Future<void> _showRangeFilterDialog(
    BuildContext context, {
    required String title,
    required num? currentMin,
    required num? currentMax,
    required void Function(ProductFilters) Function(num?, num?) apply,
  }) async {
    final minCtrl = TextEditingController(text: currentMin?.toString() ?? '');
    final maxCtrl = TextEditingController(text: currentMax?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Filtrele'),
        content: SizedBox(
          width: 260,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Min'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                decoration: const InputDecoration(labelText: 'Maks'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
          ]),
        ),
        actions: [
          if (currentMin != null || currentMax != null)
            TextButton(
              onPressed: () {
                minCtrl.clear();
                maxCtrl.clear();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Temizle'),
            ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Uygula')),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onFilterApply(apply(_parseNum(minCtrl.text), _parseNum(maxCtrl.text)));
  }

  // Durum: sabit kısa seçenek listesi → basit seçim dialogu (dropdown yerine
  // — bu dosyadaki diğer dialoglarla aynı `showDialog` deseni).
  Future<void> _showStatusFilterDialog(BuildContext context) async {
    const options = <(String?, String)>[
      (null, 'Tümü'),
      ('cok_satan', 'Çok Satan'),
      ('tukendi', 'Tükendi'),
      ('pasif', 'Pasif'),
      ('bos', 'Boş (durum yok)'),
    ];
    final current = widget.filters.status;
    final result = await showDialog<_StatusChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Durum Filtrele'),
        children: [
          for (final (value, label) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(_StatusChoice(value)),
              child: Row(children: [
                Icon(
                  current == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16,
                  color: current == value ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSizes.space8),
                Text(label),
              ]),
            ),
        ],
      ),
    );
    if (result == null) return; // Vazgeç (dışarı tıklandı)
    widget.onFilterApply((f) => f.status = result.value);
  }

  // Stok/fiyat/oran kolonları rakamdır → sağa dayalı + tabular hizalama.
  static bool _isNumericColumn(ProductColumn c) {
    switch (c) {
      case ProductColumn.stok:
      case ProductColumn.kritikStok:
      case ProductColumn.kdv:
      case ProductColumn.alis:
      case ProductColumn.fiyat1:
      case ProductColumn.fiyat2:
        return true;
      case ProductColumn.gorsel:
      case ProductColumn.barkod:
      case ProductColumn.stokKodu:
      case ProductColumn.ustGrup:
      case ProductColumn.grupAdi:
      case ProductColumn.birim:
        return false;
    }
  }

  List<DataCell> _buildCells(
      BuildContext context, Product p, int i, bool selected) {
    final saving = _savingIds.contains(p.id);
    final editing = _editingIds.contains(p.id);
    return [
      // Sabit: Checkbox
      DataCell(Checkbox(
        value: selected,
        onChanged: (_) => widget.onToggleSelect(p.id),
        activeColor: AppColors.primary,
      )),
      // Sabit: Durum (Çok Satan / Tükendi / Pasif)
      DataCell(_StatusBadge(status: widget.statuses[p.id])),
      // Sabit: Sıra
      DataCell(Text('${i + 1}',
          style: const TextStyle(color: AppColors.textMuted))),
      // Ürün Adı — dokununca düzenlenebilir (eski genişliğin 2 katı + 2cm, 220→516).
      // Eşlenik Barkod grubu varsa yanında kırmızı "!" ikonu (bkz. _EquivalentBarcodeDialog).
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(
            p,
            width: widget.equivalents.containsKey(p.id) ? 490 : 516,
            bold: true,
            controllerOf: (c) => c.name,
            displayText: () => p.name,
          ),
          if (widget.equivalents.containsKey(p.id))
            IconButton(
              icon: const Icon(Icons.error, color: AppColors.danger, size: 18),
              tooltip: 'Eşlenik barkod var',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _EquivalentBarcodeDialog(
                  groupId: p.equivalentGroupId!,
                  onChanged: widget.onEquivalentChanged,
                ),
              ),
            ),
        ],
      )),
      // Dinamik hücreler
      ...ProductColumn.values
          .where((c) => widget.visibleColumns.contains(c))
          .map((c) => _buildCell(context, c, p)),
      // Sabit: İşlem (Düzenle · [düzenleniyorsa] Güncelle/Vazgeç · Sil)
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: 'Düzenle',
            onPressed: () => context.go('/products/${p.id}'),
          ),
          if (editing)
            // Aynı satırın düzenlenebilir haneleriyle AYNI TapRegion grubunda
            // (bkz. _cell) — aksi halde bu butonlara tıklamak da "satır dışına
            // tıklama" sayılıp onTapOutside'ı gereksiz/çakışan şekilde tetikler.
            TapRegion(
              groupId: p.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  saving
                      ? const Padding(
                          padding: EdgeInsets.all(AppSizes.space8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18, color: AppColors.success),
                          tooltip: 'Güncelle',
                          onPressed: () => _onGuncelle(p),
                        ),
                  if (!saving)
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textMuted),
                      tooltip: 'Vazgeç',
                      onPressed: () => _exitEdit(p.id),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.danger),
            tooltip: 'Sil',
            onPressed: () => widget.onDelete(p),
          ),
        ],
      )),
    ];
  }

  // Satır DÜZENLENMİYORSA ucuz salt-okunur `Text` (dokununca düzenlemeye
  // geçer); DÜZENLENİYORSA canlı `TextField`. Genişlik iki modda da AYNI
  // tutulur ki dokunma anında sütun genişliği zıplamasın.
  Widget _cell(
    Product p, {
    required double width,
    required TextEditingController Function(_RowControllers) controllerOf,
    required String Function() displayText,
    bool bold = false,
    bool numeric = false,
  }) {
    if (_editingIds.contains(p.id)) {
      // Aynı satırın tüm haneleri (+ Güncelle/Vazgeç butonları, bkz.
      // _buildCells) AYNI groupId ile TapRegion'a sarılır — Enter'a basmak
      // VEYA bu grubun DIŞINDA bir yere (başka bir ürünün hanesi, boş alan)
      // tıklamak satırı otomatik kaydedip kapatır (_onGuncelle zaten
      // yinelenen çağrılara karşı korumalı).
      return TapRegion(
        groupId: p.id,
        onTapOutside: (_) => _onGuncelle(p),
        child: _editableField(controllerOf(_ctrlsFor(p)),
            width: width,
            bold: bold,
            numeric: numeric,
            onSubmit: () => _onGuncelle(p)),
      );
    }
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _enterEdit(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.space6),
          child: Text(
            displayText(),
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            maxLines: numeric ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontFeatures:
                  numeric ? const [FontFeature.tabularFigures()] : null,
            ),
          ),
        ),
      ),
    );
  }

  // Düzenleme moduna geçmiş bir satır için canlı metin alanı.
  Widget _editableField(TextEditingController ctrl,
      {required double width,
      bool bold = false,
      bool numeric = false,
      required VoidCallback onSubmit}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        autofocus: true,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric ? _decimalInputFormatters : null,
        onSubmitted: (_) => onSubmit(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          fontFeatures:
              numeric ? const [FontFeature.tabularFigures()] : null,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: AppSizes.space6),
        ),
      ),
    );
  }

  DataCell _buildCell(BuildContext context, ProductColumn col, Product p) {
    switch (col) {
      case ProductColumn.gorsel:
        return DataCell(p.imageUrl == null
            ? const Icon(Icons.image_not_supported_outlined,
                color: AppColors.textMuted, size: 22)
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: Image.network(p.imageUrl!,
                    width: 32, height: 32, fit: BoxFit.cover),
              ));
      case ProductColumn.barkod:
        return DataCell(SelectableText(p.barcode ?? '-',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)));
      case ProductColumn.stokKodu:
        return DataCell(Text(p.stockCode ?? '-'));
      case ProductColumn.ustGrup:
        return DataCell(Text(p.parentGroupName ?? '-',
            style: const TextStyle(color: AppColors.textSecondary)));
      case ProductColumn.grupAdi:
        return DataCell(Text(p.groupName ?? '-',
            style: const TextStyle(color: AppColors.textSecondary)));
      case ProductColumn.stok:
        // Dokununca düzenlenebilir (kritik stok rozeti bu haneden kalktı —
        // düzenlenebilir metin alanıyla birlikte sürmüyor). Eşlenik barkod
        // grubundaysa "kendi_stok(grup_toplamı)" formatında gösterilir —
        // düzenleme modu hâlâ ham p.stockQuantity üzerinden çalışır.
        return DataCell(_cell(
          p,
          width: 80,
          numeric: true,
          controllerOf: (c) => c.stock,
          displayText: () {
            final agg = widget.equivalents[p.id];
            if (agg == null) return formatNumber(p.stockQuantity);
            return '${formatNumber(p.stockQuantity)}(${formatNumber(agg.totalStock)})';
          },
        ));
      case ProductColumn.kritikStok:
        return DataCell(Text(formatNumber(p.criticalStock),
            style: _kTabularMuted));
      case ProductColumn.birim:
        return DataCell(Text(p.unit));
      case ProductColumn.kdv:
        return DataCell(Text('%${p.vatRate}', style: _kTabular));
      case ProductColumn.alis:
        return DataCell(_cell(
          p,
          width: 90,
          numeric: true,
          controllerOf: (c) => c.purchase,
          displayText: () => formatCurrency(p.purchasePrice),
        ));
      case ProductColumn.fiyat1:
        // Eşlenik barkod grubundaysa grup için "esas" fiyat (en son güncellenen
        // satır) gösterilir; düzenleme modu hâlâ ham p.price1 üzerinden çalışır.
        return DataCell(_cell(
          p,
          width: 90,
          numeric: true,
          bold: true,
          controllerOf: (c) => c.price1,
          displayText: () {
            final agg = widget.equivalents[p.id];
            return formatCurrency(agg?.groupPrice1 ?? p.price1);
          },
        ));
      case ProductColumn.fiyat2:
        return DataCell(Text(formatCurrency(p.price2), style: _kTabular));
    }
  }
}

// Tablo/çip rakamları için tabular (hizalı) figür stilleri (§2).
const _kTabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
const _kTabularMuted = TextStyle(
  color: AppColors.textSecondary,
  fontFeatures: [FontFeature.tabularFigures()],
);

// ── Durum rozeti (Çok Satan / Tükendi / Pasif) ───────────────────────────────
// Öncelik sırası sunucuda (`product_status` view) belirlenir: Çok Satan >
// Tükendi > Pasif > (boş). Burada yalnız gelen `status` değeri gösterilir.
class _StatusBadge extends StatelessWidget {
  final String? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      'cok_satan' => ('Çok Satan', AppColors.success),
      'tukendi' => ('Tükendi', AppColors.danger),
      'pasif' => ('Pasif', AppColors.textMuted),
      _ => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    // Mümkün olduğunca dar: metne yapışık minimum dolgu (yalnız "ÇOK SATAN"
    // okunacak kadar), sütun genişliğini bu rozetin içeriği belirler.
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space6, vertical: AppSizes.space2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ── Eşlenik Barkod grup dialogu ───────────────────────────────────────────────
//
// Ürünler listesindeki kırmızı "!" ikonuna (Ürün Adı yanında, masaüstü + mobil)
// tıklanınca açılır — grubun tüm üyelerini (barkod, ad, stok, fiyat, güncelleme
// tarihi) listeler, en son güncellenen "Esas" rozetiyle işaretlenir (bkz.
// 0021_equivalent_barcodes.sql — fiyat/KDV bu satırdan alınır). Her satırda
// "Bağlantıyı Kaldır" — kaldırınca dialog içi liste yenilenir; dialog kapanınca
// `onChanged` çağrılıp arkadaki ürün listesi yeniden yüklenir.
class _EquivalentBarcodeDialog extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onChanged;

  const _EquivalentBarcodeDialog({required this.groupId, required this.onChanged});

  @override
  ConsumerState<_EquivalentBarcodeDialog> createState() => _EquivalentBarcodeDialogState();
}

class _EquivalentBarcodeDialogState extends ConsumerState<_EquivalentBarcodeDialog> {
  bool _loading = true;
  String? _error;
  List<Product> _members = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await ref.read(productRepositoryProvider).fetchGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  Future<void> _unlink(Product p) async {
    try {
      await ref.read(productRepositoryProvider).unlinkEquivalentBarcode(p.id);
      _changed = true;
      if (!mounted) return;
      if (_members.length <= 2) {
        // Grupta artık 0 veya 1 satır kalacak — dialog'un konusu olan grup
        // çözülmüş demektir, kapat.
        Navigator.of(context).pop();
        return;
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Bağlantı kaldırılamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // En son güncellenen (grubun "esas" satırı) — fetchGroupMembers zaten
    // updated_at DESC sıralı döner, ilk eleman "Esas".
    final latestId = _members.isEmpty ? null : _members.first.id;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) widget.onChanged();
      },
      child: AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error, color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text('Eşlenik Barkod'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Text('Grup yüklenemedi: $_error', style: const TextStyle(color: AppColors.danger))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final m in _members)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSizes.space8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.space12, vertical: AppSizes.space8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(m.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          if (m.id == latestId) ...[
                                            const SizedBox(width: AppSizes.space6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: AppSizes.space6, vertical: AppSizes.space2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                                              ),
                                              child: const Text('Esas',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.success)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: AppSizes.space4),
                                      Text('Barkod: ${m.barcode ?? '-'}  ·  Stok: ${formatNumber(m.stockQuantity)}  ·  Fiyat: ${formatCurrency(m.price1)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.link_off, size: 18, color: AppColors.danger),
                                  tooltip: 'Bağlantıyı Kaldır',
                                  onPressed: () => _unlink(m),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

// ── Mobil ürün kartı ──────────────────────────────────────────────────────────
//
// Sol: ürün adı (üst) + barkod (alt)
// Sağ: Stok · Alış · Fiyat 1

class _ProductMobileCard extends StatelessWidget {
  final Product product;
  final Future<void> Function(Product) onDelete;
  final EquivalentAggregate? equivalent;
  final VoidCallback onEquivalentChanged;

  const _ProductMobileCard({
    required this.product,
    required this.onDelete,
    this.equivalent,
    required this.onEquivalentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onTap: () => context.go('/products/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12, vertical: AppSizes.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sol: ad + barkod
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (equivalent != null)
                        IconButton(
                          icon: const Icon(Icons.error, color: AppColors.danger, size: 16),
                          tooltip: 'Eşlenik barkod var',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _EquivalentBarcodeDialog(
                              groupId: p.equivalentGroupId!,
                              onChanged: onEquivalentChanged,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space4),
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
            const SizedBox(width: AppSizes.space12),
            // Sağ: üç değer sütunu
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // İMZA — kritik stok sinyali (§5)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Stok: ',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    _StockSignal(product: p, equivalent: equivalent, compact: true),
                  ],
                ),
                const SizedBox(height: AppSizes.space4),
                _InfoChip(label: 'Alış', value: formatCurrency(p.purchasePrice)),
                const SizedBox(height: AppSizes.space4),
                _InfoChip(
                  label: 'Fiyat',
                  value: formatCurrency(p.price1),
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(width: AppSizes.space4),
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
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Kritik stok sinyali (bu ekranın imzası, §5) ───────────────────────────────
//
// tükendi (stok ≤ 0)        → danger DOLU rozet (kırmızı zemin + beyaz metin)
// kritik  (0 < stok ≤ eşik) → danger ince rozet (hafif zemin + danger metin)
// normal  (stok > eşik)     → nötr tabular, vurgu yok
//
// Altın KULLANILMAZ; tablo "kırmızı duvar"a dönmesin diye yalnız riskli satır konuşur.
//
// Eşlenik barkod grubundaysa eşik kontrolü ve gösterim grubun TOPLAM stoğuna
// göre yapılır (kendi stoğu 0 olsa bile grup toplamı pozitifse Tükendi sayılmaz).
class _StockSignal extends StatelessWidget {
  final Product product;
  final EquivalentAggregate? equivalent;

  /// Mobil çip için daha küçük tipografi.
  final bool compact;

  const _StockSignal({required this.product, this.equivalent, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ownStock = product.stockQuantity;
    final effectiveStock = equivalent?.totalStock ?? ownStock;
    final fontSize = compact ? 11.0 : 13.0;
    final value = equivalent == null
        ? formatNumber(ownStock)
        : '${formatNumber(ownStock)}(${formatNumber(equivalent!.totalStock)})';

    // Tükendi — en belirgin: danger dolu rozet.
    if (effectiveStock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space8, vertical: AppSizes.space2),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        child: Text(
          'Tükendi',
          style: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnDark,
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    // Kritik — danger metin + ince rozet (hafif zemin).
    if (effectiveStock <= product.criticalStock) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space6, vertical: AppSizes.space2),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    // Normal — nötr tabular, vurgu yok.
    return Text(
      value,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: compact ? FontWeight.w500 : FontWeight.w400,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
