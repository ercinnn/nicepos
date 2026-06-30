import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Eski POS (BenimPOS) "Satış Raporu" Excel'inden okunan tek bir satış satırı.
///
/// Eski rapor **satış (başlık) seviyesindedir** — ürün kırılımı içermez.
/// Bu yüzden her satır yeni şemada yalnızca bir `sales` kaydına eşlenir;
/// `sale_items` (ürün kalemi) **yazılmaz**.
///
/// Ödeme yalnızca **nakit** veya **pos** olarak saklanır (açık hesap/parçalı
/// satışlar nakit tahsilat kabul edilir). İade satırları kaynakta negatif
/// tutarlıdır; işaret korunur (eksi yazılır).
///
/// Kaynak kolonlar (başlıksız indeks):
///   0 A: Hesap/Şube (ör. "Ana Hesap")
///   1 B: Satış Kodu (ör. "2601010003-QR") — benzersiz, mükerrer kontrolü için
///   2 C: Müşteri (çoğunlukla boş)
///   3 D: Miktar (toplam ürün adedi; iadelerde negatif)
///   4 E: Tutar (net/iskontolu toplam; iadelerde negatif)
///   5 F: İskonto (ör. "%0", "%9.09")
///   6 G: Ödeme Tipi (Nakit / Pos / Açık Hesap / Parçalı)
///   7 H: Tarih (ör. "01/01/2026 - 13:12:24")
///   8 I: İşlem Yapan (personel)
///   9 J: Uygulama (Site / AndroidApp)
///  10 K: Not / açıklama (ör. "(... iade alma)")
class ImportedSaleRow {
  final String saleCode;
  final String branch;
  final String? customerName;
  final num totalAmount;
  final num discountPercent;
  final num discountAmount;
  final String paymentTypeDb; // yalnızca 'nakit' | 'pos'
  final num cashAmount;
  final num cardAmount;
  final num paidAmount;
  final bool isReturn; // iade satırı (negatif tutar)
  final String? personnel;
  final String? note;
  final DateTime saleDate;

  const ImportedSaleRow({
    required this.saleCode,
    required this.branch,
    this.customerName,
    required this.totalAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.paymentTypeDb,
    required this.cashAmount,
    required this.cardAmount,
    required this.paidAmount,
    required this.isReturn,
    this.personnel,
    this.note,
    required this.saleDate,
  });
}

/// Excel parse sonucu: geçerli satırlar + atlanan satır sayısı + uyarılar.
class ImportParseResult {
  final List<ImportedSaleRow> rows;
  final int skippedCount; // başlık/geçersiz/tarihi okunamayan satırlar
  final List<String> warnings;

  const ImportParseResult({
    required this.rows,
    required this.skippedCount,
    required this.warnings,
  });
}

/// Eski satış xlsx'ini parse eder.
///
/// NOT: `excel` paketi (4.0.6) bu dosyayı `numFmtId 56` stil hatasıyla açamıyor
/// (SheetJS üretimi). Bu yüzden xlsx'i **doğrudan** açıyoruz: zip aç → sayfa
/// XML'ini `package:xml` ile oku. Hücreler `<c r="E2"><v>...</v></c>` ya da
/// satır içi string `<c t="inlineStr"><is><t>...</t></is></c>` biçimindedir;
/// paylaşılan string tablosu (sharedStrings) kullanılmaz.
class OldSalesExcelParser {
  // Kolon indeksleri
  static const int _cBranch = 0;
  static const int _cSaleCode = 1;
  static const int _cCustomer = 2;
  static const int _cAmount = 4;
  static const int _cDiscount = 5;
  static const int _cPaymentType = 6;
  static const int _cDate = 7;
  static const int _cPersonnel = 8;
  static const int _cApp = 9;
  static const int _cNote = 10;

  static ImportParseResult parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // İlk çalışma sayfasını bul (xl/worksheets/sheetN.xml).
    ArchiveFile? sheetFile;
    for (final f in archive.files) {
      if (f.isFile &&
          f.name.startsWith('xl/worksheets/sheet') &&
          f.name.endsWith('.xml')) {
        sheetFile = f;
        break;
      }
    }
    if (sheetFile == null) {
      return const ImportParseResult(
        rows: [],
        skippedCount: 0,
        warnings: ['Çalışma sayfası bulunamadı (geçersiz xlsx).'],
      );
    }

    final xmlStr = utf8.decode(sheetFile.content as List<int>);
    final doc = XmlDocument.parse(xmlStr);

    final rows = <ImportedSaleRow>[];
    final warnings = <String>[];
    int skipped = 0;

    for (final rowEl in doc.findAllElements('row')) {
      final cells = <int, String>{};
      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r');
        if (ref == null) continue;
        final col = _colIndex(ref);
        if (col < 0) continue;
        final text = _cellText(c);
        if (text != null) cells[col] = text;
      }
      if (cells.isEmpty) continue;

      final dateRaw = cells[_cDate];
      final date = _parseDate(dateRaw);

      // Tarih okunamıyorsa: başlık satırı veya boş satır → sessizce atla.
      if (date == null) {
        skipped++;
        continue;
      }

      final saleCode = cells[_cSaleCode]?.trim();
      if (saleCode == null || saleCode.isEmpty) {
        skipped++;
        if (warnings.length < 30) {
          warnings.add('Satış kodu boş satır atlandı ($dateRaw).');
        }
        continue;
      }

