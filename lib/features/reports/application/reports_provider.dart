import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/best_seller_record.dart';
import '../data/models/daily_report_summary.dart';
import '../data/models/product_analysis_record.dart';
import '../data/models/product_sale_record.dart';
import '../data/repositories/report_repository.dart';

part 'reports_provider.g.dart';

@Riverpod(keepAlive: true)
ReportRepository reportRepository(ReportRepositoryRef ref) => ReportRepository();

@riverpod
Future<DailyReportSummary> dailyReport(DailyReportRef ref, DateTime date) {
  return ref.watch(reportRepositoryProvider).fetchDailyReport(date);
}

// ─── En Çok Satanlar (Raporlar 4. sekme) ─────────────────────────────────────
// Tarih aralığı + min. fiyat parametreli; adet azalan sıralı liste.
@riverpod
Future<List<BestSellerRecord>> bestSellers(
  BestSellersRef ref, {
  required DateTime start,
  required DateTime end,
  required num minPrice,
}) {
  return ref
      .watch(reportRepositoryProvider)
      .fetchBestSellers(start: start, end: end, minPrice: minPrice);
}

// ─── Tarihsel rapor için parametre sınıfı ────────────────────────────────────

class DateRangeParam {
  final DateTime start;
  final DateTime end;

  const DateRangeParam(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is DateRangeParam && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

// ─── Manuel provider'lar (kod üretimi gerektirmez) ───────────────────────────

final dateRangeReportProvider =
    FutureProvider.autoDispose.family<DailyReportSummary, DateRangeParam>(
  (ref, param) =>
      ref.watch(reportRepositoryProvider).fetchDateRangeReport(param.start, param.end),
);

final productSalesHistoryProvider =
    FutureProvider.autoDispose.family<List<ProductSaleRecord>, String>(
  (ref, productId) =>
      ref.watch(reportRepositoryProvider).fetchProductSalesHistory(productId),
);

// ─── Ürün Analizi (Raporlar 5. sekme) ────────────────────────────────────────
// Durağan gün eşiği sunucu parametresi DEĞİL — eşik değişince yeniden fetch
// TETİKLENMEZ, yalnız istemci tarafında filtre/sıralama değişir.
final productAnalysisProvider =
    FutureProvider.autoDispose.family<List<ProductAnalysisRecord>, DateRangeParam>(
  (ref, param) => ref
      .watch(reportRepositoryProvider)
      .fetchProductAnalysis(start: param.start, end: param.end),
);
