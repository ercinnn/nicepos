import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/dashboard_provider.dart';

// ── Para formatlayıcı ──────────────────────────────────────────────────────
final _currencyFmt = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);

// ═══════════════════════════════════════════════════════════════════════════
// Ana Dashboard Bölümü
// ═══════════════════════════════════════════════════════════════════════════

/// Anasayfaya eklenen dashboard bölümü.
/// Stat kartları (üstte) + günlük/aylık grafikler (altta) içerir.
class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // ── 4 Stat Kartı ────────────────────────────────────────────────
        _StatCardsRow(),
        const SizedBox(height: 16),

        // ── Grafikler ───────────────────────────────────────────────────
        if (context.isMobile)
          Column(
            children: const [
              _DailyChartCard(),
              SizedBox(height: 16),
              _MonthlyChartCard(),
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Expanded(child: _DailyChartCard()),
                SizedBox(width: 16),
                Expanded(child: _MonthlyChartCard()),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4 Stat Kartı Satırı
// ═══════════════════════════════════════════════════════════════════════════

class _StatCardsRow extends ConsumerWidget {
  const _StatCardsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaySummaryProvider);
    final yesterdayAsync = ref.watch(yesterdaySummaryProvider);
    final monthAsync = ref.watch(monthSummaryProvider);
    final lastMonthAsync = ref.watch(lastMonthRevenueProvider);

    // Kart verilerini oluştur
    final cards = [
      _StatCardData(
        baslik: 'Toplam Satış',
        donem: 'Bugün',
        ikonRengi: AppColors.success,
        ikon: Icons.shopping_bag_outlined,
        asyncDeger: todayAsync.when(
          data: (d) => '${d.count} adet',
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisimAsync: _hesaplaDegisim(
          todayAsync.valueOrNull?.count.toDouble(),
          yesterdayAsync.valueOrNull?.count.toDouble(),
        ),
      ),
      _StatCardData(
        baslik: 'Net Kazanç',
        donem: 'Bugün',
        ikonRengi: AppColors.info,
        ikon: Icons.account_balance_wallet_outlined,
        asyncDeger: todayAsync.when(
          data: (d) => _currencyFmt.format(d.revenue),
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisimAsync: _hesaplaDegisim(
          todayAsync.valueOrNull?.revenue.toDouble(),
          yesterdayAsync.valueOrNull?.revenue.toDouble(),
        ),
      ),
      _StatCardData(
        baslik: 'Toplam Satış',
        donem: 'Bu Ay',
        ikonRengi: const Color(0xFF9C27B0),
        ikon: Icons.shopping_bag_outlined,
        asyncDeger: monthAsync.when(
          data: (d) => '${d.count} adet',
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisimAsync: null, // aylık adet için geçen ay adet verisi yok
      ),
      _StatCardData(
        baslik: 'Net Kazanç',
        donem: 'Bu Ay',
        ikonRengi: AppColors.warning,
        ikon: Icons.account_balance_wallet_outlined,
        asyncDeger: monthAsync.when(
          data: (d) => _currencyFmt.format(d.revenue),
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisimAsync: _hesaplaDegisim(
          monthAsync.valueOrNull?.revenue.toDouble(),
          lastMonthAsync.valueOrNull?.toDouble(),
        ),
      ),
    ];

    if (context.isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards.map((c) => _StatCard(data: c)).toList(),
      );
    }

    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StatCard(data: c),
              ),
            ),
          )
          .toList(),
    );
  }

  /// İki değer arasındaki yüzde değişimini hesapla.
  double? _hesaplaDegisim(double? yeni, double? eski) {
    if (yeni == null || eski == null) return null;
    if (eski == 0) return yeni > 0 ? 100.0 : null;
    return ((yeni - eski) / eski) * 100;
  }
}

// ── Stat Kart Verisi ───────────────────────────────────────────────────────

class _StatCardData {
  final String baslik;
  final String donem;
  final Color ikonRengi;
  final IconData ikon;
  final String? asyncDeger; // null → yükleniyor
  final double? degisimAsync; // null → hesaplanamadı

  const _StatCardData({
    required this.baslik,
    required this.donem,
    required this.ikonRengi,
    required this.ikon,
    required this.asyncDeger,
    required this.degisimAsync,
  });
}

