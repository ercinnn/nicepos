import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/repositories/product_repository.dart'
    show composeDescriptionWithFirma;
import '../../../products/presentation/widgets/company_autocomplete_field.dart';
import '../../application/eksik_listesi_provider.dart';
import '../../application/reports_provider.dart';
import '../../data/models/ciro_analiz_record.dart';
import 'daily_report_screen.dart' show ReportTableCard, ReportEmptyCard;

/// Ciro Analiz sekmesi (Analiz sayfası 3. sekme — eski adı "Eksik Listesi",
/// Raporlar'daydı; kullanıcı isteğiyle Analiz sayfasına taşındı ve yeniden
/// adlandırıldı — dosya/sınıf adları da buna göre güncellendi).
///
/// Tarama/analiz ekranı → HERO YOK. Kolonlar: Sıra · Ürün (+ barkod) · Adet
/// (aralıkta satılan) · Stok (güncel) · Toplam Ciro (gerçek/indirim-sonrası) ·
/// Ciro Payı (seçili aralıktaki TÜM ürünlerin toplam cirosuna oranı, %) ·
/// Firma. Varsayılan sıralama adet azalan; masaüstünde her sütun başlığına
/// dokununca `DataTable` yerleşik `sortColumnIndex`/`onSort` mekanizmasıyla
/// azdan çoğa/çoktan aza değiştirilebilir (sıralama tamamen istemci
/// tarafında, `records` zaten tek seferde tam çekildiğinden sunucu tarafı
/// sıralama yok — `products_list_screen.dart`'ın server-side sort'undan
/// FARKLI, basit yerel `List.sort`). Firma sütunu da alfabetik sıralanır;
/// `.toLowerCase().compareTo()` Unicode kod noktası sırasına göre çalıştığından
/// rakamlar (0-9) harflerden ÖNCE gelir — kullanıcının istediği "numaralar
/// başta" davranışı ekstra kod GEREKTİRMEDEN sağlanır.
///
/// **Firma hücresi tıkla-düzenle (yalnız masaüstü):** `products_list_screen.dart`
/// `_cell`/`_editableField` ile BENZER desen — hücreye dokununca paylaşılan
/// `CompanyAutocompleteField` (bkz. `company_autocomplete_field.dart`, aynı
/// "akıllı" P→2 eşleşme/PA→PALA/PE→PERDECİ davranışı ürün formuyla PAYLAŞILIR)
/// açılır. Kaydetme Enter'da VEYA odak kaybında (`FocusNode` listener)
/// tetiklenir — `TapRegion.onTapOutside` KASITLI kullanılmaz: öneri overlay'i
/// `OverlayPortal` ile hücrenin render alt ağacının DIŞINDA çizildiğinden bir
/// `TapRegion` öneriye tıklamayı pointer-down anında "dışarı" sayıp seçim
/// tamamlanmadan kaydedip controller'ı erken dispose ederdi; `_select()` odağı
/// KORUDUĞUNDAN (`requestFocus()`) öneriye tıklamak odak kaybı SAYILMAZ.
/// Kaydetme `ProductRepository.updateDescription()` ile ürünün `description`
/// alanının firma parçasını değiştirir (tarih/durum KORUNUR).
///
/// **Stok hücresi tıkla-düzenle (yalnız masaüstü, KARAR — kullanıcı isteği):**
/// Firma hücresiyle BİREBİR aynı iskelet (ayrı bir `_editingStockRecord`/
/// `_stockCtrl`/`_stockFocus` durum üçlüsü) — sayısal `TextField`, kaydetme
/// Enter'da VEYA odak kaybında. `ProductRepository.updateStockQuantity()` ile
/// ürünün `products.stock_quantity` alanını DOĞRUDAN (satış/description'a
/// dokunmadan) günceller — bu tablodaki "Stok" değeri zaten `products`
/// tablosundan geldiğinden (bkz. model doc'u) kaydetme aynı zamanda ürünün
/// GERÇEK stok bilgisini de günceller, ayrı bir senkron adımı GEREKMEZ.
///
/// **Her iki hücre de kaydettikten sonra:** sunucudan taze veri çekmek YERİNE
/// (tüm `fetchCiroAnaliz` sorgusu — çok sayfalı `sale_items` sorgusu — baştan
/// çalışır, TÜM tabloyu spinner'a düşürürdü) yalnız değişen hücre yerel bir
/// override map'i üzerinden yamanır; `ciroAnalizProvider` bir sonraki GERÇEK
/// sebeple (tarih aralığı değişince) yeniden çektiğinde zaten güncel veriyle
/// örtüşür.
///
/// **Sayfalama:** `_pageSize` (100) — tüm liste tek seferde çekilir
/// (`records`), sayfalama yalnız GÖRÜNTÜLEME amaçlı istemci tarafı dilimleme
/// (`List.sublist`). Sıra numarası (#) sayfalar arasında SÜREKLİ (101, 102...
/// gibi), her sayfada 1'den başlamaz.
///
/// **%80 ciro vurgusu (Pareto/ABC):** `_computeTop80ProductIds` TÜM listeyi
/// (mevcut sıralama/sayfadan BAĞIMSIZ) `totalRevenue` azalana göre sıralayıp
/// kümülatif toplamı aralığın toplam cirosunun %80'ine ulaşana kadar
/// işaretler (eşiği aşan son ürün DAHİL — klasik ABC "A sınıfı" tanımı).
/// İşaretli satırlar `AppColors.success` @0.12 alfa ile açık yeşil boyanır.
/// Filtre: tarih aralığı (default 2026-01-01 → bugün) — `best_sellers_tab.dart`
/// ile aynı desen, yalnız min-fiyat filtresi yok.
class CiroAnalizTab extends ConsumerStatefulWidget {
  const CiroAnalizTab({super.key});

