import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
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
              ? const Center(
                  child: Text(
                    'Sepet boş.\nBarkod okutun veya ürün seçin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
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
                  Text(
                    'Toplam: ${formatCurrency(tab.total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (tab.discountAmount > 0)
                    Text(
                      'İskonto: -${formatCurrency(tab.discountAmount)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger),
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
  // Kolon genişlikleri (px): İskonto 175 · Miktar 78 · Fiyat 88 · Tutar 88 · Sil 40
  // Ürün sütunu kalan alanın tamamını alır (Expanded).

  static const double _wDisc  = 175;
  static const double _wQty   = 78;
  static const double _wPrice = 88;
  static const double _wTotal = 88;
  static const double _wDel   = 40;

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
        // ── Başlık satırı ──────────────────────────────────────────────────
        Container(
          color: AppColors.tableHeader,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Expanded(child: Text('Ürün', style: _headerStyle)),
              SizedBox(width: _wDisc,  child: const Text('İskonto', style: _headerStyle)),
              SizedBox(width: _wQty,   child: const Text('Miktar',  style: _headerStyle)),
              SizedBox(width: _wPrice, child: const Text('Fiyat',   style: _headerStyle, textAlign: TextAlign.right)),
              SizedBox(width: _wTotal, child: const Text('Tutar',   style: _headerStyle, textAlign: TextAlign.right)),
              SizedBox(width: _wDel),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Satır listesi ──────────────────────────────────────────────────
        Expanded(
          child: tab.items.isEmpty
              ? const Center(
                  child: Text(
                    'Sepet boş. Barkod okutun veya ürün seçin.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  itemCount: tab.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = tab.items[index];
                    final hasBarcode =
                        item.barcode != null && item.barcode!.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Ürün adı + barkod ───────────────────────────
                          Expanded(
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
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // ── İskonto ────────────────────────────────────
                          SizedBox(
                            width: _wDisc,
                            child: _DiscountField(
                              key: ValueKey(
                                  'item-disc-$index-${item.discountValue}-${item.discountType}'),
                              initialValue: item.discountValue,
                              initialType: item.discountType,
                              onApply: (value, type) => notifier
                                  .updateItemDiscount(index, value, type),
                            ),
                          ),
                          // ── Miktar ─────────────────────────────────────
                          SizedBox(
                            width: _wQty,
                            child: TextFormField(
                              key: ValueKey('qty-$index-${item.quantity}'),
                              initialValue: item.quantity.toString(),
                              decoration: const InputDecoration(),
                              keyboardType: TextInputType.number,
                              onFieldSubmitted: (v) {
                                final value =
                                    num.tryParse(v.replaceAll(',', '.')) ??
                                        item.quantity;
                                notifier.updateItemQuantity(index, value);
                              },
                            ),
                          ),
                          // ── Birim fiyat ────────────────────────────────
                          SizedBox(
                            width: _wPrice,
                            child: Text(
                              formatCurrency(item.unitPrice),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          // ── Satır tutarı ───────────────────────────────
                          SizedBox(
                            width: _wTotal,
                            child: Text(
                              formatCurrency(item.total),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          // ── Sil ───────────────────────────────────────
                          SizedBox(
                            width: _wDel,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.danger),
                              onPressed: () => notifier.removeItem(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddMiscDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Muhtelif Tutar Ekle'),
              ),
              const Spacer(),
              _DiscountField(
                key: ValueKey(
                    'cart-disc-${tab.discountValue}-${tab.discountType}'),
                initialValue: tab.discountValue,
                initialType: tab.discountType,
                onApply: (value, type) => notifier.setDiscount(value, type),
                leadingLabel: 'Genel İskonto',
              ),
              const SizedBox(width: 24),
              Text('Ara Toplam: ${formatCurrency(tab.subtotal)}'),
              const SizedBox(width: 16),
              Text(
                'Toplam: ${formatCurrency(tab.total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
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
  final VoidCallback onRemove;

  const _MobileCartItem({
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  void _editQuantity(BuildContext context) {
    final ctrl = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adet'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Adet giriniz'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final v = num.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null) onQuantityChanged(v);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
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
                width: 44,
                height: 44,
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
                                    fontFamily: 'monospace'),
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
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

// ── Ortak İskonto Alanı ────────────────────────────────────────────────────

class _DiscountField extends StatefulWidget {
  final num initialValue;
  final DiscountType initialType;
  final void Function(num value, DiscountType type) onApply;
  final String? leadingLabel;

  const _DiscountField({
    super.key,
    required this.initialValue,
    required this.initialType,
    required this.onApply,
    this.leadingLabel,
  });

  @override
  State<_DiscountField> createState() => _DiscountFieldState();
}

class _DiscountFieldState extends State<_DiscountField> {
  late TextEditingController _ctrl;
  late DiscountType _type;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _ctrl = TextEditingController(
      text: widget.initialValue == 0 ? '' : widget.initialValue.toString(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final value = num.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
    widget.onApply(value, _type);
    setState(() => _dirty = false);
  }

  void _selectType(DiscountType t) {
    if (_type == t) return;
    setState(() {
      _type = t;
      _dirty = _ctrl.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leadingLabel != null) ...[
          Text(widget.leadingLabel!,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 8),
        ],
        _TypeChip(
          label: '%',
          selected: _type == DiscountType.percent,
          onTap: () => _selectType(DiscountType.percent),
        ),
        const SizedBox(width: 4),
        _TypeChip(
          label: '₺',
          selected: _type == DiscountType.tl,
          onTap: () => _selectType(DiscountType.tl),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: _type == DiscountType.percent ? '%' : '₺',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) =>
                setState(() => _dirty = v.trim().isNotEmpty),
            onSubmitted: (_) => _apply(),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _dirty
              ? IconButton(
                  key: const ValueKey('check'),
                  icon: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
                  onPressed: _apply,
                  tooltip: 'Uygula',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                )
              : const SizedBox(key: ValueKey('empty'), width: 30),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.goldBg,
          borderRadius: BorderRadius.circular(6),
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
