import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kasa_entry.dart' show KasaChannel, KasaChannelX;

/// `reconcile()` sonucu: sistemin hesapladığı taban, düzeltme tutarı ve
/// (varsa) oluşturulan/güncellenen düzeltme satışının id'si.
typedef KasaReconcileResult = ({num systemBase, num adjustmentAmount, String? saleId});

/// Kasa mutabakat motoru (Faz C).
///
/// Kanal başına (nakit / pos AYRI) günlük mutabakatı yürütür:
///  1. `system_base` = o günün satış geliri(kanal) + o gün yapılan açık hesap
///     borç tahsilatları(kanal). `is_adjustment=true` satışlar tabana DAHİL
///     EDİLMEZ (kendini besleyip döngü olmaması için).
///  2. `adjustment_amount` = kullanıcının beyan ettiği tutar (expected) −
///     system_base. Fark > 0 ise +düzeltme satışı (ek gelir), < 0 ise
///     −düzeltme (iade), = 0 ise düzeltme satışı oluşturulmaz (varsa silinir).
///  3. `kasa_reconciliations` (UNIQUE tenant_id+fiscal_year+entry_date+channel,
///     bkz. 0038_tenant_unique_constraints.sql) idempotent upsert'lenir; aynı
///     gün+kanal yeniden kaydedilince yeni hayalet üretilmez, mevcut düzeltme
///     satışı yeni farkla GÜNCELLENİR.
///
/// Düzeltme satışı KALEMSİZ + STOKSUZ oluşturulur: `sale_items` insert edilmez,
/// stok RPC'leri (`decrement`/`increment`) ÇAĞRILMAZ, müşteri borç hareketi
/// eklenmez.
///
/// ⚠️ ŞEMA BAĞIMLILIĞI (Faz A migration): `sales` tablosunda `is_adjustment`
/// (boolean) ve `adjustment_channel` (text) kolonları ile `kasa_reconciliations`
/// tablosu (UNIQUE tenant_id, fiscal_year, entry_date, channel + expected_amount,
/// system_base, adjustment_amount, sale_id, updated_at) bu servisin çalışması
/// için DB'de mevcut olmalıdır.
class KasaReconciliationService {
  final SupabaseClient _client = Supabase.instance.client;

  // PostgREST sayfa boyutu (1000 satır limitini aşmak için sayfalı çekim).
  static const int _pageSize = 1000;

  // date türü alanlar için 'YYYY-MM-DD' dizesi (saat/timezone yok).
  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // PostgREST numeric alanları num veya String gelebilir; güvenle sayıya çevir.
  static num _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  // Günün UTC sınırları. report_repository deseni: yerel gece yarısı → UTC ISO.
  // Makine Türkiye saatinde (UTC+3) çalıştığı için yerel gün ile sales.sale_date
  // / customer_payments.payment_date gün sınırı tutarlıdır (dashboard'un
  // AT TIME ZONE 'Europe/Istanbul' davranışıyla aynı günü verir).
  static ({String start, String end}) _dayBoundsUtc(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (
      start: start.toUtc().toIso8601String(),
      end: end.toUtc().toIso8601String(),
    );
  }