  @override
  ConsumerState<CiroAnalizTab> createState() => _CiroAnalizTabState();
}

class _CiroAnalizTabState extends ConsumerState<CiroAnalizTab> {
  static const _pageSize = 100;

  DateTime _start = DateTime(2026, 1, 1);
  DateTime _end = DateTime.now();

  // Masaüstü tablo sütun sıralaması — yerel (client-side), `records` zaten
  // tam çekildiği için sunucuya gitmez. Varsayılan: adet azalan (repository
  // ile aynı).
  String _sortColumn = 'quantitySold';
  bool _sortAscending = false;

  int _page = 0;

  // Stok/Satış filtre haneleri (kullanıcı isteği: tabloyu düşük stok + yüksek
  // satış ürünlerine daraltma) — istemci tarafında `_applyRangeFilters` ile
  // uygulanır, sunucuya gitmez (`records` zaten tek seferde tam çekili).
  // "Stok ≤ X" VE "Satış ≥ Y" birlikte AND ile uygulanır.
  final _stockMaxCtrl = TextEditingController();
  final _salesMinCtrl = TextEditingController();
  num? _stockMaxFilter;
  num? _salesMinFilter;

  // Filtrelenmiş sonuçtaki firmaları seçip (inline `FilterChip`'ler) Eksik
  // Listesi'ne aktarmak için — bkz. `_buildCompanyPicker`/`_addSelectedCompaniesToEksikListesi`.
  final Set<String> _selectedCompanies = {};

  void _onFilterFieldChanged() {
    setState(() {
      _stockMaxFilter = _parseStockInput(_stockMaxCtrl.text);
      _salesMinFilter = _parseStockInput(_salesMinCtrl.text);
      _page = 0;
      _selectedCompanies.clear();
    });
  }

  List<CiroAnalizRecord> _applyRangeFilters(List<CiroAnalizRecord> records) {
    if (_stockMaxFilter == null && _salesMinFilter == null) return records;
    return records.where((r) {
      final stockOk = _stockMaxFilter == null || r.stockQuantity <= _stockMaxFilter!;
      final salesOk = _salesMinFilter == null || r.quantitySold >= _salesMinFilter!;
      return stockOk && salesOk;
    }).toList();
  }

