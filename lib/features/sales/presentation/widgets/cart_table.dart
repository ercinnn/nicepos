import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/sales_cart_notifier.dart';

class CartTable extends ConsumerWidget {
  const CartTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesCartProvider);
    final notifier = ref.read(salesCartProvider.notifier);
    final tab = salesState.active;

    if (context.isMobile) {
      return _buildMobileList(context, ref, tab, notifier);
    }
    return _buildDesktopTable(context, ref, tab, notifier);
  }

  // ─── Mobil kart listesi ──────────────────────────────────────────────────

  Widget _buildMobileList(
    BuildContext context,
    WidgetRef ref,
    CustomerTabState tab,
    SalesCart notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      onQuantityChanged: (q) =>
                          notifier.updateItemQuantity(index, q),
                      onDiscountChanged: (v, t) =>
                          notifier.updateItemDiscount(index, v, t),
                      onRemove: () => notifier.removeItem(index),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Alt özet satırı
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddMiscDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Muhtelif', style: TextStyle(fontSize: 12)),
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
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
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
                            horizontal: AppSizes.space4),
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
                                  FontFeature.tabularFigures()
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
        ),
      ],
    );
  }

  // ─── Masaüstü sabit genişlikli tablo ─────────────────────────────────────
  //
  // Kolon genişlikleri (px): İskonto 96 · Miktar 116 · Fiyat 88 · Tutar 88 · Sil 40
  // Ürün sütunu kalan alanı alır; ancak en az _wProductMin korunur. Toplam genişlik
  // panele sığmazsa tablo yatay kaydırılır (kırpma/çökme yok).
  //
  // İskonto sütunu eskiden 175px'lik satır içi alan idi; kompakt rozet + düzenleme
  // dialog'una (_CompactDiscountCell) taşındığı için 96px'e indi → dar panelde
  // ürün sütununa nefes kalır.

  static const double _wDisc       = 96;
  static const double _wQty        = 116;
  static const double _wPrice      = 88;
  static const double _wTotal      = 88;
  static const double _wDel        = 40;
  static const double _wProductMin = 220; // ürün adının dikey karaktere çökmesini önler

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  Widget _buildDesktopTable(
    BuildContext context,
    WidgetRef ref,
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
              const fixed = _wDisc + _wQty + _wPrice + _wTotal + _wDel;
              const hPad = AppSizes.space12 * 2; // satır/başlık yatay iç boşluk
              final available = constraints.maxWidth;
              final room = available - fixed - hPad;
              final productWidth = room >= _wProductMin ? room : _wProductMin;
              final tableWidth = fixed + hPad + productWidth;
              final needsScroll = tableWidth > available + 0.5;

              final table = SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(productWidth),
                    const Divider(height: 1),
                    Expanded(
                      child: tab.items.isEmpty
                          ? const EmptyState(
                              icon: Icons.shopping_cart_outlined,
                              title: 'Sepet boş',
                              message: 'Barkod okutun veya sağdan ürün seçin',
                            )
                          : ListView.separated(
                              itemCount: tab.items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, index) => _buildItemRow(
                                productWidth, index, tab.items[index], notifier),
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
        _buildFooter(context, ref, tab, notifier),
      ],
    );
  }

  // ── Başlık satırı ──────────────────────────────────────────────────────────
  Widget _buildHeaderRow(double productWidth) {
    return Container(
      color: AppColors.tableHeader,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12, vertical: AppSizes.space8),
      child: Row(
        children: [
          SizedBox(width: productWidth, child: const Text('Ürün', style: _headerStyle)),
          SizedBox(width: _wDisc,  child: const Text('İskonto', style: _headerStyle)),
          SizedBox(width: _wQty,   child: const Text('Miktar',  style: _headerStyle)),
          SizedBox(width: _wPrice, child: const Text('Fiyat',   style: _headerStyle, textAlign: TextAlign.right)),
          SizedBox(width: _wTotal, child: const Text('Tutar',   style: _headerStyle, textAlign: TextAlign.right)),
          const SizedBox(width: _wDel),
        ],
      ),
    );
  }

  // ── Tek bir sepet satırı ─────────────────────────────────────────────────
  Widget _buildItemRow(
      double productWidth, int index, dynamic item, SalesCart notifier) {
    final hasBarcode = item.barcode != null && item.barcode!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12, vertical: AppSizes.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
            width: _wDisc,
            child: _CompactDiscountCell(
              value: item.discountValue,
              type: item.discountType,
              onApply: (value, type) =>
                  notifier.updateItemDiscount(index, value, type),
            ),
          ),
          // ── Miktar ───────────────────────────────────────────────────────
          SizedBox(
            width: _wQty,
            child: _QuantityControl(
              key: ValueKey('qty-$index'),
              quantity: item.quantity,
              onChanged: (q) => notifier.updateItemQuantity(index, q),
            ),
          ),
          // ── Birim fiyat ──────────────────────────────────────────────────
          SizedBox(
            width: _wPrice,
            child: Text(
              formatCurrency(item.unitPrice),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // ── Satır tutarı ─────────────────────────────────────────────────
          SizedBox(
            width: _wTotal,
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
            width: _wDel,
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.danger),
              onPressed: () => notifier.removeItem(index),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
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
    WidgetRef ref,
    CustomerTabState tab,
    SalesCart notifier,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSizes.space8, horizontal: AppSizes.space12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddMiscDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Muhtelif'),
              ),
              const SizedBox(width: AppSizes.space16),
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

  Future<void> _showAddMiscDialog(
      BuildContext context, WidgetRef ref) async {
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
                decoration:
                    const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç')),
          ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ekle')),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount =
        num.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    ref
        .read(salesCartProvider.notifier)
        .addMiscItem(amount, note: noteCtrl.text);
  }
}