  /// Verilen [channel] için o günün sistem tabanını hesaplar.
  ///
  /// Nakit taban = Σ(satış cash_amount) + Σ(nakit borç tahsilatları).
  /// POS taban   = Σ(satış card_amount) + Σ(POS borç tahsilatları).
  ///
  /// BORÇ TAHSİLATI KANALI: `customer_payments.channel` ('nakit'|'pos', 0012
  /// migration) tahsilatın hangi kanaldan alındığını tutar. Müşteri açık hesap
  /// borcunu HEM nakit HEM POS ile ödeyebildiği için tahsilat doğru tabana
  /// eklenir:
  ///   • Nakit tabanı: channel='nakit' VEYA channel IS NULL (eski kayıtlar
  ///     geriye dönük NAKİT sayılır).
  ///   • POS tabanı:   channel='pos'.
  Future<num> computeSystemBase(
    int fiscalYear,
    DateTime date,
    KasaChannel channel,
  ) async {
    final bounds = _dayBoundsUtc(date);

    // 1. O günün satış geliri (kanal bazlı). is_adjustment=true HARİÇ.
    //    .not('is_adjustment', 'is', true) → is_adjustment false VEYA null olan
    //    satırlar (mevcut/normal satışlar dahil, düzeltme satışları hariç).
    num salesChannelSum = 0;
    var salesFrom = 0;
    while (true) {
      final page = await _client
          .from('sales')
          .select('cash_amount, card_amount')
          .gte('sale_date', bounds.start)
          .lt('sale_date', bounds.end)
          .not('is_adjustment', 'is', true)
          .range(salesFrom, salesFrom + _pageSize - 1);
      final list = page as List;
      for (final r in list) {
        final map = Map<String, dynamic>.from(r as Map);
        salesChannelSum += channel == KasaChannel.nakit
            ? _asNum(map['cash_amount'])
            : _asNum(map['card_amount']);
      }
      if (list.length < _pageSize) break;
      salesFrom += _pageSize;
    }

    // 2. O gün yapılan açık hesap borç tahsilatları (type='odeme').
    //    channel'a göre doğru tabana eklenir (0012 migration):
    //      • Nakit tabanı → channel='nakit' VEYA channel IS NULL (eski kayıt).
    //      • POS tabanı   → channel='pos'.
    num debtCollectionSum = 0;
    var payFrom = 0;
    while (true) {
      var q = _client
          .from('customer_payments')
          .select('amount')
          .eq('type', 'odeme')
          .gte('payment_date', bounds.start)
          .lt('payment_date', bounds.end);
      if (channel == KasaChannel.nakit) {
        // Nakit: kanalı 'nakit' olan VEYA hiç kanal atanmamış (eski) tahsilatlar.
        q = q.or('channel.eq.nakit,channel.is.null');
      } else {
        // POS: yalnız kanalı 'pos' olan tahsilatlar.
        q = q.eq('channel', 'pos');
      }
      final page = await q.range(payFrom, payFrom + _pageSize - 1);
      final list = page as List;
      for (final r in list) {
        final map = Map<String, dynamic>.from(r as Map);
        debtCollectionSum += _asNum(map['amount']);
      }
      if (list.length < _pageSize) break;
      payFrom += _pageSize;
    }

    return salesChannelSum + debtCollectionSum;
  }

