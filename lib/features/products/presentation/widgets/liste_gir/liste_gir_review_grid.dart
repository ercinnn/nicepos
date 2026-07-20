import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../application/products_provider.dart';
import '../../../data/models/liste_gir/extracted_row.dart';
import '../../../data/models/product.dart';
import '../../../data/services/liste_gir/tr_number_parser.dart';

/// Liste Gir önizleme/düzenleme ızgarası — çıkarılan satırlar burada elle
/// düzeltilir (barkod boşsa doldurulur, hatalı okumalar düzeltilir) ve
/// kaynak belgede hiç olmayan Satış Fiyatı burada girilir.
///
/// Satır sayısı bir tedarikçi listesi için tipik olarak küçük (onlarca) —
/// `products_list_screen.dart`'taki "yalnız dokunulan satır düzenlenir"
/// performans optimizasyonuna burada gerek yok, tüm satırlar zaten her
/// zaman düzenlenebilir.
class ListeGirReviewGrid extends ConsumerStatefulWidget {
  final List<ExtractedRow> rows;
  final VoidCallback onRowsChanged;

  const ListeGirReviewGrid({super.key, required this.rows, required this.onRowsChanged});

  @override
  ConsumerState<ListeGirReviewGrid> createState() => _ListeGirReviewGridState();
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

class _ListeGirReviewGridState extends ConsumerState<ListeGirReviewGrid> {
  final Map<int, _RowCtrls> _ctrls = {};
  final TextEditingController _purchaseMultiplierCtrl = TextEditingController(text: '1');
  final TextEditingController _saleMultiplierCtrl = TextEditingController(text: '1');
  double _purchaseMultiplier = 1;
  final Set<int> _sendingIndexes = {};

  _RowCtrls _ctrlsFor(int index) => _ctrls.putIfAbsent(index, () => _RowCtrls(widget.rows[index]));

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _purchaseMultiplierCtrl.dispose();
    _saleMultiplierCtrl.dispose();
    super.dispose();
  }

  // Listede yazan alış fiyatı gerçek alış fiyatından farklı olabilir
  // (iskonto/+KDV) — kullanıcı burada sabit bir çarpan girer, tüm satırların
  // alış fiyatı `rawPurchasePrice * çarpan` olarak yeniden hesaplanır. Ham
  // değer korunduğu için çarpan istenildiği kadar değiştirilebilir.
  void _applyPurchaseMultiplier() {
    final parsed = parseTrNumber(_purchaseMultiplierCtrl.text);
    final multiplier = parsed == 0 ? 1.0 : parsed.toDouble();
    setState(() {
      _purchaseMultiplier = multiplier;
      for (var i = 0; i < widget.rows.length; i++) {
        final row = widget.rows[i];
        row.purchasePrice = row.rawPurchasePrice * multiplier;
        _ctrls[i]?.purchasePrice.text = _fmt(row.purchasePrice);
      }
    });
    widget.onRowsChanged();
  }

