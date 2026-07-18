import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/models/liste_gir/extracted_row.dart';
import '../../../data/services/liste_gir/tr_number_parser.dart';

/// Liste Gir önizleme/düzenleme ızgarası — çıkarılan satırlar burada elle
/// düzeltilir (barkod boşsa doldurulur, hatalı okumalar düzeltilir) ve
/// kaynak belgede hiç olmayan Satış Fiyatı burada girilir.
///
/// Satır sayısı bir tedarikçi listesi için tipik olarak küçük (onlarca) —
/// `products_list_screen.dart`'taki "yalnız dokunulan satır düzenlenir"
/// performans optimizasyonuna burada gerek yok, tüm satırlar zaten her
/// zaman düzenlenebilir.
class ListeGirReviewGrid extends StatefulWidget {
  final List<ExtractedRow> rows;
  final VoidCallback onRowsChanged;

  const ListeGirReviewGrid({super.key, required this.rows, required this.onRowsChanged});

  @override
  State<ListeGirReviewGrid> createState() => _ListeGirReviewGridState();
}

class _RowCtrls {
  final TextEditingController barcode;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController purchasePrice;
  final TextEditingController salePrice;

  _RowCtrls(ExtractedRow row)
      : barcode = TextEditingController(text: row.barcode),
        name = TextEditingController(text: row.name),
        quantity = TextEditingController(text: _fmt(row.quantity)),
        purchasePrice = TextEditingController(text: _fmt(row.purchasePrice)),
        salePrice = TextEditingController(text: _fmt(row.salePrice));

  void dispose() {
    barcode.dispose();
    name.dispose();
    quantity.dispose();
    purchasePrice.dispose();
    salePrice.dispose();
  }
}

String _fmt(num v) {
  if (v == 0) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

class _ListeGirReviewGridState extends State<ListeGirReviewGrid> {
  final Map<int, _RowCtrls> _ctrls = {};
  final TextEditingController _multiplierCtrl = TextEditingController(text: '1');
  double _multiplier = 1;

  _RowCtrls _ctrlsFor(int index) => _ctrls.putIfAbsent(index, () => _RowCtrls(widget.rows[index]));

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _multiplierCtrl.dispose();
    super.dispose();
  }

  // Listede yazan alış fiyatı gerçek alış fiyatından farklı olabilir
  // (iskonto/+KDV) — kullanıcı burada sabit bir çarpan girer, tüm satırların
  // alış fiyatı `rawPurchasePrice * çarpan` olarak yeniden hesaplanır. Ham
  // değer korunduğu için çarpan istenildiği kadar değiştirilebilir.
  void _applyMultiplier() {
    final parsed = parseTrNumber(_multiplierCtrl.text);
    final multiplier = parsed == 0 ? 1.0 : parsed.toDouble();
    setState(() {
      _multiplier = multiplier;
      for (var i = 0; i < widget.rows.length; i++) {
        final row = widget.rows[i];
        row.purchasePrice = row.rawPurchasePrice * multiplier;
        _ctrls[i]?.purchasePrice.text = _fmt(row.purchasePrice);
      }
    });
    widget.onRowsChanged();
  }

  void _removeRow(int index) {
    setState(() {
      widget.rows.removeAt(index);
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _ctrls.clear();
    });
    widget.onRowsChanged();
  }

  void _addEmptyRow() {
    setState(() => widget.rows.add(ExtractedRow()));
    widget.onRowsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMultiplierRow(),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Barkod')),
                  DataColumn(label: Text('Ürün Adı')),
                  DataColumn(label: Text('Adet'), numeric: true),
                  DataColumn(label: Text('Alış Fiyatı'), numeric: true),
                  DataColumn(label: Text('Satış Fiyatı'), numeric: true),
                  DataColumn(label: Text('Durum')),
                  DataColumn(label: Text('')),
                ],
                rows: [for (var i = 0; i < widget.rows.length; i++) _buildRow(context, i)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addEmptyRow,
          icon: const Icon(Icons.add),
          label: const Text('Satır Ekle'),
        ),
      ],
    );
  }

  Widget _buildMultiplierRow() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Text('Alış Fiyatı Çarpanı:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _multiplierCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            onSubmitted: (_) => _applyMultiplier(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _applyMultiplier, child: const Text('Uygula')),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Listede yazan alış fiyatı gerçek alış fiyatından farklıysa (iskonto/+KDV) çarpan girin — ör. %34 iskonto için 0,66, +%20 KDV için 1,2. Aynıysa 1 bırakın.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  DataRow _buildRow(BuildContext context, int index) {
    final row = widget.rows[index];
    final c = _ctrlsFor(index);
    return DataRow(cells: [
      DataCell(SizedBox(
        width: 150,
        child: TextField(
          controller: c.barcode,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.barcode = v.trim(),
        ),
      )),
      DataCell(SizedBox(
        width: 260,
        child: TextField(
          controller: c.name,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.name = v,
        ),
      )),
      DataCell(SizedBox(
        width: 80,
        child: TextField(
          controller: c.quantity,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.quantity = parseTrNumber(v),
        ),
      )),
      DataCell(SizedBox(
        width: 100,
        child: TextField(
          controller: c.purchasePrice,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) {
            final parsed = parseTrNumber(v);
            row.purchasePrice = parsed;
            // Elle girilen değeri de mevcut çarpana göre "ham" değere geri
            // çevirip saklar — çarpan sonradan değişirse bu satır da tutarlı
            // kalsın diye (bkz. ExtractedRow.rawPurchasePrice dokümantasyonu).
            row.rawPurchasePrice = _multiplier == 0 ? parsed : parsed / _multiplier;
          },
        ),
      )),
      DataCell(SizedBox(
        width: 100,
        child: TextField(
          controller: c.salePrice,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.salePrice = parseTrNumber(v),
        ),
      )),
      DataCell(SizedBox(width: 190, child: _StatusBadge(row: row))),
      DataCell(IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
        tooltip: 'Satırı sil',
        onPressed: () => _removeRow(index),
      )),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final ExtractedRow row;
  const _StatusBadge({required this.row});

  @override
  Widget build(BuildContext context) {
    if (row.barcode.isEmpty) {
      return const Text('Barkod yok — yeni ürün', style: TextStyle(fontSize: 11, color: AppColors.textMuted));
    }
    if (row.existingProductId != null) {
      final current = row.existingStock ?? 0;
      return Text(
        'Mevcut — stok ${_fmt(current)} → ${_fmt(current + row.quantity)}',
        style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
      );
    }
    return const Text('Yeni ürün oluşturulacak', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600));
  }
}