  /// Bir gün + kanal için mutabakatı yürütür.
  ///
  /// [expectedAmount] kullanıcının kasaya beyan ettiği (beklenen) tutardır.
  /// Sistem tabanını hesaplar, farka göre düzeltme satışını oluşturur/günceller/
  /// siler ve `kasa_reconciliations` kaydını idempotent upsert'ler.
  Future<KasaReconcileResult> reconcile({
    required int fiscalYear,
    required DateTime date,
    required KasaChannel channel,
    required num expectedAmount,
  }) async {
    final systemBase = await computeSystemBase(fiscalYear, date, channel);
    // num aritmetiği — kuruş kaybı yok. Fark pozitif=ek gelir, negatif=iade.
    final num adjustment = expectedAmount - systemBase;

    // Mevcut mutabakat kaydını (idempotentlik için) oku.
    final existing = await _client
        .from('kasa_reconciliations')
        .select('sale_id')
        .eq('fiscal_year', fiscalYear)
        .eq('entry_date', _dateStr(date))
        .eq('channel', channel.dbValue)
        .maybeSingle();
    final existingSaleId = existing?['sale_id'] as String?;

    String? saleId = existingSaleId;

    if (adjustment == 0) {
      // Düzeltme gerekmez → varsa mevcut düzeltme satışını sil, sale_id=null.
      if (existingSaleId != null) {
        await _deleteAdjustmentSale(existingSaleId);
        saleId = null;
      }
    } else if (existingSaleId != null) {
      // Mevcut düzeltme satışını yeni farkla GÜNCELLE (yeni hayalet üretme).
      saleId = await _updateAdjustmentSale(
        saleId: existingSaleId,
        channel: channel,
        amount: adjustment,
        date: date,
      );
    } else {
      // İlk kez: yeni düzeltme satışı oluştur.
      saleId = await _insertAdjustmentSale(
        channel: channel,
        amount: adjustment,
        date: date,
      );
    }

    // kasa_reconciliations idempotent upsert (onConflict = benzersiz üçlü).
    await _client.from('kasa_reconciliations').upsert(
      {
        'fiscal_year': fiscalYear,
        'entry_date': _dateStr(date),
        'channel': channel.dbValue,
        'sale_id': saleId,
        'expected_amount': expectedAmount,
        'system_base': systemBase,
        'adjustment_amount': adjustment,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'tenant_id,fiscal_year,entry_date,channel',
    );

    return (systemBase: systemBase, adjustmentAmount: adjustment, saleId: saleId);
  }

  // ── Düzeltme satışı yardımcıları (kalemsiz + stoksuz) ──────────────────────

  // Düzeltme satışının sale_date'i: mutabakat günü + şu anki saat. Yerel günün
  // içinde kalır (report/dashboard gün sınırıyla tutarlı), UTC olarak yazılır.
  String _adjustmentSaleDate(DateTime date) {
    final now = DateTime.now();
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
    );
    return dt.toUtc().toIso8601String();
  }

  // Düzeltme satışının kanal-bazlı ödeme alanları.
  Map<String, dynamic> _channelPaymentFields(KasaChannel channel, num amount) {
    final isNakit = channel == KasaChannel.nakit;
    return {
      'payment_type': isNakit ? 'nakit' : 'pos',
      'cash_amount': isNakit ? amount : 0,
      'card_amount': isNakit ? 0 : amount,
      'adjustment_channel': channel.dbValue,
    };
  }

  Future<String> _insertAdjustmentSale({
    required KasaChannel channel,
    required num amount,
    required DateTime date,
  }) async {
    final saleCode = await _client.rpc('generate_sale_code') as String;
    final row = await _client
        .from('sales')
        .insert({
          'sale_code': saleCode,
          'customer_id': null,
          'total_amount': amount, // +fark: ek gelir, −fark: iade
          'discount_percent': 0,
          'discount_amount': 0,
          'discount_type': 'percent',
          'paid_amount': amount,
          'remaining_debt': 0,
          'personnel': 'Kasa Mutabakat',
          'note': '[KASA DÜZELTME]',
          'is_adjustment': true,
          ..._channelPaymentFields(channel, amount),
          'sale_date': _adjustmentSaleDate(date),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> _updateAdjustmentSale({
    required String saleId,
    required KasaChannel channel,
    required num amount,
    required DateTime date,
  }) async {
    // Yalnız is_adjustment=true satırı güncelle (normal satışa asla dokunma).
    final updated = await _client
        .from('sales')
        .update({
          'total_amount': amount,
          'paid_amount': amount,
          'remaining_debt': 0,
          ..._channelPaymentFields(channel, amount),
          'sale_date': _adjustmentSaleDate(date),
        })
        .eq('id', saleId)
        .eq('is_adjustment', true)
        .select('id');
    // Kayıt dışarıdan silinmişse (hayalet sale_id) yeniden oluştur → idempotent.
    if ((updated as List).isEmpty) {
      return _insertAdjustmentSale(channel: channel, amount: amount, date: date);
    }
    return saleId;
  }

  Future<void> _deleteAdjustmentSale(String saleId) async {
    // Düzeltme satışı kalemsiz + stoksuz: stok iadesi / borç hareketi YOK.
    // Güvenlik: yalnız is_adjustment=true satırı silinir.
    await _client
        .from('sales')
        .delete()
        .eq('id', saleId)
        .eq('is_adjustment', true);
  }
}
