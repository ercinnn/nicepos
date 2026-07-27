import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../application/sales_cart_notifier.dart';

class CartTable extends ConsumerStatefulWidget {
  const CartTable({super.key});

  // ─── Masaüstü sabit genişlikli tablo ─────────────────────────────────────
  //
  // Kolon genişlikleri (px): Seç 32 · İskonto 96 · Miktar 116 · Fiyat 160 ·
  // Tutar 88 · Sil 40. Ürün sütunu kalan alanı alır; ancak en az _wProductMin
  // korunur. Toplam genişlik panele sığmazsa tablo yatay kaydırılır (kırpma/
  // çökme yok).
  //
  // İskonto sütunu eskiden 175px'lik satır içi alan idi; kompakt rozet + düzenleme
  // dialog'una (_CompactDiscountCell) taşındığı için 96px'e indi → dar panelde
  // ürün sütununa nefes kalır.
  //
  // Fiyat sütunu 160px'e genişletildi (KARAR v1.6): birim fiyat artık elle
  // düzenlenebilir bir alan + yanında çıplak "Fiyat1 yap" radyosu (KARAR v1.6.1) /
  // altında yeşil onay pill'i taşır.
  //
  // Seç sütunu (32px): çoklu satır seçimi için yuvarlak toggle — toplu %
  // iskonto aksiyonunun (aşağıda _CartTableState) parçası. Tekil satır
  // iskontosuna (_CompactDiscountCell) DOKUNMAZ.

  static const double _wSelect = 32;
  static const double _wDisc = 96;
  static const double _wQty = 116;
  static const double _wPrice = 160;
  static const double _wTotal = 88;
  static const double _wDel = 40;
  static const double _wProductMin =
      220; // ürün adının dikey karaktere çökmesini önler

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  @override
  ConsumerState<CartTable> createState() => _CartTableState();
}

