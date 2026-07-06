import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kasa_entry.dart';
import '../models/kasa_expense_category.dart';
import '../models/kasa_opening_balance.dart';
import '../../../products/data/models/company.dart';

/// Kasa (kasa defteri) veri katmanı repository'si.
///
/// ⚠️ FAZ B SINIRI: Bu repository yalnız `kasa_entries`, `kasa_expense_categories`,
/// `kasa_opening_balances` (+ `companies` autocomplete) üzerinde çalışır. Toplam/
/// hero yardımcıları YALNIZ kasa_entries + opening_balances agregasyonudur.
/// `sales` / `customer_payments` sorgulama, düzeltme satışı üretme ve mutabakat
/// HESABI Faz C'ye aittir — burada YAPILMAZ.
class KasaRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Türkçe büyük harf: önce i→İ, ı→I eşle, sonra toUpperCase().
  // Dart'ın yerleşik toUpperCase'i Türkçe değildir; noktalı/noktasız i'yi yanlış katlar.
  static String _trUpper(String s) =>
      s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  // Türkçe küçük harf: önce I→ı, İ→i eşle, sonra toLowerCase().
  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  // date türü alanlar için 'YYYY-MM-DD' dizesi (saat/timezone yok).
  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Kasa kalemleri ────────────────────────────────────────────────────────

  /// Belirli mali yılın kasa kalemlerini çeker. [date] verilirse yalnız o gün,
  /// [direction] verilirse yalnız o yön (gelir/gider) döner. Firma adı için
  /// `companies(name)` join'i yapılır.
  Future<List<KasaEntry>> fetchEntries({
    required int fiscalYear,
    DateTime? date,
    String? direction,
  }) async {
    var builder = _client
        .from('kasa_entries')
        .select('*, companies(name)')
        .eq('fiscal_year', fiscalYear);
    if (date != null) {
      builder = builder.eq('entry_date', _dateStr(date));
    }
    if (direction != null && direction.isNotEmpty) {
      builder = builder.eq('direction', direction);
    }
    final rows = await builder.order('entry_date', ascending: false);
    return (rows as List)
        .map((r) => KasaEntry.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Yeni kasa kalemi ekler, oluşturulan id'yi döner.
  Future<String> addEntry(KasaEntry entry) async {
    final row = await _client
        .from('kasa_entries')
        .insert(entry.toInsertMap())
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Mevcut kasa kalemini günceller.
  Future<void> updateEntry(String id, KasaEntry entry) async {
    await _client.from('kasa_entries').update(entry.toInsertMap()).eq('id', id);
  }

  /// Kasa kalemini siler.
  Future<void> deleteEntry(String id) async {
    await _client.from('kasa_entries').delete().eq('id', id);
  }

  // ── Gider kategorileri ────────────────────────────────────────────────────

  /// Aktif gider kategorilerini (is_active=true) ada göre sıralı çeker.
  Future<List<KasaExpenseCategory>> fetchExpenseCategories() async {
    final rows = await _client
        .from('kasa_expense_categories')
        .select()
        .eq('is_active', true)
        .order('name');
    return (rows as List)
        .map((r) =>
            KasaExpenseCategory.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Yeni gider kategorisi ekler, oluşturulan id'yi döner.
  Future<String> addExpenseCategory(String name) async {
    final row = await _client
        .from('kasa_expense_categories')
        .insert({'name': name, 'is_active': true})
        .select('id')
        .single();
    return row['id'] as String;
  }

  // ── Açılış bakiyeleri ─────────────────────────────────────────────────────

  /// Mali yılın açılış bakiyesini çeker. Kayıt yoksa null döner.
  Future<KasaOpeningBalance?> fetchOpeningBalance(int fiscalYear) async {
    final row = await _client
        .from('kasa_opening_balances')
        .select()
        .eq('fiscal_year', fiscalYear)
        .maybeSingle();
    if (row == null) return null;
    return KasaOpeningBalance.fromMap(Map<String, dynamic>.from(row));
  }

  /// Mali yılın açılış bakiyesini ekler/günceller (PK: fiscal_year).
  Future<void> upsertOpeningBalance(
    int fiscalYear,
    num income,
    num expense, {
    String? note,
  }) async {
    final model = KasaOpeningBalance(
      fiscalYear: fiscalYear,
      openingIncome: income,
      openingExpense: expense,
      note: note,
    );
    await _client
        .from('kasa_opening_balances')
        .upsert(model.toInsertMap(), onConflict: 'fiscal_year');
  }

  // ── Firma autocomplete ────────────────────────────────────────────────────

  /// Gider firması autocomplete'i için `companies.name` üzerinde Türkçe-duyarlı
  /// ilike araması. İ/i, I/ı katlaması için sorguyu {ham, büyük, küçük}
  /// varyantlarıyla OR'lar (ProductRepository._buildSearchOr deseni).
  Future<List<Company>> searchCompanies(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    // .or() virgülle ayrılır; sorgudaki , ( ) filtre sözdizimini bozar → sadeleştir.
    final safe = q.replaceAll(RegExp(r'[,()]'), ' ').trim();
    final variants = <String>{safe, _trUpper(safe), _trLower(safe)};
    final orFilter = variants.map((v) => 'name.ilike.%$v%').join(',');
    final rows = await _client
        .from('companies')
        .select()
        .or(orFilter)
        .order('name')
        .limit(20);
    return (rows as List)
        .map((r) => Company.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ── Toplam / hero yardımcıları (SADECE kasa_entries + opening_balances) ────
  //
  // Bu bölüm satışa DOKUNMAZ. Mutabakat/satış karşılaştırması Faz C'dedir.

  // PostgREST numeric alanları num veya String gelebilir; güvenle sayıya çevir.
  num _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  /// Verilen yön için [uptoDate] dahil kümülatif kalem toplamı (opening HARİÇ).
  Future<num> _sumEntries(
    int fiscalYear,
    String direction,
    DateTime uptoDate,
  ) async {
    final rows = await _client
        .from('kasa_entries')
        .select('amount')
        .eq('fiscal_year', fiscalYear)
        .eq('direction', direction)
        .lte('entry_date', _dateStr(uptoDate));
    num sum = 0;
    for (final r in (rows as List)) {
      final map = Map<String, dynamic>.from(r as Map);
      sum += _asNum(map['amount']);
    }
    return sum;
  }

  /// Kümülatif gelir = opening_income + Σ(gelir kalemleri, entry_date ≤ uptoDate).
  /// Formül: opening_income + Σ amount (direction='gelir').
  /// Örnek: opening 1000 + güne kadar 3 gelir (500+250.50+100) = 1850.50.
  Future<num> cumulativeIncome(int fiscalYear, DateTime uptoDate) async {
    final opening = await fetchOpeningBalance(fiscalYear);
    final entriesSum = await _sumEntries(fiscalYear, 'gelir', uptoDate);
    return (opening?.openingIncome ?? 0) + entriesSum;
  }

  /// Kümülatif gider = opening_expense + Σ(gider kalemleri, entry_date ≤ uptoDate).
  Future<num> cumulativeExpense(int fiscalYear, DateTime uptoDate) async {
    final opening = await fetchOpeningBalance(fiscalYear);
    final entriesSum = await _sumEntries(fiscalYear, 'gider', uptoDate);
    return (opening?.openingExpense ?? 0) + entriesSum;
  }

  /// Kümülatif gelir + gider + net bakiye (hero için tek çağrıda). opening
  /// bakiyesi bir kez çekilir; net = kümülatif gelir − kümülatif gider.
  Future<({num income, num expense, num net})> cumulativeSummary(
    int fiscalYear,
    DateTime uptoDate,
  ) async {
    final opening = await fetchOpeningBalance(fiscalYear);
    final incomeSum = await _sumEntries(fiscalYear, 'gelir', uptoDate);
    final expenseSum = await _sumEntries(fiscalYear, 'gider', uptoDate);
    final income = (opening?.openingIncome ?? 0) + incomeSum;
    final expense = (opening?.openingExpense ?? 0) + expenseSum;
    return (income: income, expense: expense, net: income - expense);
  }

  /// Seçili günün gelir kanalı kırılımı: Nakit ve POS gelir toplamları.
  /// Yalnız direction='gelir' kalemleri kanala göre gruplanır. Kanalsız (null)
  /// gelir kalemleri hiçbir kanala eklenmez.
  /// Örnek: gün içi nakit 300+200, pos 150 → (nakit: 500, pos: 150).
  Future<({num nakit, num pos})> dailyChannelIncome(
    int fiscalYear,
    DateTime date,
  ) async {
    final rows = await _client
        .from('kasa_entries')
        .select('channel, amount')
        .eq('fiscal_year', fiscalYear)
        .eq('direction', 'gelir')
        .eq('entry_date', _dateStr(date));
    num nakit = 0;
    num pos = 0;
    for (final r in (rows as List)) {
      final map = Map<String, dynamic>.from(r as Map);
      final channel = map['channel'] as String?;
      final amount = _asNum(map['amount']);
      if (channel == 'nakit') {
        nakit += amount;
      } else if (channel == 'pos') {
        pos += amount;
      }
    }
    return (nakit: nakit, pos: pos);
  }
}