  // Barkodu sistemde ZATEN KAYITLI satırlarda Satış Fiyatı ürünün mevcut
  // price1'i (bkz. liste_gir_screen.dart _confirmColumns) — dokunulmaz. Bu
  // çarpan yalnız barkodu YENİ (sistemde eşleşmeyen) satırlar için, o satırın
  // (çarpan uygulanmış) alış fiyatı üzerinden bir satış fiyatı önerisi kurar.
  void _applySaleMultiplier() {
    final parsed = parseTrNumber(_saleMultiplierCtrl.text);
    final multiplier = parsed == 0 ? 1.0 : parsed.toDouble();
    setState(() {
      for (var i = 0; i < widget.rows.length; i++) {
        final row = widget.rows[i];
        if (row.existingProductId != null) continue;
        row.salePrice = row.purchasePrice * multiplier;
        _ctrls[i]?.salePrice.text = _fmt(row.salePrice);
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

  // Tek satırı, `liste_gir_screen.dart`'ın toplu `_save()` mantığının birebir
  // aynısıyla (eşleşme → additive stok/replace fiyat güncelleme; eşleşmezse
  // yeni ürün) tek başına Supabase'e gönderir. Barkod önizleme adımından beri
  // elle değişmiş olabileceği için, `_save()` ile AYNI tazelik kuralına uyarak
  // göndermeden hemen önce `fetchByBarcodes` ile tekrar sorgulanır — satırın
  // olası bayat `existingProductId`/`existingStock` alanlarına güvenilmez.
  Future<void> _sendRow(int index) async {
    if (_sendingIndexes.contains(index)) return;
    final row = widget.rows[index];
    setState(() => _sendingIndexes.add(index));
    try {
      final repo = ref.read(productRepositoryProvider);
      final barcode = row.barcode;
      final existingByBarcode = barcode.isEmpty ? <String, Product>{} : await repo.fetchByBarcodes([barcode]);
      final existing = barcode.isEmpty ? null : existingByBarcode[barcode];
      if (existing != null) {
        final merged = existing.copyWith(
          stockQuantity: existing.stockQuantity + row.quantity,
          purchasePrice: row.purchasePrice,
          price1: row.salePrice,
        );
        await repo.update(existing.id, merged);
      } else {
        await repo.create(Product(
          barcode: row.barcode.isEmpty ? null : row.barcode,
          name: row.name.isEmpty ? '(İsimsiz Ürün)' : row.name,
          stockQuantity: row.quantity,
          purchasePrice: row.purchasePrice,
          price1: row.salePrice,
        ));
      }
      if (!mounted) return;
      // Gönderim sırasında başka satırlar silinmiş/eklenmiş olabilir — bu
      // satırın GÜNCEL index'ini nesne kimliğiyle tekrar bul (yalnız stale
      // `index`'e güvenme).
      final currentIndex = widget.rows.indexOf(row);
      if (currentIndex != -1) {
        _removeRow(currentIndex);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün sisteme yüklendi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingIndexes.remove(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMultiplierRow(
          label: 'Alış Fiyatı Çarpanı:',
          controller: _purchaseMultiplierCtrl,
          onApply: _applyPurchaseMultiplier,
          helperText: 'Listede yazan alış fiyatı gerçek alış fiyatından farklıysa (iskonto/+KDV) '
              'çarpan girin — ör. %34 iskonto için 0,66, +%20 KDV için 1,2. Aynıysa 1 bırakın.',
        ),
        const SizedBox(height: 8),
        _buildMultiplierRow(
          label: 'Satış Fiyatı Çarpanı (yalnız yeni ürünler):',
          controller: _saleMultiplierCtrl,
          onApply: _applySaleMultiplier,
          helperText: 'Barkodu sistemde zaten kayıtlı ürünlerde mevcut satış fiyatı korunur. '
              'Barkodu YENİ olan ürünlerde satış fiyatı, alış fiyatı × bu çarpan olarak hesaplanır.',
        ),
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

  Widget _buildMultiplierRow({
    required String label,
    required TextEditingController controller,
    required VoidCallback onApply,
    required String helperText,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            onSubmitted: (_) => onApply(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onApply, child: const Text('Uygula')),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            helperText,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  // Önizleme ızgarasındaki düzenlenebilir hanelerin metin boyutu — varsayılan
  // TextField boyutundan 2 punto küçük (yoğunlaştırılmış tablo, dense=true ile
  // uyumlu; bkz. products_list_screen.dart'ın aynı "1 kademe küçük" kararı).
  static const _cellFontSize = 12.0;
  static const _cellTextStyle = TextStyle(fontSize: _cellFontSize);

  DataRow _buildRow(BuildContext context, int index) {
    final row = widget.rows[index];
    final c = _ctrlsFor(index);
    return DataRow(cells: [
      DataCell(SizedBox(
        width: 150,
        child: TextField(
          controller: c.barcode,
          style: _cellTextStyle,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.barcode = v.trim(),
        ),
      )),
      DataCell(SizedBox(
        width: 390,
        child: TextField(
          controller: c.name,
          style: _cellTextStyle,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => row.name = v,
        ),
      )),
      DataCell(SizedBox(
        width: 80,
        child: TextField(
          controller: c.quantity,
          style: _cellTextStyle,
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
          style: _cellTextStyle,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: (v) {
            final parsed = parseTrNumber(v);
            row.purchasePrice = parsed;
            // Elle girilen değeri de mevcut çarpana göre "ham" değere geri
            // çevirip saklar — çarpan sonradan değişirse bu satır da tutarlı
            // kalsın diye (bkz. ExtractedRow.rawPurchasePrice dokümantasyonu).
            row.rawPurchasePrice = _purchaseMultiplier == 0 ? parsed : parsed / _purchaseMultiplier;
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
          // Barkodu YENİ (sistemde eşleşmeyen) ürünlerde satış fiyatı tahmini/
          // girilmesi gereken bir değerdir → kırmızı, dikkat çeksin. Barkodu
          // zaten kayıtlı ürünlerde mevcut fiyat gösterildiği için otomatik
          // (siyah) renk yeterli.
          style: _cellTextStyle.copyWith(color: row.existingProductId == null ? AppColors.danger : null),
          onChanged: (v) => row.salePrice = parseTrNumber(v),
        ),
      )),
      DataCell(SizedBox(width: 190, child: _StatusBadge(row: row))),
      DataCell(_buildRowActions(index)),
    ]);
  }

  Widget _buildRowActions(int index) {
    final sending = _sendingIndexes.contains(index);
    if (sending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.success, size: 20),
        tooltip: 'Tekil gönder',
        onPressed: () => _sendRow(index),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
        tooltip: 'Satırı sil',
        onPressed: () => _removeRow(index),
      ),
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