class _CartTableState extends ConsumerState<CartTable> {
  // ── Çoklu satır seçimi (yalnız toplu % iskonto aksiyonu için) ────────────
  //
  // Seçim, aktif müşteri sekmesindeki sepet kalemlerinin index'lerini tutar.
  // Sekme değiştiğinde veya kalem sayısı değiştiğinde (ekleme/silme) index'ler
  // artık güvenilir olmadığından seçim sessizce sıfırlanır.
  final Set<int> _selected = {};
  int? _lastActiveTab;
  int? _lastItemCount;

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesCartProvider);
    final notifier = ref.read(salesCartProvider.notifier);
    final tab = salesState.active;

    if (_lastActiveTab != salesState.activeTab ||
        _lastItemCount != tab.items.length) {
      _lastActiveTab = salesState.activeTab;
      _lastItemCount = tab.items.length;
      _selected.clear();
    }

    if (context.isMobile) {
      return _buildMobileList(context, tab, notifier);
    }
    return _buildDesktopTable(context, tab, notifier);
  }

  // ─── Mobil kart listesi ──────────────────────────────────────────────────

  Widget _buildMobileList(
    BuildContext context,
    CustomerTabState tab,
    SalesCart notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selected.isNotEmpty) _buildMobileBulkBar(notifier),
        Expanded(
          child: tab.items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Sepet boş',
                  message: 'Barkod okutun veya aşağıdan ürün seçin',
                )
              : ListView.separated(
                  itemCount: tab.items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 8, endIndent: 8),
                  itemBuilder: (context, index) {
                    final item = tab.items[index];
                    return _MobileCartItem(
                      item: item,
                      index: index,
                      selected: _selected.contains(index),
                      onToggleSelect: () => _toggle(index),
                      onQuantityChanged: (q) =>
                          notifier.updateItemQuantity(index, q),
                      onUnitPriceChanged: (p) =>
                          notifier.updateItemUnitPrice(index, p),
                      onDiscountChanged: (v, t) =>
                          notifier.updateItemDiscount(index, v, t),
                      onRemove: () => notifier.removeItem(index),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Alt özet satırı — dar telefon genişliklerinde (ör. 360px) "Muhtelif"
        // butonu + toplam/iskonto kırılımının doğal genişliği Spacer'ın
        // bırakabileceğinden fazla olabiliyor (sert RenderFlex overflow).
        // Desktop footer'daki (_buildFooter) AYNI güvenlik ağı: sığarsa normal
        // görünür, sığmazsa satır kırpılmadan yatay kaydırılır.
        LayoutBuilder(
          builder: (context, constraints) {
            final row = Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAddMiscDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Muhtelif',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Genel toplamın TEK sahibi alttaki sticky ödeme barıdır (§4 hero).
                      // Alt özet yalnızca kırılım verir: Ara Toplam (iskonto öncesi).
                      Text(
                        'Ara Toplam: ${formatCurrency(tab.subtotal)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      // Sepet (genel) iskonto girişi — yalnızca sepet doluyken anlamlı.
                      // 48px dokunma hedefi (§3). Aktifse danger renkli "İskonto: -₺X"
                      // kırılımı (tabular), yoksa "İskonto ekle" affordance'ı; dokununca
                      // web ile aynı _DiscountDialog açılır.
                      if (tab.items.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                          onTap: () => _openDiscountDialog(
                            context,
                            value: tab.discountValue,
                            type: tab.discountType,
                            onApply: (v, t) => notifier.setDiscount(v, t),
                          ),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.discountAmount > 0
                                      ? Icons.edit
                                      : Icons.percent,
                                  size: 15,
                                  color: tab.discountAmount > 0
                                      ? AppColors.danger
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: AppSizes.space4),
                                Text(
                                  tab.discountAmount > 0
                                      ? 'İskonto: -${formatCurrency(tab.discountAmount)}'
                                      : 'İskonto ekle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tab.discountAmount > 0
                                        ? AppColors.danger
                                        : AppColors.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
            // IntrinsicWidth ZORUNLU (masaüstü _buildFooter ile birebir aynı
            // desen): yatay SingleChildScrollView çocuğuna SINIRSIZ genişlik
            // verir, ConstrainedBox'ın minWidth'i yalnız ALT sınır koyar → üst
            // sınır Infinity kalır. Yukarıdaki Row bir Spacer (flex) taşıdığı
            // için sınırsız genişlikte "RenderFlex children have non-zero flex
            // but incoming width constraints are unbounded" ile TÜM mobil satış
            // ekranı çöker. IntrinsicWidth, Row'un doğal genişliğini ölçüp
            // aşağıya SIKI bir genişlik kısıtı geçirerek flex'i çözülebilir kılar.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: IntrinsicWidth(child: row),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Mobil toplu seçim çubuğu (aynı görsel dil, dar ekrana uygun kompakt) ──
  Widget _buildMobileBulkBar(SalesCart notifier) {
    return Container(
      width: double.infinity,
      color: AppColors.goldBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      child: Wrap(
        spacing: AppSizes.space12,
        runSpacing: AppSizes.space4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${_selected.length} ürün seçili',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          TextButton.icon(
            onPressed: () => _showBulkPercentDialog(context, notifier),
            icon: const Icon(Icons.percent, size: 15),
            label: const Text('% İndirim', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: AppSizes.space4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          TextButton(
            onPressed: _clearSelection,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: AppSizes.space4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Temizle', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    CustomerTabState tab,
    SalesCart notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık + satırlar ──────────────────────────────────────────────
        // Sütunların toplam genişliği panele sığarsa ürün sütunu esner; sığmazsa
        // ürün sütunu _wProductMin'de kalır ve tablo tek parça yatay kaydırılır
        // (başlık ile satırlar aynı offset'te hizalı kalır, kırpma olmaz).
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const fixed =
                  CartTable._wSelect +
                  CartTable._wDisc +
                  CartTable._wQty +
                  CartTable._wPrice +
                  CartTable._wTotal +
                  CartTable._wDel;
              const hPad = AppSizes.space12 * 2; // satır/başlık yatay iç boşluk
              final available = constraints.maxWidth;
              final room = available - fixed - hPad;
              final productWidth = room >= CartTable._wProductMin
                  ? room
                  : CartTable._wProductMin;
              final tableWidth = fixed + hPad + productWidth;
              final needsScroll = tableWidth > available + 0.5;

              final table = SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Toplu seçim çubuğu — yalnız en az bir satır seçiliyken ──
                    if (_selected.isNotEmpty) _buildDesktopBulkBar(notifier),
                    _buildHeaderRow(productWidth),
                    const Divider(height: 1),
                    Expanded(
                      // Son satır DAİMA satır-içi "+" muhtelif ekleme satırıdır
                      // (KARAR v1.6.2): itemCount = kalem sayısı + 1. Sepet boşsa
                      // itemCount=1 → yalnız "+" satırı (keşif ipucuyla) görünür;
                      // ürün eklendikçe "+" satırı otomatik bir alt satıra iner.
                      child: ListView.separated(
                        itemCount: tab.items.length + 1,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          if (index < tab.items.length) {
                            return _buildItemRow(
                              productWidth,
                              index,
                              tab.items[index],
                              notifier,
                            );
                          }
                          return _AddMiscRow(
                            productWidth: productWidth,
                            showHint: tab.items.isEmpty,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (!needsScroll) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              );
            },
          ),
        ),
        const Divider(height: 1),
        _buildFooter(context, tab, notifier),
      ],
    );
  }

  // ── Masaüstü toplu seçim çubuğu ────────────────────────────────────────────
  Widget _buildDesktopBulkBar(SalesCart notifier) {
    return Container(
      color: AppColors.goldBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      child: Row(
        children: [
          Text(
            '${_selected.length} ürün seçili',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          ElevatedButton.icon(
            onPressed: () => _showBulkPercentDialog(context, notifier),
            icon: const Icon(Icons.percent, size: 15),
            label: const Text('Seçilenlere % İndirim Uygula'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space8,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _clearSelection,
            child: const Text('Seçimi Temizle'),
          ),
        ],
      ),
    );
  }

  // ── Başlık satırı ──────────────────────────────────────────────────────────
  Widget _buildHeaderRow(double productWidth) {
    return Container(
      color: AppColors.tableHeader,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      child: Row(
        children: [
          // Seç sütunu — "tümünü seç" istenmedi, başlığı boş kalır.
          const SizedBox(width: CartTable._wSelect),
          SizedBox(
            width: productWidth,
            child: const Text('Ürün', style: CartTable._headerStyle),
          ),
          SizedBox(
            width: CartTable._wDisc,
            child: const Text('İskonto', style: CartTable._headerStyle),
          ),
          SizedBox(
            width: CartTable._wQty,
            child: const Text('Miktar', style: CartTable._headerStyle),
          ),
          SizedBox(
            width: CartTable._wPrice,
            child: const Text(
              'Fiyat',
              style: CartTable._headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: CartTable._wTotal,
            child: const Text(
              'Tutar',
              style: CartTable._headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: CartTable._wDel),
        ],
      ),
    );
  }

  // ── Tek bir sepet satırı ─────────────────────────────────────────────────
  Widget _buildItemRow(
    double productWidth,
    int index,
    dynamic item,
    SalesCart notifier,
  ) {
    final hasBarcode = item.barcode != null && item.barcode!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Seç (çoklu satır seçimi — toplu % iskonto aksiyonu için) ──────
          SizedBox(
            width: CartTable._wSelect,
            child: Center(
              child: _RowSelectToggle(
                key: ValueKey('row-select-$index'),
                selected: _selected.contains(index),
                onTap: () => _toggle(index),
              ),
            ),
          ),
          // ── Ürün adı + barkod ───────────────────────────────────────────
          SizedBox(
            width: productWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasBarcode)
                  SelectableText(
                    item.barcode!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          // ── İskonto (kompakt rozet → düzenleme dialog'u) ────────────────
          SizedBox(
            width: CartTable._wDisc,
            child: _CompactDiscountCell(
              value: item.discountValue,
              type: item.discountType,
              onApply: (value, type) =>
                  notifier.updateItemDiscount(index, value, type),
            ),
          ),
          // ── Miktar ───────────────────────────────────────────────────────
          SizedBox(
            width: CartTable._wQty,
            child: _QuantityControl(
              key: ValueKey('qty-$index'),
              quantity: item.quantity,
              onChanged: (q) => notifier.updateItemQuantity(index, q),
            ),
          ),
          // ── Birim fiyat (elle düzenlenebilir + "Fiyat1 yap") ─────────────
          SizedBox(
            width: CartTable._wPrice,
            child: _UnitPriceControl(
              key: ValueKey('price-$index'),
              unitPrice: item.unitPrice,
              productId: item.productId,
              onChanged: (p) => notifier.updateItemUnitPrice(index, p),
            ),
          ),
          // ── Satır tutarı ─────────────────────────────────────────────────
          SizedBox(
            width: CartTable._wTotal,
            child: Text(
              formatCurrency(item.total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // ── Sil ──────────────────────────────────────────────────────────
          SizedBox(
            width: CartTable._wDel,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.danger,
              ),
              onPressed: () => notifier.removeItem(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer (Muhtelif · Genel İskonto · Ara Toplam/İndirim/Toplam) ─────────
  // Panele sığarsa toplamlar sağa yaslanır; sığmazsa footer yatay kaydırılır →
  // hiçbir genişlikte toplamlar kırpılmaz (IntrinsicWidth + minWidth güvenlik ağı).
  Widget _buildFooter(
    BuildContext context,
    CustomerTabState tab,
    SalesCart notifier,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSizes.space8,
            horizontal: AppSizes.space12,
          ),
          child: Row(
            children: [
              // Masaüstü "+Muhtelif" footer butonu KALDIRILDI (KARAR v1.6.2);
              // ekleme artık tablodaki satır-içi "+" satırından yapılır. Mobil
              // footer butonu ve _showAddMiscDialog korunur.
              _CompactDiscountCell(
                value: tab.discountValue,
                type: tab.discountType,
                onApply: (value, type) => notifier.setDiscount(value, type),
                leadingLabel: 'Genel İskonto',
              ),
              const Spacer(),
              // Footer Ara Toplam/İndirim odağına alınır; genel toplamın TEK sahibi
              // ödeme panelindeki hero tutardır (§4) — buradaki Toplam normal ağırlıkta.
              Text(
                'Ara Toplam: ${formatCurrency(tab.subtotal)}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (tab.discountAmount > 0) ...[
                const SizedBox(width: AppSizes.space16),
                Text(
                  'İndirim: -${formatCurrency(tab.discountAmount)}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: AppSizes.space16),
              Text(
                'Toplam: ${formatCurrency(tab.total)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicWidth(child: row),
          ),
        );
      },
    );
  }

  Future<void> _showAddMiscDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Muhtelif Tutar Ekle'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tutar'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = num.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    ref
        .read(salesCartProvider.notifier)
        .addMiscItem(amount, note: noteCtrl.text);
  }

  // ── Toplu % iskonto dialog'u ───────────────────────────────────────────────
  //
  // Mevcut _DiscountDialog %/₺ ikisini birden destekler — bu dialog KASITLI
  // olarak SADECE yüzde alır (tip seçici YOK), seçili TÜM satırlara uygulanır.
  // Tekil satır iskontosu (_CompactDiscountCell/_DiscountDialog) mekanizmasına
  // dokunmaz; yalnızca aynı notifier metodunu (updateItemDiscount) döngüyle
  // seçili her index için çağırır.
  Future<void> _showBulkPercentDialog(
    BuildContext context,
    SalesCart notifier,
  ) async {
    final ctrl = TextEditingController();
    final percent = await showDialog<num>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Seçili ${_selected.length} Ürüne % İndirim'),
        content: SizedBox(
          width: 240,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'İndirim Yüzdesi',
              suffixText: '%',
            ),
            onSubmitted: (_) => Navigator.of(
              dialogContext,
            ).pop(num.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(num.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    if (percent == null || percent <= 0) return;
    // Dialog kapandıktan SONRA state güncellemesi yapılır (proje kuralı).
    for (final index in _selected) {
      notifier.updateItemDiscount(index, percent, DiscountType.percent);
    }
    _clearSelection();
  }
}

// ── Satır seçim toggle'ı (çoklu satır seçimi, toplu % iskonto aksiyonu) ────
//
// Satırın EN SOLUNDA. Ürün formu vb. yerlerdeki "Fiyat1 yap" radyosuyla
// (_UnitPriceControl._buildPrice1Radio) AYNI boş/dolu ikon çiftini kullanır
// ama TAMAMEN farklı bir konumda ve işlevdedir — karıştırılmamalı.
class _RowSelectToggle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const _RowSelectToggle({
    super.key,
    required this.selected,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space4),
        child: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          size: size,
          color: selected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Satır-içi muhtelif ürün ekleme satırı (yalnız masaüstü) ────────────────
//
// design-tokens §5, KARAR v1.6.2. Tablonun sıradaki boş satırında (son ürünün
// altında; sepet boşsa 1. satır) durur. Header/item satırlarıyla BİREBİR aynı
// kolon genişlikleri + aynı Padding → kolon hizası korunur.
//
// Toplanmış (varsayılan): Ürün sütununun en solunda sade bir "+" ikonu
// (tooltip "Muhtelif ürün ekle"); sepet boşsa yanında muted keşif ipucu. Diğer
// sütunlar boş. Açık (+'ya basınca): Ürün adı alanı Ürün sütununda (autofocus),
// Fiyat alanı Fiyat sütununda; İskonto/Miktar sütunları boş kalır. Onay (✓)
// Tutar sütununda, vazgeç (✕) Sil sütununda. Onayda addMiscItem(fiyat, not=ad)
// çağrılır → kalem normal satır olur, "+" satırı bir alta iner ve toplanır.
class _AddMiscRow extends ConsumerStatefulWidget {
  final double productWidth;
  final bool showHint;

  const _AddMiscRow({required this.productWidth, required this.showHint});

  @override
  ConsumerState<_AddMiscRow> createState() => _AddMiscRowState();
}

class _AddMiscRowState extends ConsumerState<_AddMiscRow> {
  bool _expanded = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _expanded = true);
    // Ad alanına autofocus (satır açıldıktan sonra frame'de).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  void _cancel() {
    _nameCtrl.clear();
    _priceCtrl.clear();
    setState(() => _expanded = false);
  }

  void _confirm() {
    final price = num.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    // Fiyat boş/0/geçersiz → sessizce yok say (alan açık kalır).
    if (price == null || price <= 0) return;
    final name = _nameCtrl.text.trim();
    ref
        .read(salesCartProvider.notifier)
        .addMiscItem(price, note: name.isEmpty ? 'Muhtelif' : name);
    _nameCtrl.clear();
    _priceCtrl.clear();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space6,
      ),
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  // Toplanmış: Ürün sütununda "+" ikonu (+ opsiyonel ipucu); kalan sütunlar boş.
  Widget _buildCollapsed() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Seç sütunu — muhtelif ekleme satırı seçilebilir bir sepet kalemi
        // DEĞİL, yalnız kolon hizası korunsun diye boş bırakılır.
        const SizedBox(width: CartTable._wSelect),
        SizedBox(
          width: widget.productWidth,
          child: Row(
            children: [
              Tooltip(
                message: 'Muhtelif ürün ekle',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  onTap: _open,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSizes.space4),
                    child: Icon(Icons.add, size: 20, color: AppColors.primary),
                  ),
                ),
              ),
              if (widget.showHint) ...[
                const SizedBox(width: AppSizes.space8),
                const Flexible(
                  child: Text(
                    'Barkod okutun veya + ile muhtelif ekleyin',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: CartTable._wDisc),
        const SizedBox(width: CartTable._wQty),
        const SizedBox(width: CartTable._wPrice),
        const SizedBox(width: CartTable._wTotal),
        const SizedBox(width: CartTable._wDel),
      ],
    );
  }

  // Açık: Ürün adı (Ürün sütunu) · Fiyat (Fiyat sütunu) · ✓ (Tutar) · ✕ (Sil).
  Widget _buildExpanded() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Seç sütunu boş (hizayı korur) — bkz. _buildCollapsed.
        const SizedBox(width: CartTable._wSelect),
        // ── Ürün adı ─────────────────────────────────────────────────────
        SizedBox(
          width: widget.productWidth,
          child: TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Ürün adı',
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            style: const TextStyle(fontSize: 13),
            textInputAction: TextInputAction.next,
          ),
        ),
        // ── İskonto / Miktar sütunları boş (hizayı korur) ────────────────
        const SizedBox(width: CartTable._wDisc),
        const SizedBox(width: CartTable._wQty),
        // ── Fiyat ────────────────────────────────────────────────────────
        SizedBox(
          width: CartTable._wPrice,
          child: TextField(
            controller: _priceCtrl,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              prefixText: '₺ ',
              hintText: '0',
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ),
        // ── Onay (Tutar sütunu) ──────────────────────────────────────────
        SizedBox(
          width: CartTable._wTotal,
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.check, size: 20, color: AppColors.success),
              tooltip: 'Ekle',
              onPressed: _confirm,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ),
        // ── Vazgeç (Sil sütunu) ──────────────────────────────────────────
        SizedBox(
          width: CartTable._wDel,
          child: IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            tooltip: 'Vazgeç',
            onPressed: _cancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
      ],
    );
  }
}

// ── Mobil sepet kartı ─────────────────────────────────────────────────────
//
// [Seç] [%15 Adet] [%65 İsim / Barkod · Fiyat] [%20 Tutar]

class _MobileCartItem extends StatelessWidget {
  final dynamic item; // CartItem
  final int index;
  final bool selected;
  final VoidCallback onToggleSelect;
  final ValueChanged<num> onQuantityChanged;
  final ValueChanged<num> onUnitPriceChanged;
  final void Function(num value, DiscountType type) onDiscountChanged;
  final VoidCallback onRemove;

  const _MobileCartItem({
    required this.item,
    required this.index,
    required this.selected,
    required this.onToggleSelect,
    required this.onQuantityChanged,
    required this.onUnitPriceChanged,
    required this.onDiscountChanged,
    required this.onRemove,
  });

  Future<void> _editQuantity(BuildContext context) async {
    final result = await showDialog<(num, num)>(
      context: context,
      builder: (dialogContext) => _MobileQtyDialog(
        initialQuantity: item.quantity,
        unitPrice: item.unitPrice,
        productId: item.productId as String?,
      ),
    );
    // State güncellemesi dialog kapandıktan SONRA yapılır: adet + birim fiyat.
    if (result != null) {
      onQuantityChanged(result.$1);
      onUnitPriceChanged(result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('cart-item-$index-${item.productId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onRemove(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Seç (çoklu satır seçimi — toplu % iskonto aksiyonu) ────
            _RowSelectToggle(
              key: ValueKey('row-select-$index'),
              selected: selected,
              onTap: onToggleSelect,
              size: 18,
            ),
            // ── %15: Adet (dokunulabilir) ──────────────────────────
            GestureDetector(
              onTap: () => _editQuantity(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _fmtQty(item.quantity),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── %65: Üst satır: ürün adı | Alt satır: barkod + fiyat ──
            Expanded(
              flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: item.barcode != null && item.barcode!.isNotEmpty
                            ? SelectableText(
                                item.barcode!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                maxLines: 1,
                              )
                            : Text(
                                item.note ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      Text(
                        formatCurrency(item.unitPrice),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── İskonto girişi (48px hedef → web ile aynı _DiscountDialog) ──
            _MobileDiscountButton(
              value: item.discountValue,
              type: item.discountType,
              onApply: onDiscountChanged,
            ),
            const SizedBox(width: 4),
            // ── %20: Tutar ─────────────────────────────────────────
            SizedBox(
              width: 72,
              child: Text(
                formatCurrency(item.total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(num q) {
    if (q == q.truncate()) return q.toInt().toString();
    return q.toStringAsFixed(2);
  }
}

// ── İskonto dialog açıcı (web + mobil ortak) ───────────────────────────────
//
// Hem satır hem sepet bazı iskonto için aynı _DiscountDialog'u açar (web ile
// AYNI %/₺ deneyimi). Seçilen değer/tür dialog kapandıktan SONRA onApply'a
// iletilir (notifier davranışı korunur).
Future<void> _openDiscountDialog(
  BuildContext context, {
  required num value,
  required DiscountType type,
  required void Function(num value, DiscountType type) onApply,
}) async {
  final result = await showDialog<(num, DiscountType)>(
    context: context,
    builder: (dialogContext) =>
        _DiscountDialog(initialValue: value, initialType: type),
  );
  // State güncellemesi dialog kapandıktan SONRA yapılır.
  if (result != null) onApply(result.$1, result.$2);
}

// ── Mobil satır iskonto butonu ─────────────────────────────────────────────
//
// 48×48 dokunma hedefi (§3). İskonto yoksa nötr yüzde ikonu (altın serpilmez,
// §5); aktifse danger renkli tabular rozet (%10 / 10 ₺). Dokununca web ile
// aynı _DiscountDialog açılır → updateItemDiscount.
class _MobileDiscountButton extends StatelessWidget {
  final num value;
  final DiscountType type;
  final void Function(num value, DiscountType type) onApply;

  const _MobileDiscountButton({
    required this.value,
    required this.type,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    final label = type == DiscountType.percent
        ? '%${_qtyText(value)}'
        : '${_qtyText(value)} ₺';
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      onTap: () => _openDiscountDialog(
        context,
        value: value,
        type: type,
        onApply: onApply,
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        child: active
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space6,
                  vertical: AppSizes.space2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              )
            : const Icon(Icons.percent, size: 20, color: AppColors.textMuted),
      ),
    );
  }
}

// ── Kompakt İskonto Hücresi ────────────────────────────────────────────────
//
// Satır içinde dar bir rozet gösterir: iskonto varsa "%10" / "10 ₺", yoksa "İsk.".
// Dokununca _DiscountDialog açılır (%/₺ seçimi + değer). Eski 175px'lik satır içi
// alanın yerini alır → İskonto sütunu 96px'e iner, dar panelde kırpma riski kalmaz.
class _CompactDiscountCell extends StatelessWidget {
  final num value;
  final DiscountType type;
  final void Function(num value, DiscountType type) onApply;
  final String? leadingLabel;

  const _CompactDiscountCell({
    required this.value,
    required this.type,
    required this.onApply,
    this.leadingLabel,
  });

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<(num, DiscountType)>(
      context: context,
      builder: (dialogContext) =>
          _DiscountDialog(initialValue: value, initialType: type),
    );
    // State güncellemesi dialog kapandıktan SONRA yapılır.
    if (result != null) onApply(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    final label = active
        ? (type == DiscountType.percent
              ? '%${_qtyText(value)}'
              : '${_qtyText(value)} ₺')
        : 'İsk.';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingLabel != null) ...[
          Text(
            leadingLabel!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(width: AppSizes.space8),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          onTap: () => _edit(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space8,
              vertical: AppSizes.space4,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.goldBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.goldBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.edit : Icons.add,
                  size: 13,
                  color: active ? AppColors.goldLight : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.space4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppColors.goldLight
                        : AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── İskonto düzenleme dialog'u ─────────────────────────────────────────────
class _DiscountDialog extends StatefulWidget {
  final num initialValue;
  final DiscountType initialType;

  const _DiscountDialog({
    required this.initialValue,
    required this.initialType,
  });

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late TextEditingController _ctrl;
  late DiscountType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _ctrl = TextEditingController(
      text: widget.initialValue == 0 ? '' : _qtyText(widget.initialValue),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = num.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
    Navigator.of(context).pop((value, _type));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İskonto'),
      content: SizedBox(
        width: 280,
        child: Row(
          children: [
            _TypeChip(
              label: '%',
              selected: _type == DiscountType.percent,
              onTap: () => setState(() => _type = DiscountType.percent),
            ),
            const SizedBox(width: AppSizes.space4),
            _TypeChip(
              label: '₺',
              selected: _type == DiscountType.tl,
              onTap: () => setState(() => _type = DiscountType.tl),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: _type == DiscountType.percent ? '%' : '₺',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (_) => _submit(),
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
        ElevatedButton(onPressed: _submit, child: const Text('Uygula')),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space8,
          vertical: AppSizes.space4,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.goldBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.goldBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.goldLight : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Miktar metni biçimleyici ───────────────────────────────────────────────
// Tam sayı ise "2", ondalıklı ise "2.5" gibi gösterir.
String _qtyText(num q) =>
    q == q.truncate() ? q.toInt().toString() : q.toString();

// ── Satır içi miktar kontrolü ( - [alan] + ) ───────────────────────────────
//
// Sol "-" butonu KIRMIZI, sağ "+" butonu lacivert. Alana yazılan her karakterde
// (onChanged) miktar canlı olarak notifier'a iletilir; böylece satır toplamı
// anında güncellenir. Geçersiz/boş giriş yok sayılır (eski değer korunur).
class _QuantityControl extends StatefulWidget {
  final num quantity;
  final ValueChanged<num> onChanged;

  const _QuantityControl({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<_QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<_QuantityControl> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _qtyText(widget.quantity));
  }

  @override
  void didUpdateWidget(covariant _QuantityControl old) {
    super.didUpdateWidget(old);
    // Dışarıdan (ör. +/- veya başka bir akış) gelen değer, alandaki değerden
    // farklıysa metni güncelle. Kullanıcı yazarken (değerler eşitken) dokunma —
    // imleç kaymasın.
    final current = num.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (widget.quantity != current) {
      _ctrl.text = _qtyText(widget.quantity);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setText(num q) {
    _ctrl.text = _qtyText(q);
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  void _delta(num d) {
    final current =
        num.tryParse(_ctrl.text.replaceAll(',', '.')) ?? widget.quantity;
    var next = current + d;
    if (next < 1) next = 1;
    _setText(next);
    widget.onChanged(next);
  }

  void _onChanged(String v) {
    final parsed = num.tryParse(v.replaceAll(',', '.'));
    // Boş veya geçersiz giriş -> dokunma. Sıfır/negatif -> kabul etme.
    if (parsed != null && parsed > 0) {
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QtyBtn(
          icon: Icons.remove,
          color: AppColors.danger,
          onTap: () => _delta(-1),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(width: 2),
        _QtyBtn(
          icon: Icons.add,
          color: AppColors.primary,
          onTap: () => _delta(1),
        ),
      ],
    );
  }
}

// ── Miktar +/- butonu ──────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _QtyBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ── Satır içi "Fiyat1 yap" onay durumu ─────────────────────────────────────
enum _PriceStatus { idle, saving, success, error }

// ── Satır içi birim fiyat kontrolü (elle düzenlenebilir + "Fiyat1 yap") ────
//
// design-tokens §5, KARAR v1.6.1. Solda elle düzenlenebilir fiyat alanı: her tuş
// vuruşunda satır tutarı anında güncellenir (ondalık destekli). Fiyat hanesinin
// HEMEN yanında, yalnız `productId != null` satırlarda, çıplak "Fiyat1 yap"
// radyosu (etiketsiz; keşif için hover tooltip'i) → ürünün kalıcı satış fiyatını
// (products.price1) DB'de günceller. Başarıda ~2.5 sn yeşil "Fiyat güncellendi"
// pill'i fiyatın ALTINDA (success, §1 — altın DEĞİL); hatada kırmızı kısa uyarı.
class _UnitPriceControl extends StatefulWidget {
  final num unitPrice;
  final String? productId;
  final ValueChanged<num> onChanged;

  const _UnitPriceControl({
    super.key,
    required this.unitPrice,
    required this.productId,
    required this.onChanged,
  });

  @override
  State<_UnitPriceControl> createState() => _UnitPriceControlState();
}

class _UnitPriceControlState extends State<_UnitPriceControl> {
  late TextEditingController _ctrl;
  _PriceStatus _status = _PriceStatus.idle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _qtyText(widget.unitPrice));
  }

  @override
  void didUpdateWidget(covariant _UnitPriceControl old) {
    super.didUpdateWidget(old);
    // Dışarıdan gelen fiyat (ör. başka akış) alandakinden farklıysa metni
    // güncelle; kullanıcı yazarken (değerler eşitken) dokunma → imleç kaymasın.
    final current = num.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (widget.unitPrice != current) {
      _ctrl.text = _qtyText(widget.unitPrice);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // Her tuş vuruşunda: geçerli (>= 0) değeri notifier'a ilet → satır tutarı anında.
  void _onChanged(String v) {
    final parsed = num.tryParse(v.replaceAll(',', '.'));
    if (parsed != null && parsed >= 0) {
      widget.onChanged(parsed);
    }
  }

  Future<void> _setPrice1() async {
    final productId = widget.productId;
    if (productId == null) return;
    final price = num.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (price == null || price < 0) return;
    setState(() => _status = _PriceStatus.saving);
    try {
      await ProductRepository().updatePrice1(productId, price);
      if (!mounted) return;
      setState(() => _status = _PriceStatus.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _PriceStatus.error);
    }
    _scheduleReset();
  }

  void _scheduleReset() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _status = _PriceStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fiyat hanesi + hemen sağında çıplak "Fiyat1 yap" radyosu (yalnız gerçek
    // ürün + idle). Saving/success/error bildirimleri fiyatın ALTINDA kalır.
    final showRadio = widget.productId != null && _status == _PriceStatus.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '₺ ',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                onChanged: _onChanged,
              ),
            ),
            if (showRadio) _buildPrice1Radio(),
          ],
        ),
        if (widget.productId != null && _status != _PriceStatus.idle) ...[
          const SizedBox(height: AppSizes.space4),
          _buildStatusPill(),
        ],
      ],
    );
  }

  // Çıplak "Fiyat1 yap" radyosu — fiyat hanesinin hemen yanında, etiketsiz;
  // keşif için yalnız hover tooltip'i (KARAR v1.6.1). Rengi textSecondary.
  Widget _buildPrice1Radio() {
    return Tooltip(
      message: 'Fiyat1 yap',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        onTap: _setPrice1,
        child: const Padding(
          padding: EdgeInsets.all(AppSizes.space4),
          child: Icon(
            Icons.radio_button_unchecked,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Kalıcı fiyat güncelleme bildirimi (fiyatın altında): spinner / yeşil onay
  // pill'i / kırmızı hata. Idle'da hiçbir şey göstermez (radyo yukarıda).
  Widget _buildStatusPill() {
    switch (_status) {
      case _PriceStatus.saving:
        return const SizedBox(
          height: 20,
          width: 20,
          child: Padding(
            padding: EdgeInsets.all(3),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _PriceStatus.success:
        return const _PriceStatusPill(
          label: 'Fiyat güncellendi',
          icon: Icons.check,
          color: AppColors.success,
        );
      case _PriceStatus.error:
        return const _PriceStatusPill(
          label: 'Güncellenemedi',
          icon: Icons.error_outline,
          color: AppColors.danger,
        );
      case _PriceStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

// Kısa süreli durum pill'i (yeşil onay / kırmızı hata). type.utility.
class _PriceStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PriceStatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: AppSizes.space4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobil miktar düzenleme dialog'u ────────────────────────────────────────
//
// -/+ butonları ve metin alanı; her değişimde satır toplamı canlı güncellenir.
// Ayrıca elle düzenlenebilir birim fiyat + "Fiyat1 yap" kontrolü (KARAR v1.6).
// "Tamam" ile seçilen miktar + fiyat Navigator.pop ile geri döner (state sonra).
class _MobileQtyDialog extends StatefulWidget {
  final num initialQuantity;
  final num unitPrice;
  final String? productId;

  const _MobileQtyDialog({
    required this.initialQuantity,
    required this.unitPrice,
    required this.productId,
  });

  @override
  State<_MobileQtyDialog> createState() => _MobileQtyDialogState();
}

class _MobileQtyDialogState extends State<_MobileQtyDialog> {
  late TextEditingController _ctrl;
  late TextEditingController _priceCtrl;
  late num _qty;
  late num _price;
  _PriceStatus _status = _PriceStatus.idle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQuantity;
    _price = widget.unitPrice;
    _ctrl = TextEditingController(text: _qtyText(_qty));
    _priceCtrl = TextEditingController(text: _qtyText(_price));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _setQty(num q) {
    _ctrl.text = _qtyText(q);
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() => _qty = q);
  }

  void _delta(num d) {
    var next = _qty + d;
    if (next < 1) next = 1;
    _setQty(next);
  }

  void _onChanged(String v) {
    final parsed = num.tryParse(v.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) {
      setState(() => _qty = parsed);
    }
  }

  void _onPriceChanged(String v) {
    final parsed = num.tryParse(v.replaceAll(',', '.'));
    if (parsed != null && parsed >= 0) {
      setState(() => _price = parsed);
    }
  }

  Future<void> _setPrice1() async {
    final productId = widget.productId;
    if (productId == null) return;
    setState(() => _status = _PriceStatus.saving);
    try {
      await ProductRepository().updatePrice1(productId, _price);
      if (!mounted) return;
      setState(() => _status = _PriceStatus.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _PriceStatus.error);
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _status = _PriceStatus.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adet & Fiyat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Adet ──────────────────────────────────────────────────────
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove,
                color: AppColors.danger,
                onTap: () => _delta(-1),
                size: 40,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Adet',
                    isDense: true,
                  ),
                  onChanged: _onChanged,
                ),
              ),
              const SizedBox(width: 8),
              _QtyBtn(
                icon: Icons.add,
                color: AppColors.primary,
                onTap: () => _delta(1),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Birim fiyat (elle düzenlenebilir) + bitişik Fiyat1 radyosu ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Birim Fiyat',
                    prefixText: '₺ ',
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  onChanged: _onPriceChanged,
                ),
              ),
              // Çıplak "Fiyat1 yap" radyosu — fiyat alanının hemen yanında
              // (etiketsiz; hover tooltip). Yalnız gerçek ürün + idle.
              if (widget.productId != null && _status == _PriceStatus.idle) ...[
                const SizedBox(width: AppSizes.space8),
                _buildPrice1Radio(),
              ],
            ],
          ),
          // Kalıcı fiyat bildirimi (spinner/success/error) fiyatın altında.
          if (widget.productId != null && _status != _PriceStatus.idle) ...[
            const SizedBox(height: AppSizes.space8),
            Align(alignment: Alignment.centerLeft, child: _buildStatusPill()),
          ],
          const SizedBox(height: 16),
          Text(
            'Satır Toplamı: ${formatCurrency(_qty * _price)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop((_qty, _price)),
          child: const Text('Tamam'),
        ),
      ],
    );
  }

  // Çıplak "Fiyat1 yap" radyosu — fiyat alanının hemen yanında, etiketsiz;
  // keşif için yalnız hover tooltip'i (KARAR v1.6.1). Rengi textSecondary.
  Widget _buildPrice1Radio() {
    return Tooltip(
      message: 'Fiyat1 yap',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        onTap: _setPrice1,
        child: const Padding(
          padding: EdgeInsets.all(AppSizes.space6),
          child: Icon(
            Icons.radio_button_unchecked,
            size: 22,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Kalıcı fiyat güncelleme bildirimi (fiyatın altında): spinner / yeşil onay
  // pill'i / kırmızı hata. Idle'da hiçbir şey göstermez (radyo yanda).
  Widget _buildStatusPill() {
    switch (_status) {
      case _PriceStatus.saving:
        return const SizedBox(
          height: 20,
          width: 20,
          child: Padding(
            padding: EdgeInsets.all(3),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _PriceStatus.success:
        return const _PriceStatusPill(
          label: 'Fiyat güncellendi',
          icon: Icons.check,
          color: AppColors.success,
        );
      case _PriceStatus.error:
        return const _PriceStatusPill(
          label: 'Güncellenemedi',
          icon: Icons.error_outline,
          color: AppColors.danger,
        );
      case _PriceStatus.idle:
        return const SizedBox.shrink();
    }
  }
}
