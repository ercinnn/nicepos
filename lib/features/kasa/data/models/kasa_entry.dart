/// Kasa hareketinin yönü: gelir (kasaya giren) veya gider (kasadan çıkan).
enum KasaDirection { gelir, gider }

extension KasaDirectionX on KasaDirection {
  String get dbValue {
    switch (this) {
      case KasaDirection.gelir:
        return 'gelir';
      case KasaDirection.gider:
        return 'gider';
    }
  }

  String get label {
    switch (this) {
      case KasaDirection.gelir:
        return 'Gelir';
      case KasaDirection.gider:
        return 'Gider';
    }
  }

  static KasaDirection fromDb(String value) =>
      value == 'gider' ? KasaDirection.gider : KasaDirection.gelir;
}

/// Kasa gelir kanalı: nakit veya pos. Gider hareketlerinde null olabilir.
enum KasaChannel { nakit, pos }

extension KasaChannelX on KasaChannel {
  String get dbValue {
    switch (this) {
      case KasaChannel.nakit:
        return 'nakit';
      case KasaChannel.pos:
        return 'pos';
    }
  }

  String get label {
    switch (this) {
      case KasaChannel.nakit:
        return 'Nakit';
      case KasaChannel.pos:
        return 'Pos';
    }
  }

  /// DB değeri null olabildiği için nullable döner.
  static KasaChannel? fromDb(String? value) {
    if (value == null) return null;
    return value == 'pos' ? KasaChannel.pos : KasaChannel.nakit;
  }
}

/// Kasa defteri kalemi. `kasa_entries` tablosunun bire bir karşılığı.
/// ORM yoktur — `fromMap()` + `toInsertMap()` deseni kullanılır.
class KasaEntry {
  final String id;

  /// Hareketin tarihi (date türü, saat bilgisi yok).
  final DateTime entryDate;

  /// Mali yıl — yıl bazlı sorgulama için (ör. 2027). Otomatik devir yok.
  final int fiscalYear;

  /// Yön: gelir / gider.
  final KasaDirection direction;

  /// Gelir kanalı (nakit/pos). Giderde genelde null.
  final KasaChannel? channel;

  /// Gider kategorisi (ör. "Kira", "Elektrik"). Gelirde genelde null.
  final String? category;

  /// İlişkili firma (gider için firma seçimi). Null olabilir.
  final String? companyId;

  /// İlişkili firmanın adı — `companies(name)` join'i ile gelir (kayıtta yok).
  final String? companyName;

  /// Tutar (numeric, TL).
  final num amount;

  /// Serbest not.
  final String? note;

  final DateTime? createdAt;

  const KasaEntry({
    this.id = '',
    required this.entryDate,
    required this.fiscalYear,
    required this.direction,
    this.channel,
    this.category,
    this.companyId,
    this.companyName,
    this.amount = 0,
    this.note,
    this.createdAt,
  });

  factory KasaEntry.fromMap(Map<String, dynamic> map) {
    // Firma adı `companies(name)` join'iyle gelebilir (Map veya List).
    final rawCompany = map['companies'];
    final company = rawCompany is Map
        ? Map<String, dynamic>.from(rawCompany)
        : rawCompany is List && rawCompany.isNotEmpty
            ? Map<String, dynamic>.from(rawCompany.first as Map)
            : null;
    return KasaEntry(
      id: map['id'] as String,
      // entry_date date türü → 'YYYY-MM-DD'; saat olmadığı için toLocal gerekmez.
      entryDate: DateTime.parse(map['entry_date'] as String),
      fiscalYear: (map['fiscal_year'] as num).toInt(),
      direction: KasaDirectionX.fromDb(map['direction'] as String),
      channel: KasaChannelX.fromDb(map['channel'] as String?),
      category: map['category'] as String?,
      companyId: map['company_id'] as String?,
      companyName: company?['name'] as String?,
      amount: map['amount'] as num? ?? 0,
      note: map['note'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      // date türü — yalnız 'YYYY-MM-DD' kısmı gönderilir.
      'entry_date':
          '${entryDate.year.toString().padLeft(4, '0')}-${entryDate.month.toString().padLeft(2, '0')}-${entryDate.day.toString().padLeft(2, '0')}',
      'fiscal_year': fiscalYear,
      'direction': direction.dbValue,
      'channel': channel?.dbValue,
      'category': category,
      'company_id': companyId,
      'amount': amount,
      'note': note,
    };
  }

  KasaEntry copyWith({
    DateTime? entryDate,
    int? fiscalYear,
    KasaDirection? direction,
    KasaChannel? channel,
    String? category,
    String? companyId,
    String? companyName,
    num? amount,
    String? note,
  }) {
    return KasaEntry(
      id: id,
      entryDate: entryDate ?? this.entryDate,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      direction: direction ?? this.direction,
      channel: channel ?? this.channel,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}