// ── Mobil sepet kartı ─────────────────────────────────────────────────────
//
// [%15 Adet] [%65 İsim / Barkod · Fiyat] [%20 Tutar]

class _MobileCartItem extends StatelessWidget {
  final dynamic item;   // CartItem
  final int index;
  final ValueChanged<num> onQuantityChanged;
  final void Function(num value, DiscountType type) onDiscountChanged;
  final VoidCallback onRemove;

  const _MobileCartItem({
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    required this.onDiscountChanged,
    required this.onRemove,
  });

  Future<void> _editQuantity(BuildContext context) async {
    final result = await showDialog<num>(
      context: context,
      builder: (dialogContext) => _MobileQtyDialog(
        initialQuantity: item.quantity,
        unitPrice: item.unitPrice,
      ),
    );
    // State güncellemesi dialog kapandıktan SONRA yapılır.
    if (result != null) onQuantityChanged(result);
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
                      color: AppColors.primary.withValues(alpha: 0.25)),
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
                                    fontFeatures: [FontFeature.tabularFigures()]),
                                maxLines: 1,
                              )
                            : Text(
                                item.note ?? '',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      Text(
                        formatCurrency(item.unitPrice),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()]),
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
                    horizontal: AppSizes.space6, vertical: AppSizes.space2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.40)),
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
                horizontal: AppSizes.space8, vertical: AppSizes.space4),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.goldBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              border: Border.all(
                  color: active ? AppColors.primary : AppColors.goldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.edit : Icons.add,
                  size: 13,
                  color:
                      active ? AppColors.goldLight : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.space4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? AppColors.goldLight : AppColors.textSecondary,
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Uygula'),
        ),
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
            horizontal: AppSizes.space8, vertical: AppSizes.space4),
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
    _ctrl.selection =
        TextSelection.collapsed(offset: _ctrl.text.length);
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            ),
            style: const TextStyle(
                fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
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

// ── Mobil miktar düzenleme dialog'u ────────────────────────────────────────
//
// -/+ butonları ve metin alanı; her değişimde satır toplamı canlı güncellenir.
// "Tamam" ile seçilen miktar Navigator.pop ile geri döner (state pop'tan sonra).
class _MobileQtyDialog extends StatefulWidget {
  final num initialQuantity;
  final num unitPrice;

  const _MobileQtyDialog({
    required this.initialQuantity,
    required this.unitPrice,
  });

  @override
  State<_MobileQtyDialog> createState() => _MobileQtyDialogState();
}

class _MobileQtyDialogState extends State<_MobileQtyDialog> {
  late TextEditingController _ctrl;
  late num _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQuantity;
    _ctrl = TextEditingController(text: _qtyText(_qty));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setQty(num q) {
    _ctrl.text = _qtyText(q);
    _ctrl.selection =
        TextSelection.collapsed(offset: _ctrl.text.length);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Adet giriniz',
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
          Text(
            'Satır Toplamı: ${formatCurrency(_qty * widget.unitPrice)}',
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
          onPressed: () => Navigator.of(context).pop(_qty),
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
