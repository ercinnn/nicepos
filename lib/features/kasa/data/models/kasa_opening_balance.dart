/// Bir mali yılın kasa açılış bakiyesi. `kasa_opening_balances` tablosunun
/// karşılığı (PK: fiscal_year). Otomatik devir yoktur; her yıl açılışı elle
/// girilir (2027 sıfırdan başlar).
/// ORM yoktur — `fromMap()` + `toInsertMap()` deseni kullanılır.
class KasaOpeningBalance {
  /// Mali yıl (birincil anahtar).
  final int fiscalYear;

  /// Yıl başı devreden gelir (kümülatif gelir hero'sunun başlangıcı).
  final num openingIncome;

  /// Yıl başı devreden gider (kümülatif gider hero'sunun başlangıcı).
  final num openingExpense;

  final String? note;

  const KasaOpeningBalance({
    required this.fiscalYear,
    this.openingIncome = 0,
    this.openingExpense = 0,
    this.note,
  });

  factory KasaOpeningBalance.fromMap(Map<String, dynamic> map) {
    return KasaOpeningBalance(
      fiscalYear: (map['fiscal_year'] as num).toInt(),
      openingIncome: map['opening_income'] as num? ?? 0,
      openingExpense: map['opening_expense'] as num? ?? 0,
      note: map['note'] as String?,
    );
  }

  /// upsert için kullanılır (PK fiscal_year dahil edilir).
  Map<String, dynamic> toInsertMap() {
    return {
      'fiscal_year': fiscalYear,
      'opening_income': openingIncome,
      'opening_expense': openingExpense,
      'note': note,
    };
  }
}