  Future<void> _addSelectedCompaniesToEksikListesi(
    List<CiroAnalizRecord> filtered,
  ) async {
    if (_selectedCompanies.isEmpty) return;
    final matches =
        filtered.where((r) => _selectedCompanies.contains(r.companyName)).toList();
    ref.read(eksikListesiControllerProvider.notifier).addAll(matches);
    setState(() => _selectedCompanies.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${matches.length} ürün Eksik Listesi\'ne eklendi.')),
      );
    }
  }

  // Firma kaydından sonra ekranı YALNIZ o hücre için güncellemek üzere:
  // sunucudan taze veri çekmek (`ref.invalidate(ciroAnalizProvider(...))`)
  // hem YAVAŞ (tüm `fetchCiroAnaliz` sorgusu — çok sayfalı `sale_items`
  // sorgusu — baştan çalışırdı) hem de TÜM tabloyu yeniden yükleyip
  // spinner'a düşürürdü (kullanıcı şikayeti: "çok uzun sürüyor" +
  // "ekran anında yenilenmesin, sadece değişen hücre yenilensin"). Bunun
  // yerine `records` listesi provider'dan geldiği gibi bırakılır, yalnız bu
  // iki override map'i üzerinden görüntüleme anında yamanır (bkz.
  // `_applyFirmaOverrides`) — provider bir sonraki GERÇEK sebeple (tarih
  // aralığı değişince) yeniden çektiğinde zaten güncel veriyle örtüşür.
  final Map<String, String> _firmaNameOverrides = {};
  final Map<String, String> _firmaDescriptionOverrides = {};

  List<CiroAnalizRecord> _applyFirmaOverrides(List<CiroAnalizRecord> records) {
    if (_firmaNameOverrides.isEmpty) return records;
    return records.map((r) {
      final name = _firmaNameOverrides[r.productId];
      if (name == null) return r;
      return r.copyWith(
        companyName: name,
        rawDescription: _firmaDescriptionOverrides[r.productId],
      );
    }).toList();
  }

  // Firma hücresi tıkla-düzenle — yalnız masaüstü tablo, aynı anda tek satır
  // düzenlenebilir (`products_list_screen.dart` `_editingIds` tekil desenden
  // farklı olarak burada tek hücre için basitleştirildi). Kaydetme odak
  // KAYBINDA tetiklenir (`TapRegion.onTapOutside` DEĞİL) — `CompanyAutocompleteField`
  // önerisi ayrı bir `OverlayPortal`/`TextFieldTapRegion` içinde render edilir
  // (hücrenin render alt ağacının DIŞINDA), bir `TapRegion` önce
  // pointer-down'da tetiklenip öneriye tıklamayı "dışarı" sayardı — seçim
  // tamamlanmadan kaydedip controller'ı erken dispose ederdi. `_select()`
  // odağı kasıtlı KORUDUĞUNDAN (`widget.focusNode.requestFocus()`) öneriye
  // tıklamak odak kaybı SAYILMAZ; yalnız gerçekten hücre dışına tıklamak/
  // Tab'lamak tetikler.
  CiroAnalizRecord? _editingFirmaRecord;
  TextEditingController? _firmaCtrl;
  FocusNode? _firmaFocus;
  bool _savingFirma = false;

  void _enterFirmaEdit(CiroAnalizRecord r) {
    _firmaFocus?.removeListener(_onFirmaFocusChange);
    _firmaCtrl?.dispose();
    _firmaFocus?.dispose();
    final focus = FocusNode();
    focus.addListener(_onFirmaFocusChange);
    setState(() {
      _editingFirmaRecord = r;
      _firmaCtrl = TextEditingController(
        text: r.companyName == '-' ? '' : r.companyName,
      );
      _firmaFocus = focus;
    });
  }

  void _onFirmaFocusChange() {
    if (_firmaFocus != null && !_firmaFocus!.hasFocus) {
      final r = _editingFirmaRecord;
      if (r != null) _saveFirma(r);
    }
  }

  void _exitFirmaEdit() {
    _firmaFocus?.removeListener(_onFirmaFocusChange);
    _firmaCtrl?.dispose();
    _firmaFocus?.dispose();
    setState(() {
      _editingFirmaRecord = null;
      _firmaCtrl = null;
      _firmaFocus = null;
    });
  }

  Future<void> _saveFirma(CiroAnalizRecord r) async {
    final ctrl = _firmaCtrl;
    if (ctrl == null || _editingFirmaRecord?.productId != r.productId) return;
    final newValue = ctrl.text.trim();
    final unchanged =
        newValue == r.companyName || (newValue.isEmpty && r.companyName == '-');
    if (unchanged) {
      _exitFirmaEdit();
      return;
    }
    setState(() => _savingFirma = true);
    try {
      // Ham description elimizde (rapor satırından/önceki override'dan) —
      // sunucudan tekrar SELECT ETMEDEN tek UPDATE ile kaydeder (hız şikayeti
      // buradan geliyordu, bkz. ProductRepository.updateDescription notu).
      final newDescription =
          composeDescriptionWithFirma(r.rawDescription, newValue);
      await ref
          .read(productRepositoryProvider)
          .updateDescription(r.productId, newDescription);
      setState(() {
        _firmaNameOverrides[r.productId] = newValue.isEmpty ? '-' : newValue;
        _firmaDescriptionOverrides[r.productId] = newDescription;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firma güncellenemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingFirma = false);
        _exitFirmaEdit();
      }
    }
  }

  // Stok hücresi tıkla-düzenle — Firma hücresiyle BİREBİR aynı iskelet (bkz.
  // yukarıdaki class doc'u), yalnız sayısal `TextField` + hedef alan
  // `products.stock_quantity`. Ayrı bir override map'i (`_stockOverrides`)
  // kullanılır ki Firma ve Stok birbirinden bağımsız kaydedilebilsin.
  final Map<String, num> _stockOverrides = {};

  List<CiroAnalizRecord> _applyStockOverrides(List<CiroAnalizRecord> records) {
    if (_stockOverrides.isEmpty) return records;
    return records.map((r) {
      final stock = _stockOverrides[r.productId];
      if (stock == null) return r;
      return r.copyWith(stockQuantity: stock);
    }).toList();
  }

  CiroAnalizRecord? _editingStockRecord;
  TextEditingController? _stockCtrl;
  FocusNode? _stockFocus;
  bool _savingStock = false;

  void _enterStockEdit(CiroAnalizRecord r) {
    _stockFocus?.removeListener(_onStockFocusChange);
    _stockCtrl?.dispose();
    _stockFocus?.dispose();
    final focus = FocusNode();
    focus.addListener(_onStockFocusChange);
    setState(() {
      _editingStockRecord = r;
      _stockCtrl = TextEditingController(text: _formatStockForEdit(r.stockQuantity));
      _stockFocus = focus;
    });
  }

  void _onStockFocusChange() {
    if (_stockFocus != null && !_stockFocus!.hasFocus) {
      final r = _editingStockRecord;
      if (r != null) _saveStock(r);
    }
  }

  void _exitStockEdit() {
    _stockFocus?.removeListener(_onStockFocusChange);
    _stockCtrl?.dispose();
    _stockFocus?.dispose();
    setState(() {
      _editingStockRecord = null;
      _stockCtrl = null;
      _stockFocus = null;
    });
  }

  Future<void> _saveStock(CiroAnalizRecord r) async {
    final ctrl = _stockCtrl;
    if (ctrl == null || _editingStockRecord?.productId != r.productId) return;
    final newValue = _parseStockInput(ctrl.text);
    if (newValue == null || newValue == r.stockQuantity) {
      _exitStockEdit();
      return;
    }
    setState(() => _savingStock = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .updateStockQuantity(r.productId, newValue);
      setState(() => _stockOverrides[r.productId] = newValue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok güncellenemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingStock = false);
        _exitStockEdit();
      }
    }
  }

  @override
  void dispose() {
    _firmaFocus?.removeListener(_onFirmaFocusChange);
    _firmaCtrl?.dispose();
    _firmaFocus?.dispose();
    _stockFocus?.removeListener(_onStockFocusChange);
    _stockCtrl?.dispose();
    _stockFocus?.dispose();
    _stockMaxCtrl.dispose();
    _salesMinCtrl.dispose();
    super.dispose();
  }

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _page = 0;
    });
  }

  List<CiroAnalizRecord> _sortRecords(List<CiroAnalizRecord> records) {
    final sorted = List<CiroAnalizRecord>.from(records);
    int compare(CiroAnalizRecord a, CiroAnalizRecord b) {
      switch (_sortColumn) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'companyName':
          return a.companyName
              .toLowerCase()
              .compareTo(b.companyName.toLowerCase());
        case 'stockQuantity':
          return a.stockQuantity.compareTo(b.stockQuantity);
        case 'totalRevenue':
          return a.totalRevenue.compareTo(b.totalRevenue);
        case 'revenueSharePercent':
          return a.revenueSharePercent.compareTo(b.revenueSharePercent);
        case 'quantitySold':
        default:
          return a.quantitySold.compareTo(b.quantitySold);
      }
    }

    sorted.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return sorted;
  }

  // Seçili aralıktaki TÜM ürünlerin toplam cirosunun %80'ine kümülatif
  // olarak ulaşan (eşiği aşan son ürün DAHİL) ürün id'lerini döner —
  // mevcut sıralama/sayfadan bağımsız, her zaman `totalRevenue` azalana
  // göre hesaplanır (klasik ABC/Pareto "A sınıfı" tanımı).
  Set<String> _computeTop80ProductIds(List<CiroAnalizRecord> records) {
    final byRevenue = List<CiroAnalizRecord>.from(records)
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final grandTotal = byRevenue.fold<num>(0, (sum, r) => sum + r.totalRevenue);
    if (grandTotal <= 0) return {};
    num cumulative = 0;
    final ids = <String>{};
    for (final r in byRevenue) {
      final beforePercent = cumulative / grandTotal * 100;
      cumulative += r.totalRevenue;
      if (beforePercent < 80) {
        ids.add(r.productId);
      }
    }
    return ids;
  }

  Future<void> _pickStart() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) {
      setState(() {
        _start = p;
        _page = 0;
        _firmaNameOverrides.clear();
        _firmaDescriptionOverrides.clear();
        _stockOverrides.clear();
      });
    }
  }

  Future<void> _pickEnd() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) {
      setState(() {
        _end = p;
        _page = 0;
        _firmaNameOverrides.clear();
        _firmaDescriptionOverrides.clear();
        _stockOverrides.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    // Aralık normalize edilir (başlangıç ≤ bitiş).
    final start = _start.isBefore(_end) ? _start : _end;
    final end = _start.isBefore(_end) ? _end : _start;

    final recordsAsync = ref.watch(
      ciroAnalizProvider(start: start, end: end),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          _buildMobileControls()
        else
          _buildDesktopControls(),
        const SizedBox(height: AppSizes.space12),
        _buildFilterRow(),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (rawRecords) {
              if (rawRecords.isEmpty) {
                return const ReportEmptyCard(
                  'Seçili aralıkta satılan ürün bulunamadı.',
                );
              }
              // Firma/Stok kaydından sonra tam sunucu round-trip'i YERİNE
              // yerel yama (bkz. _firmaNameOverrides/_stockOverrides doc'u) —
              // yalnız değişen hücre(ler) güncellenmiş görünür, tablo
              // yeniden yüklenmez.
              final withOverrides =
                  _applyStockOverrides(_applyFirmaOverrides(rawRecords));
              // Stok/Satış filtreleri (varsa) — bkz. `_applyRangeFilters`.
              final records = _applyRangeFilters(withOverrides);
              if (records.isEmpty) {
                return const ReportEmptyCard(
                  'Filtrelere uyan ürün bulunamadı.',
                );
              }
              final sorted = _sortRecords(records);
              // %80 vurgusu FİLTRELENMİŞ sete göre hesaplanır — ekranda
              // görünen (filtrelenmiş) tabloyla tutarlı kalsın.
              final topProductIds = _computeTop80ProductIds(records);

              final pageCount = (sorted.length / _pageSize).ceil();
              final safePage = _page.clamp(0, pageCount - 1);
              final startIdx = safePage * _pageSize;
              final endIdx = (startIdx + _pageSize).clamp(0, sorted.length);
              final pageRecords = sorted.sublist(startIdx, endIdx);

              final filterActive =
                  _stockMaxFilter != null || _salesMinFilter != null;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.space8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: AppSizes.space8),
                          const Text(
                            'Açık yeşil: cironun %80\'ini oluşturan ürünler',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (filterActive) ...[
                      _buildCompanyPicker(records),
                      const SizedBox(height: AppSizes.space12),
                    ],
                    ReportTableCard(
                      child: isMobile
                          ? _CiroAnalizMobileList(
                              records: pageRecords,
                              startIndex: startIdx,
                              topProductIds: topProductIds,
                            )
                          : _CiroAnalizTable(
                              records: pageRecords,
                              startIndex: startIdx,
                              topProductIds: topProductIds,
                              sortColumn: _sortColumn,
                              sortAscending: _sortAscending,
                              onSort: _onSort,
                              editingFirmaProductId: _editingFirmaRecord?.productId,
                              firmaController: _firmaCtrl,
                              firmaFocusNode: _firmaFocus,
                              savingFirma: _savingFirma,
                              onFirmaTap: _enterFirmaEdit,
                              onFirmaSave: _saveFirma,
                              editingStockProductId: _editingStockRecord?.productId,
                              stockController: _stockCtrl,
                              stockFocusNode: _stockFocus,
                              savingStock: _savingStock,
                              onStockTap: _enterStockEdit,
                              onStockSave: _saveStock,
                            ),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    _buildPagination(
                      page: safePage,
                      pageCount: pageCount,
                      totalCount: sorted.length,
                    ),
                    const SizedBox(height: AppSizes.space24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Sayfalama kontrolü ─────────────────────────────────────────────────────
  Widget _buildPagination({
    required int page,
    required int pageCount,
    required int totalCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed:
              page > 0 ? () => setState(() => _page = page - 1) : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Önceki'),
        ),
        const SizedBox(width: AppSizes.space16),
        Text(
          'Sayfa ${page + 1} / $pageCount  ·  toplam ${formatNumber(totalCount)} ürün',
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSizes.space16),
        TextButton.icon(
          onPressed: page < pageCount - 1
              ? () => setState(() => _page = page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Sonraki'),
        ),
      ],
    );
  }

  // ── Masaüstü kontrol satırı ────────────────────────────────────────────────
  Widget _buildDesktopControls() {
    return Row(
      children: [
        Text('Ciro Analiz', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('Başlangıç: ${formatDate(_start)}'),
          onPressed: _pickStart,
        ),
        const SizedBox(width: AppSizes.space8),
        const Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSizes.space8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('Bitiş: ${formatDate(_end)}'),
          onPressed: _pickEnd,
        ),
      ],
    );
  }

  // ── Mobil kontrol satırı ───────────────────────────────────────────────────
  Widget _buildMobileControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ciro Analiz', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  formatDate(_start),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _pickStart,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.textMuted),
            ),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  formatDate(_end),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _pickEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Stok/Satış filtre haneleri ─────────────────────────────────────────────
  // "Stok ≤" bu sayıya eşit VE bu sayıdan az olan ürünleri, "Satış ≥" bu
  // sayıya eşit VE yüksek olan ürünleri bırakır (ikisi birlikte AND).
  Widget _buildFilterRow() {
    Widget field(String label, TextEditingController ctrl) => SizedBox(
          width: 150,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _stockInputFormatters,
            onChanged: (_) => _onFilterFieldChanged(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        );

    return Wrap(
      spacing: AppSizes.space12,
      runSpacing: AppSizes.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        field('Stok ≤', _stockMaxCtrl),
        field('Satış ≥', _salesMinCtrl),
        if (_stockMaxFilter != null || _salesMinFilter != null)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _stockMaxCtrl.clear();
                _salesMinCtrl.clear();
                _stockMaxFilter = null;
                _salesMinFilter = null;
                _page = 0;
                _selectedCompanies.clear();
              });
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Filtreyi Temizle'),
          ),
      ],
    );
  }

  // ── Firma seçici — filtre sonucundaki firmaları yan yana `FilterChip` +
  // "Eksik Listesine Ekle" butonuyla gösterir (bkz. `_addSelectedCompaniesToEksikListesi`).
  Widget _buildCompanyPicker(List<CiroAnalizRecord> filtered) {
    final companies = filtered.map((r) => r.companyName).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrelenen ürünlerdeki firmalar — Eksik Listesi\'ne aktarmak '
            'istediklerinizi seçin:',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSizes.space8),
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            children: [
              for (final company in companies)
                FilterChip(
                  label: Text(company),
                  selected: _selectedCompanies.contains(company),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCompanies.add(company);
                      } else {
                        _selectedCompanies.remove(company);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSizes.space12),
          FilledButton.icon(
            onPressed: _selectedCompanies.isEmpty
                ? null
                : () => _addSelectedCompaniesToEksikListesi(filtered),
            icon: const Icon(Icons.playlist_add, size: 18),
            label: Text(
              'Eksik Listesine Ekle (${_selectedCompanies.length} firma)',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _CiroAnalizTable extends StatelessWidget {
  final List<CiroAnalizRecord> records;
  final int startIndex;
  final Set<String> topProductIds;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String column, bool ascending) onSort;

  // Firma hücresi tıkla-düzenle — bkz. _CiroAnalizTabState.
  final String? editingFirmaProductId;
  final TextEditingController? firmaController;
  final FocusNode? firmaFocusNode;
  final bool savingFirma;
  final void Function(CiroAnalizRecord r) onFirmaTap;
  final void Function(CiroAnalizRecord r) onFirmaSave;

  // Stok hücresi tıkla-düzenle — Firma ile BİREBİR aynı desen, bkz.
  // _CiroAnalizTabState.
  final String? editingStockProductId;
  final TextEditingController? stockController;
  final FocusNode? stockFocusNode;
  final bool savingStock;
  final void Function(CiroAnalizRecord r) onStockTap;
  final void Function(CiroAnalizRecord r) onStockSave;

  const _CiroAnalizTable({
    required this.records,
    required this.startIndex,
    required this.topProductIds,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.editingFirmaProductId,
    required this.firmaController,
    required this.firmaFocusNode,
    required this.savingFirma,
    required this.onFirmaTap,
    required this.onFirmaSave,
    required this.editingStockProductId,
    required this.stockController,
    required this.stockFocusNode,
    required this.savingStock,
    required this.onStockTap,
    required this.onStockSave,
  });

  // Sütun sırası: #(0, sıralanamaz) · Ürün(1) · Adet(2) · Stok(3, öne alındı
  // — kullanıcı geniş Toplam Ciro/Ciro Payı sütunları arkasında kaldığından
  // "görünmüyor" şikayeti etti) · Toplam Ciro(4) · Ciro Payı(5) · Firma(6).
  static const _columnKeys = [
    null,
    'name',
    'quantitySold',
    'stockQuantity',
    'totalRevenue',
    'revenueSharePercent',
    'companyName',
  ];

  int? get _sortColumnIndex {
    final idx = _columnKeys.indexOf(sortColumn);
    return idx == -1 ? null : idx;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        sortColumnIndex: _sortColumnIndex,
        sortAscending: sortAscending,
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(
            label: const Text('Ürün'),
            onSort: (_, ascending) => onSort('name', ascending),
          ),
          DataColumn(
            label: const Text('Adet'),
            numeric: true,
            onSort: (_, ascending) => onSort('quantitySold', ascending),
          ),
          DataColumn(
            label: const Text('Stok'),
            numeric: true,
            onSort: (_, ascending) => onSort('stockQuantity', ascending),
          ),
          DataColumn(
            label: const Text('Toplam Ciro'),
            numeric: true,
            onSort: (_, ascending) => onSort('totalRevenue', ascending),
          ),
          DataColumn(
            label: const Text('Ciro Payı'),
            numeric: true,
            onSort: (_, ascending) => onSort('revenueSharePercent', ascending),
          ),
          DataColumn(
            label: const Text('Firma'),
            onSort: (_, ascending) => onSort('companyName', ascending),
          ),
        ],
        rows: List.generate(records.length, (i) {
          final r = records[i];
          final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
          final lowStock = r.stockQuantity <= 0;
          final isTop80 = topProductIds.contains(r.productId);
          return DataRow(
            color: isTop80
                ? WidgetStateProperty.all(
                    AppColors.success.withValues(alpha: 0.12))
                : null,
            cells: [
            DataCell(Text(
              '${startIndex + i + 1}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hasBarcode)
                  Text(
                    r.barcode!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            )),
            DataCell(Text(
              formatNumber(r.quantitySold),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(_buildStockCell(r, lowStock)),
            DataCell(Text(
              formatCurrency(r.totalRevenue),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              _formatRevenueShare(r.revenueSharePercent),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(_buildFirmaCell(r)),
          ]);
        }),
      ),
    );
  }

  // Firma hücresi: normalde tıkla-düzenlemeye geçen salt-okunur `Text`;
  // düzenlenen satırda paylaşılan `CompanyAutocompleteField` (akıllı P→2
  // eşleşme/PA→PALA/PE→PERDECİ önerisi). Kaydetme odak kaybında VEYA Enter'da
  // tetiklenir (bkz. _CiroAnalizTabState._onFirmaFocusChange — `TapRegion`
  // KASITLI kullanılmaz, öneri overlay'i hücrenin dışında render edildiğinden
  // yanlış "dışarı tıklama" sayılırdı).
  Widget _buildFirmaCell(CiroAnalizRecord r) {
    if (editingFirmaProductId == r.productId &&
        firmaController != null &&
        firmaFocusNode != null) {
      if (savingFirma) {
        return const SizedBox(
          width: 160,
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return SizedBox(
        width: 160,
        child: CompanyAutocompleteField(
          controller: firmaController!,
          focusNode: firmaFocusNode!,
          dense: true,
          autofocus: true,
          onSubmitted: (_) => onFirmaSave(r),
        ),
      );
    }
    return InkWell(
      onTap: () => onFirmaTap(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space6),
        child: Text(
          r.companyName,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Stok hücresi: Firma hücresiyle BİREBİR aynı iskelet (normalde tıkla-
  // düzenlemeye geçen salt-okunur `Text`; düzenlenen satırda sayısal
  // `TextField`). Kaydetme odak kaybında VEYA Enter'da (bkz.
  // _CiroAnalizTabState._onStockFocusChange).
  Widget _buildStockCell(CiroAnalizRecord r, bool lowStock) {
    if (editingStockProductId == r.productId &&
        stockController != null &&
        stockFocusNode != null) {
      if (savingStock) {
        return const SizedBox(
          width: 80,
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return SizedBox(
        width: 80,
        child: TextField(
          controller: stockController!,
          focusNode: stockFocusNode!,
          autofocus: true,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _stockInputFormatters,
          onSubmitted: (_) => onStockSave(r),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: AppSizes.space6),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => onStockTap(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space6),
        child: Text(
          formatNumber(r.stockQuantity),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: lowStock ? AppColors.danger : AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _CiroAnalizMobileList extends StatelessWidget {
  final List<CiroAnalizRecord> records;
  final int startIndex;
  final Set<String> topProductIds;
  const _CiroAnalizMobileList({
    required this.records,
    required this.startIndex,
    required this.topProductIds,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final r = records[i];
        final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
        final lowStock = r.stockQuantity <= 0;
        final isTop80 = topProductIds.contains(r.productId);
        return Container(
          color: isTop80
              ? AppColors.success.withValues(alpha: 0.12)
              : null,
          child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space12,
          ),
          child: Row(
            children: [
              // Sıra numarası
              SizedBox(
                width: 28,
                child: Text(
                  '${startIndex + i + 1}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              // Ürün adı + barkod + firma
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      [
                        if (hasBarcode) r.barcode!,
                        r.companyName,
                      ].join('  ·  '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              // Sağ: adet + stok
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatNumber(r.quantitySold)} adet',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    'Stok: ${formatNumber(r.stockQuantity)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          lowStock ? AppColors.danger : AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    formatCurrency(r.totalRevenue),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    _formatRevenueShare(r.revenueSharePercent),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// Ciro Payı hücresi biçimi: nokta sonrası daima 2 hane, boşluksuz (%2.50).
String _formatRevenueShare(num value) => '%${value.toStringAsFixed(2)}';

// Stok tıkla-düzenle: `formatNumber`'ın binlik ayracı (`1.294`) düzenleme
// alanında KAFA KARIŞTIRIR (ondalık noktasıyla karışabilir) — bu yüzden
// `products_list_screen.dart` `_fmtNum` ile AYNI sade biçim kullanılır.
String _formatStockForEdit(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// Yalnız `_parseStockInput` içinde kullanılan gevşek ayrıştırma — ',' ve '.'
// ikisi de ondalık ayracı sayılır (kullanıcı hangisini yazarsa yazsın).
num? _parseStockInput(String s) => num.tryParse(s.trim().replaceAll(',', '.'));

// `products_list_screen.dart` `_decimalInputFormatters` ile AYNI desen —
// yalnız rakam/nokta/virgül, en fazla bir ondalık ayracı. Eksi işareti
// KASITLI izin verilmez: bu hücre bir SAYIM/düzeltme girişi, satışlardan
// doğan negatif stok (bkz. tablodaki kırmızı değerler) buradan elle
// girilmez.
final _stockInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  TextInputFormatter.withFunction(
    (o, n) => RegExp(r'[.,]').allMatches(n.text).length > 1 ? o : n,
  ),
];