      final total = _num(cells[_cAmount]) ?? 0;
      final discountPercent = _parsePercent(cells[_cDiscount]);
      final isReturn = total < 0;

      // İskontonun kesin TL tutarı (0008 migration'ı ile aynı mantık):
      // Tutar net (iskontolu) kabul edilir → brüt = net / (1 - p/100).
      num discountAmount = 0;
      if (discountPercent > 0 && discountPercent < 100) {
        final gross = total / (1 - discountPercent / 100.0);
        discountAmount = double.parse((gross - total).toStringAsFixed(2));
      }

      // Ödeme: yalnızca nakit veya pos.
      //  pos/kart/kredi → tamamı kart tahsilat
      //  diğer (nakit, açık hesap, parçalı) → tamamı nakit tahsilat
      // İadelerde tutar negatif olduğundan nakit/kart da negatif olur.
      final isPos = _isPos(cells[_cPaymentType]);
      final num cash = isPos ? 0 : total;
      final num card = isPos ? total : 0;
      final paymentDb = isPos ? 'pos' : 'nakit';

      // Not: [İçe aktarıldı] + (iade ise) [İade] + uygulama + eski not.
      final app = cells[_cApp]?.trim();
      final noteRaw = cells[_cNote]?.trim();
      final noteParts = <String>['[İçe aktarıldı]'];
      if (isReturn) noteParts.add('[İADE]');
      if (app != null && app.isNotEmpty) noteParts.add(app);
      if (noteRaw != null && noteRaw.isNotEmpty) noteParts.add(noteRaw);
      final note = noteParts.join(' · ');

      final customer = cells[_cCustomer]?.trim();

      rows.add(ImportedSaleRow(
        saleCode: saleCode,
        branch: cells[_cBranch]?.trim().isNotEmpty == true
            ? cells[_cBranch]!.trim()
            : 'Ana Hesap',
        customerName:
            (customer != null && customer.isNotEmpty) ? customer : null,
        totalAmount: total,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        paymentTypeDb: paymentDb,
        cashAmount: cash,
        cardAmount: card,
        paidAmount: total,
        isReturn: isReturn,
        personnel: cells[_cPersonnel]?.trim(),
        note: note,
        saleDate: date,
      ));
    }

    return ImportParseResult(
      rows: rows,
      skippedCount: skipped,
      warnings: warnings,
    );
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────────

  /// Hücre değerini okur: satır içi string (`<is><t>`) varsa onu, yoksa `<v>`.
  static String? _cellText(XmlElement c) {
    final isEl = c.getElement('is');
    if (isEl != null) {
      final text = isEl.findAllElements('t').map((e) => e.innerText).join();
      return text.isEmpty ? null : text;
    }
    final v = c.getElement('v');
    final text = v?.innerText;
    if (text == null) return null;
    return text.isEmpty ? null : text;
  }

  /// Hücre referansından ("E223") 0-tabanlı kolon indeksini çıkarır.
  static int _colIndex(String ref) {
    var result = 0;
    var seen = false;
    for (final code in ref.codeUnits) {
      if (code >= 65 && code <= 90) {
        result = result * 26 + (code - 64);
        seen = true;
      } else if (code >= 97 && code <= 122) {
        result = result * 26 + (code - 96);
        seen = true;
      } else {
        break; // rakama gelindi
      }
    }
    return seen ? result - 1 : -1;
  }

  static num? _num(String? raw) {
    if (raw == null) return null;
    return num.tryParse(raw.trim().replaceAll(',', '.'));
  }

  /// "%9.09" / "%0" / "9,09" → 9.09 (yüzde). Bulunamazsa 0.
  static num _parsePercent(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll('%', '').replaceAll(',', '.').trim();
    return num.tryParse(cleaned) ?? 0;
  }

  /// Ödeme tipi POS/kart mı? (değilse nakit kabul edilir)
  static bool _isPos(String? raw) {
    final v = (raw ?? '').toLowerCase();
    return v.contains('pos') || v.contains('kart') || v.contains('kredi');
  }

  /// "01/01/2026 - 13:12:24" → yerel DateTime. Saat yoksa gün başı kabul edilir.
  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    String datePart = s;
    String? timePart;
    if (s.contains(' - ')) {
      final parts = s.split(' - ');
      datePart = parts[0].trim();
      if (parts.length > 1) timePart = parts[1].trim();
    } else if (s.contains(' ')) {
      final idx = s.indexOf(' ');
      datePart = s.substring(0, idx).trim();
      timePart = s.substring(idx + 1).trim();
    }

    final dParts = datePart.split(RegExp(r'[\/.\-]'));
    if (dParts.length != 3) return null;
    final day = int.tryParse(dParts[0]);
    final month = int.tryParse(dParts[1]);
    final year = int.tryParse(dParts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;

    int h = 0, mi = 0, sec = 0;
    if (timePart != null && timePart.isNotEmpty) {
      final tParts = timePart.split(':');
      if (tParts.isNotEmpty) h = int.tryParse(tParts[0]) ?? 0;
      if (tParts.length > 1) mi = int.tryParse(tParts[1]) ?? 0;
      if (tParts.length > 2) sec = int.tryParse(tParts[2]) ?? 0;
    }

    return DateTime(year, month, day, h, mi, sec);
  }
}
