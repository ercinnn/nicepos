import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_status_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/network_timeout.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/scan_sound.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../../../features/products/data/local/product_local_cache_dao.dart';
import '../../../../features/products/data/models/product.dart';
import '../../../../features/products/presentation/widgets/live_product_search_field.dart';
import '../../application/barcode_cache.dart';
import '../../application/barcode_focus_notifier.dart';
import '../../application/sales_cart_notifier.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/cart_table.dart';
import '../widgets/customer_tabs.dart';
import '../widgets/payment_panel.dart';
import '../widgets/product_search_dialog.dart';
import '../widgets/quick_products_dialog.dart';
import '../widgets/quick_products_panel.dart';

/// Masaüstü sağ sütunda Hızlı Ürünler paneline garanti edilen en az yükseklik
/// (§6.7(h)/3 "makul alt sınır"): grup çipleri + birkaç ürün satırı okunur kalır,
/// panel kısa pencerede 0'a inip yok olmaz. Mobildeki sabit hızlı ürünler
/// yüksekliğiyle (196) aynı aileden, bir kademe kısa.
const double _kMinHizliUrunlerYuksekligi = 160;

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Barkod → Product bellek indeksini bir kez prefetch et (keepAlive cache;
    // her ekran açılışında yeniden çekmez). Okutmada ağ turu beklemeden ekleme.
    ref.read(barcodeCacheProvider).ensureLoaded();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  // Bulunan ürünü sepete ekler + başarı bipi/haptic + alanı temizler (dört
  // farklı bulma yolundan da — bellek/ağ/yerel önbellek — çağrılan ortak kuyruk).
  //
  // Ayrıca (fire-and-forget) `label_scan_activity`'e işaretlenir — "Stok"
  // sayfasındaki aktif-ürün sayacı satış EKRANINDA barkodu okutulan her ürünü
  // de kapsasın diye (satış TAMAMLANMASA bile "okutuldu" sayılır; satış
  // gerçekten tamamlanırsa zaten `sale_items` üzerinden ayrıca aktif sayılır
  // — bkz. `ProductRepository.markLabelScanned`, 0034 migration).
  void _addFoundProduct(BarcodeCache cache, Product product) {
    cache.put(product);
    HapticFeedback.lightImpact();
    playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
    ref.read(salesCartProvider.notifier).addProduct(product);
    unawaited(ref
        .read(productRepositoryProvider)
        .markLabelScanned(product.id, product.barcode ?? ''));
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _onBarcodeSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    // ÖNCE bellek cache'i: hit ise ağ beklemeden anında ekle (senkron).
    final cache = ref.read(barcodeCacheProvider);
    final cached = cache.lookup(query);
    if (cached != null) {
      _addFoundProduct(cache, cached);
      return;
    }

    // Zaten "offline" biliniyorsa 6sn'lik ağ timeout'unu tekrar tekrar
    // beklemeden direkt yerel önbelleğe düş (bkz. product_form_screen.dart
    // `_knownOffline` deseni).
    final knownOffline =
        !kIsWeb && ref.read(connectivityStatusServiceProvider).phase == ConnectivityPhase.offline;

    if (!knownOffline) {
      try {
        final product = await withNetworkTimeout(ref.read(productRepositoryProvider).fetchByBarcode(query));
        if (product != null) {
          _addFoundProduct(cache, product);
          return;
        }
        final matches = await withNetworkTimeout(ref.read(productRepositoryProvider).fetchAll(query: query));
        if (matches.length == 1) {
          _addFoundProduct(cache, matches.first);
          return;
        }
      } catch (_) {
        // Ağ başarısız (timeout/soket) — aşağıda yerel önbelleğe düşülür.
      }
    }

    // Yerel önbellek (native only) — barkod BİREBİR eşleşme önce, yoksa
    // isim/stok kodu üzerinde TEK eşleşme.
    if (!kIsWeb) {
      final localMatches = await ref.read(productLocalCacheDaoProvider).searchCached(query: query);
      final exactBarcode = localMatches.where((p) => p.barcode == query).toList();
      if (exactBarcode.length == 1) {
        _addFoundProduct(cache, exactBarcode.first);
        return;
      }
      if (exactBarcode.isEmpty && localMatches.length == 1) {
        _addFoundProduct(cache, localMatches.first);
        return;
      }
    }

    // Tam/tekil eşleşme yok → danger uyarı sesi + arama diyaloğu.
    playScanBeep(success: false); // (KARAR v1.14.1)
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

    // Satış başarıyla tamamlanınca (payment_panel tick'i artırır) barkod alanına
    // otomatik odak ver — kullanıcı elini klavyeden çekmeden yeni ürün okutabilsin.
    // Yalnızca masaüstü layout'ta dinlenir (mobilde ödeme bottom sheet ile; orada
    // klavye istenmeden açılmasın diye odak zorlanmaz).
    ref.listen(barcodeFocusRequestProvider, (_, _) {
      _barcodeFocusNode.requestFocus();
    });

    return Focus(
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LiveProductSearchField(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Sağ sütun akışkan: dar masaüstünde 420'ye kadar daralır, geniş
                // ekranda 580'de durur. Sepet (flex: 3) kalan alanı alır.
                final double sagSutunGenisligi =
                    (constraints.maxWidth * 0.42).clamp(420.0, 580.0).toDouble();
                // ── Dikey taşma emniyeti (§6.7(h)/3 + §6.8(a)). Sabit yükseklik
                // GERİ GELMEZ; bunun yerine ödeme paneline bir ÜST SINIR verilir:
                // sığmazsa panel KENDİ İÇİNDE, yalnız ORTA bölgesini kaydırır —
                // hero (üstte) ve "Satışı Tamamla" (altta) kaydırma alanının
                // DIŞINDA kalır, hiçbir çözünürlükte kaybolmaz. Altındaki Hızlı
                // Ürünler paneline de bir alt sınır kalır. Not: iki çocuğu birden
                // `Flexible` yapmak alanı flex ORANINA göre bölerdi (panelin doğal
                // yüksekliği korunmazdı) — bu yüzden üst-sınır + `Expanded` düzeni.
                final double sutunYuksekligi = constraints.maxHeight;
                final double maxOdemeYuksekligi = (sutunYuksekligi -
                        _kMinHizliUrunlerYuksekligi -
                        AppSizes.space12)
                    .clamp(sutunYuksekligi * 0.5, sutunYuksekligi)
                    .toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space12),
                          child: CartTable(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    SizedBox(
                      width: sagSutunGenisligi,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ödeme paneli sabit yükseklikli DEĞİL — içeriği kadar
                          // yer alır (Parçalı seçilince büyür); yalnız üst sınırı
                          // aşarsa panel KENDİ orta bölgesini kaydırır. Buraya
                          // dıştan bir `SingleChildScrollView` KONULMAZ: tüm
                          // paneli kaydırırdı ve ana aksiyon görünmez alana
                          // düşerdi (§6.8(a) — ölçülen 1366×768 hatası).
                          ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: maxOdemeYuksekligi),
                            child: const PaymentPanel(),
                          ),
                          const SizedBox(height: AppSizes.space12),
                          const Expanded(child: Card(child: QuickProductsPanel())),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
              child: LiveProductSearchField(
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
        // Ödeme satırının bir üstü: solda Müşteri Seç, sağda Hızlı Ürünler
        // (diyalog olarak açılır, bkz. quick_products_dialog.dart)
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: CustomerSelectButton()),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                  context: context, builder: (_) => const QuickProductsDialog()),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Hızlı Ürünler'),
            ),
          ],
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
              icon: const Icon(Icons.undo_rounded, size: 18),
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
    // §5 altın ekonomisi: bu çubuk artık hero DEĞİL → kenarlık nötr hairline.
    final borderColor = isReturnMode ? AppColors.danger.withValues(alpha: 0.5) : AppColors.divider;
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
                const SizedBox(height: AppSizes.space2),
                // Bu çubuk hero DEĞİL (§4 tek-hero): altın ray YOK, tutar bir
                // kademe küçük. Mobilin tek hero'su ödeme sheet'indeki
                // `InstrumentHero`'dur. Rakam yine tabular.
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
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
              // §6.8(a): sheet'in kendi `SingleChildScrollView`'ı KALDIRILDI —
              // tüm paneli kaydırdığı için "Satışı Tamamla" katlanın altında
              // kalıyordu. Artık panel bounded (tight) yükseklik alır ve ÜÇ
              // BÖLGE düzenini kurar: hero üstte sabit, ana aksiyon altta sabit,
              // yalnız orta bölge kayar. Sheet'in `controller`'ı panele geçilir →
              // sürükleyerek büyütme/küçültme aynen çalışır ve ekranda TEK bir
              // kaydırılabilir kalır (iç içe kaydırma YOK). `initialChildSize`
              // (0.6) DEĞİŞMEDİ.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  child: PaymentPanel(scrollController: controller),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