// ── Tekil Stat Kart Widget'ı ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final degisim = data.degisimAsync;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst satır: ikon + dönem badge ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: data.ikonRengi.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.ikon, size: 18, color: data.ikonRengi),
                ),
                // Dönem badge'i
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.donem,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Başlık ──────────────────────────────────────────────────
            Text(
              data.baslik,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            // ── Değer ───────────────────────────────────────────────────
            data.asyncDeger == null
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    data.asyncDeger!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

            // ── Değişim badge'i ─────────────────────────────────────────
            if (degisim != null) ...[
              const SizedBox(height: 6),
              _DegisimBadge(yuzde: degisim),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Değişim Badge'i ────────────────────────────────────────────────────────

class _DegisimBadge extends StatelessWidget {
  final double yuzde;

  const _DegisimBadge({required this.yuzde});

  @override
  Widget build(BuildContext context) {
    final artis = yuzde >= 0;
    final renk = artis ? AppColors.success : AppColors.danger;
    final ikon = artis ? Icons.arrow_upward : Icons.arrow_downward;
    final etiket = '${artis ? '+' : ''}${yuzde.toStringAsFixed(1)}%';

    return Row(
      children: [
        Icon(ikon, size: 10, color: renk),
        const SizedBox(width: 2),
        Text(
          etiket,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: renk,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'dünden',
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Günlük Satış Grafiği Kartı
// ═══════════════════════════════════════════════════════════════════════════

class _DailyChartCard extends ConsumerStatefulWidget {
  const _DailyChartCard();

  @override
  ConsumerState<_DailyChartCard> createState() => _DailyChartCardState();
}

class _DailyChartCardState extends ConsumerState<_DailyChartCard> {
  int _secilenGun = 7; // Varsayılan: 7 gün
  final _gunSecenekleri = const [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final veriAsync = ref.watch(dailySalesProvider(_secilenGun));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık + seçici ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_secilenGun Günlük Satış',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                _ChipSecici(
                  secenekler: _gunSecenekleri
                      .map((g) => (etiket: '$g G', deger: g))
                      .toList(),
                  secilen: _secilenGun,
                  onSecim: (val) => setState(() => _secilenGun = val),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Grafik ──────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: veriAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Veri yüklenemedi',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                data: (veriler) => _SatisLineChart(
                  veriler: veriler,
                  formatEtiket: (dt) =>
                      '${dt.day}/${dt.month}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Aylık Satış Grafiği Kartı
// ═══════════════════════════════════════════════════════════════════════════

class _MonthlyChartCard extends ConsumerStatefulWidget {
  const _MonthlyChartCard();

  @override
  ConsumerState<_MonthlyChartCard> createState() => _MonthlyChartCardState();
}

class _MonthlyChartCardState extends ConsumerState<_MonthlyChartCard> {
  int _secilenAy = 6; // Varsayılan: 6 ay
  final _aySecenekleri = const [3, 6, 12, 24, 36];

  @override
  Widget build(BuildContext context) {
    final veriAsync = ref.watch(monthlySalesProvider(_secilenAy));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık + seçici ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_secilenAy Aylık Satış',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                _ChipSecici(
                  secenekler: _aySecenekleri
                      .map((a) => (etiket: '$a A', deger: a))
                      .toList(),
                  secilen: _secilenAy,
                  onSecim: (val) => setState(() => _secilenAy = val),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Grafik ──────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: veriAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Veri yüklenemedi',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                data: (veriler) => _SatisLineChart(
                  veriler: veriler,
                  formatEtiket: (dt) {
                    const aylar = [
                      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
                      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
                    ];
                    return "${aylar[dt.month - 1]}'${dt.year % 100}";
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Çizgi Grafik Widget'ı (fl_chart LineChart)
// ═══════════════════════════════════════════════════════════════════════════

class _SatisLineChart extends StatelessWidget {
  final List<({DateTime date, num amount})> veriler;
  final String Function(DateTime) formatEtiket;

  const _SatisLineChart({
    required this.veriler,
    required this.formatEtiket,
  });

  @override
  Widget build(BuildContext context) {
    if (veriler.isEmpty) {
      return const Center(
        child: Text(
          'Veri bulunamadı',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    // Y ekseni max değeri
    final maxY = veriler
        .map((v) => v.amount.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final yMax = maxY == 0 ? 100.0 : maxY * 1.2;

    // Nokta listesi
    final spots = veriler.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.amount.toDouble());
    }).toList();

    // X etiketi gösterim adımı — çok kalabalık olmasın
    final adim = (veriler.length / 6).ceil().clamp(1, veriler.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (veriler.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,

        // Grid
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),

        // Kenarlık
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
            left: BorderSide(color: Colors.grey.shade300),
          ),
        ),

        // Eksen başlıkları
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: yMax / 4,
              getTitlesWidget: (val, meta) {
                if (val == 0) return const SizedBox.shrink();
                final etiket = val >= 1000
                    ? '${(val / 1000).toStringAsFixed(1)}K'
                    : val.toStringAsFixed(0);
                return Text(
                  etiket,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: adim.toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= veriler.length) {
                  return const SizedBox.shrink();
                }
                if (idx % adim != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    formatEtiket(veriler[idx].date),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Tooltip
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary.withValues(alpha: 0.85),
            getTooltipItems: (spots) => spots.map((s) {
              final idx = s.x.round().clamp(0, veriler.length - 1);
              final v = veriler[idx];
              return LineTooltipItem(
                '${formatEtiket(v.date)}\n${_currencyFmt.format(v.amount)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),

        // Çizgi verisi
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: veriler.length <= 15,
              getDotPainter: (spot, xPct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Seçici Chip Satırı
// ═══════════════════════════════════════════════════════════════════════════

class _ChipSecici extends StatelessWidget {
  final List<({String etiket, int deger})> secenekler;
  final int secilen;
  final ValueChanged<int> onSecim;

  const _ChipSecici({
    required this.secenekler,
    required this.secilen,
    required this.onSecim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: secenekler.map((s) {
          final aktif = s.deger == secilen;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onSecim(s.deger),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: aktif ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: aktif ? AppColors.primary : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  s.etiket,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        aktif ? FontWeight.bold : FontWeight.normal,
                    color: aktif ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
