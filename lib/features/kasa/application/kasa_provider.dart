import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/kasa_entry.dart';
import '../data/models/kasa_expense_category.dart';
import '../data/models/kasa_opening_balance.dart';
import '../data/repositories/kasa_repository.dart';

part 'kasa_provider.g.dart';

/// Kasa repository provider — tekil örüntü, oturum boyunca aynı örnek.
@Riverpod(keepAlive: true)
KasaRepository kasaRepository(KasaRepositoryRef ref) => KasaRepository();

// ── Kasa kalemleri ──────────────────────────────────────────────────────────

/// `kasaEntriesProvider` family parametresi. Değer eşitliği ile aynı sorgu
/// tekrar çekilmez (customerSalesQuery deseni).
class KasaEntriesQuery {
  final int fiscalYear;
  final DateTime? date;

  /// 'gelir' | 'gider' | null (tümü).
  final String? direction;

  const KasaEntriesQuery({
    required this.fiscalYear,
    this.date,
    this.direction,
  });

  @override
  bool operator ==(Object other) =>
      other is KasaEntriesQuery &&
      other.fiscalYear == fiscalYear &&
      other.date == date &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(fiscalYear, date, direction);
}

/// Seçili mali yıl / gün / yön için kasa kalemleri.
@riverpod
Future<List<KasaEntry>> kasaEntries(KasaEntriesRef ref, KasaEntriesQuery q) {
  return ref.watch(kasaRepositoryProvider).fetchEntries(
        fiscalYear: q.fiscalYear,
        date: q.date,
        direction: q.direction,
      );
}

// ── Açılış bakiyesi ─────────────────────────────────────────────────────────

/// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
@riverpod
Future<KasaOpeningBalance?> kasaOpeningBalance(
  KasaOpeningBalanceRef ref,
  int fiscalYear,
) {
  return ref.watch(kasaRepositoryProvider).fetchOpeningBalance(fiscalYear);
}

// ── Gider kategorileri ──────────────────────────────────────────────────────

/// Aktif gider kategorileri.
@riverpod
Future<List<KasaExpenseCategory>> kasaExpenseCategories(
  KasaExpenseCategoriesRef ref,
) {
  return ref.watch(kasaRepositoryProvider).fetchExpenseCategories();
}

// ── Kümülatif hero özeti ────────────────────────────────────────────────────

/// `kasaCumulativeSummaryProvider` family parametresi (mali yıl + kesim tarihi).
class KasaSummaryQuery {
  final int fiscalYear;
  final DateTime uptoDate;

  const KasaSummaryQuery({required this.fiscalYear, required this.uptoDate});

  @override
  bool operator ==(Object other) =>
      other is KasaSummaryQuery &&
      other.fiscalYear == fiscalYear &&
      other.uptoDate == uptoDate;

  @override
  int get hashCode => Object.hash(fiscalYear, uptoDate);
}

/// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
/// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
@riverpod
Future<({num income, num expense, num net})> kasaCumulativeSummary(
  KasaCumulativeSummaryRef ref,
  KasaSummaryQuery q,
) {
  return ref
      .watch(kasaRepositoryProvider)
      .cumulativeSummary(q.fiscalYear, q.uptoDate);
}

// ── Günlük kanal geliri (Nakit / POS kırılımı) ─────────────────────────────

/// `kasaDailyChannelIncomeProvider` family parametresi (mali yıl + gün).
class KasaDailyQuery {
  final int fiscalYear;
  final DateTime date;

  const KasaDailyQuery({required this.fiscalYear, required this.date});

  @override
  bool operator ==(Object other) =>
      other is KasaDailyQuery &&
      other.fiscalYear == fiscalYear &&
      other.date == date;

  @override
  int get hashCode => Object.hash(fiscalYear, date);
}

/// Seçili günün gelir kanalı kırılımı (Nakit / POS).
@riverpod
Future<({num nakit, num pos})> kasaDailyChannelIncome(
  KasaDailyChannelIncomeRef ref,
  KasaDailyQuery q,
) {
  return ref
      .watch(kasaRepositoryProvider)
      .dailyChannelIncome(q.fiscalYear, q.date);
}
