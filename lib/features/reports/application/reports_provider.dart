import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/daily_report_summary.dart';
import '../data/models/product_sale_record.dart';
import '../data/repositories/report_repository.dart';

part 'reports_provider.g.dart';

@Riverpod(keepAlive: true)
ReportRepository reportRepository(ReportRepositoryRef ref) => ReportRepository();

@riverpod
Future<DailyReportSummary> dailyReport(DailyReportRef ref, DateTime date) {
  return ref.watch(reportRepositoryProvider).fetchDailyReport(date);
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
