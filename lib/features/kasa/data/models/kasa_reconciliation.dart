import 'kasa_entry.dart' show KasaChannel, KasaChannelX;

/// Kasa mutabakat kaydı. `kasa_reconciliations` tablosunun karşılığı.
///
/// ⚠️ Faz B sınırı: bu model yalnız veri taşıma (read/write) için tanımlıdır.
/// Mutabakat HESABI (satışla karşılaştırma, düzeltme tutarı üretimi) Faz C'ye
/// aittir ve burada YAPILMAZ. `expected_amount`, `system_base` ve
/// `adjustment_amount` alanları Faz C tarafından doldurulur.
/// ORM yoktur — `fromMap()` + `toInsertMap()` deseni kullanılır.
class KasaReconciliation {
  final String id;

  /// Mali yıl.
  final int fiscalYear;

  /// Mutabakat günü (date türü).
  final DateTime entryDate;

  /// Kanal: nakit / pos. (fiscal_year, entry_date, channel) benzersizdir.
  final KasaChannel channel;

  /// İlişkili düzeltme satışının id'si (Faz C üretir). Null olabilir.
  final String? saleId;

  /// Beklenen (kullanıcının beyan ettiği) tutar — Faz C doldurur.
  final num expectedAmount;

  /// Sistemin hesapladığı baz tutar — Faz C doldurur.
  final num systemBase;

  /// Düzeltme tutarı (beklenen − sistem) — Faz C doldurur.
  final num adjustmentAmount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KasaReconciliation({
    this.id = '',
    required this.fiscalYear,
    required this.entryDate,
    required this.channel,
    this.saleId,
    this.expectedAmount = 0,
    this.systemBase = 0,
    this.adjustmentAmount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory KasaReconciliation.fromMap(Map<String, dynamic> map) {
    return KasaReconciliation(
      id: map['id'] as String,
      fiscalYear: (map['fiscal_year'] as num).toInt(),
      entryDate: DateTime.parse(map['entry_date'] as String),
      // Mutabakatta kanal her zaman dolu (NOT NULL); güvenlik için nakit'e düşer.
      channel: KasaChannelX.fromDb(map['channel'] as String?) ?? KasaChannel.nakit,
      saleId: map['sale_id'] as String?,
      expectedAmount: map['expected_amount'] as num? ?? 0,
      systemBase: map['system_base'] as num? ?? 0,
      adjustmentAmount: map['adjustment_amount'] as num? ?? 0,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'fiscal_year': fiscalYear,
      'entry_date':
          '${entryDate.year.toString().padLeft(4, '0')}-${entryDate.month.toString().padLeft(2, '0')}-${entryDate.day.toString().padLeft(2, '0')}',
      'channel': channel.dbValue,
      'sale_id': saleId,
      'expected_amount': expectedAmount,
      'system_base': systemBase,
      'adjustment_amount': adjustmentAmount,
    };
  }
}
