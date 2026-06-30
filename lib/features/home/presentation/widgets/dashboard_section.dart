import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/skeleton.dart';
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
        // Bölüm başlığı (Manrope — type.title)
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSizes.space16),

        // ── İmza: Tam-genişlik hero bandı (bugünkü ciro) ─────────────────
        const _HeroBand(),
        const SizedBox(height: AppSizes.space16),

        // ── Destek stat kartları (hero'yu tekrar etmez) ─────────────────
        _StatCardsRow(),
        const SizedBox(height: AppSizes.space16),

        // ── Grafikler ───────────────────────────────────────────────────
        if (context.isMobile)
          Column(
            children: const [
              _DailyChartCard(),
              SizedBox(height: AppSizes.space16),
              _MonthlyChartCard(),
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Expanded(child: _DailyChartCard()),
                SizedBox(width: AppSizes.space16),
                Expanded(child: _MonthlyChartCard()),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// İmza Öğesi — Hero Bandı (design-tokens §4: Hero Tutar + Altın Ray)
// ═══════════════════════════════════════════════════════════════════════════

/// Ekranın TEK kahramanı: bugünkü toplam ciro (₺). İri tabular rakam +
/// hemen altında ince altın aksan rayı (rakam genişliğinin ~%40'ı, pill).
/// Veri: mevcut `todaySummaryProvider` (`d.revenue`) — yeni provider yok.
class _HeroBand extends ConsumerWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaySummaryProvider);
    final yesterdayAsync = ref.watch(yesterdaySummaryProvider);
    final mobil = context.isMobile;

    // Dünkü ciroya göre değişim — hero'nun yanında sakin rozet (ikinci tutar değil).
    final degisim = _yuzdeDegisim(
      todayAsync.valueOrNull?.revenue.toDouble(),
      yesterdayAsync.valueOrNull?.revenue.toDouble(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space20,
        vertical: AppSizes.space20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiket + karşılaştırma rozeti
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space4,
            children: [
              const Text(
                'BUGÜNKÜ CİRO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              if (degisim != null)
                _DegisimBadge(yuzde: degisim, etiket: 'dünden'),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          // Hero tutar + altın ray
          todayAsync.when(
            loading: () => const Skeleton(width: 220, height: 40, radius: 8),
            error: (e, s) => Text(
              '—',
              style: TextStyle(
                fontSize: mobil ? 30 : 38,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
            data: (d) => IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currencyFmt.format(d.revenue),
                    style: TextStyle(
                      fontSize: mobil ? 30 : 38,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.5,
                      color: AppColors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space6),
                  // Altın aksan rayı — yalnızca hero tutarın altında (~%40).
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.4,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                      ),
                    ),
                  ),
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

    // Destek kartları: hero (bugünkü ciro) zaten gösterildiği için TEKRAR
    // edilmez. Kalan metrikler sakin kartlarda — semantik % rozeti dışında renk yok.
    final cards = [
      _StatCardData(
        baslik: 'Satış Adedi',
        donem: 'Bugün',
        asyncDeger: todayAsync.when(
          data: (d) => '${d.count} adet',
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisim: _yuzdeDegisim(
          todayAsync.valueOrNull?.count.toDouble(),
          yesterdayAsync.valueOrNull?.count.toDouble(),
        ),
        karsilastirmaEtiketi: 'dünden',
      ),
      _StatCardData(
        baslik: 'Aylık Ciro',
        donem: 'Bu Ay',
        asyncDeger: monthAsync.when(
          data: (d) => _currencyFmt.format(d.revenue),
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisim: _yuzdeDegisim(
          monthAsync.valueOrNull?.revenue.toDouble(),
          lastMonthAsync.valueOrNull?.toDouble(),
        ),
        karsilastirmaEtiketi: 'geçen aydan',
      ),
      _StatCardData(
        baslik: 'Aylık Adet',
        donem: 'Bu Ay',
        asyncDeger: monthAsync.when(
          data: (d) => '${d.count} adet',
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisim: null, // aylık adet için geçen ay adet verisi yok
        karsilastirmaEtiketi: '',
      ),
    ];

    if (context.isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: AppSizes.space12,
        mainAxisSpacing: AppSizes.space12,
        childAspectRatio: 1.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards.map((c) => _StatCard(data: c)).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.space12),
          Expanded(child: _StatCard(data: cards[i])),
        ],
      ],
    );
  }
}

/// İki değer arasındaki yüzde değişimini hesapla (sadece görsel — iş mantığı değil).
double? _yuzdeDegisim(double? yeni, double? eski) {
  if (yeni == null || eski == null) return null;
  if (eski == 0) return yeni > 0 ? 100.0 : null;
  return ((yeni - eski) / eski) * 100;
}

// ── Stat Kart Verisi ───────────────────────────────────────────────────────

class _StatCardData {
  final String baslik;
  final String donem;
  final String? asyncDeger; // null → yükleniyor
  final double? degisim; // null → hesaplanamadı
  final String karsilastirmaEtiketi; // örn. 'dünden', 'geçen aydan'

  const _StatCardData({
    required this.baslik,
    required this.donem,
    required this.asyncDeger,
    required this.degisim,
    required this.karsilastirmaEtiketi,
  });
}

// ── Tekil Stat Kart Widget'ı ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final degisim = data.degisim;

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Üst satır: başlık + dönem pill ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  data.baslik,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSizes.space6),
              _DonemPill(donem: data.donem),
            ],
          ),
          const SizedBox(height: AppSizes.space12),

          // ── Değer (Inter tabular) ─────────────────────────────────────
          data.asyncDeger == null
              ? const Skeleton(width: 90, height: 22, radius: 6)
              // Dar kartta büyük tutarlar kırpılmasın: tek satır kalır,
              // sığmazsa kırpmak yerine ölçek düşürülür (asla büyütülmez).
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.asyncDeger!,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

          // ── Değişim rozeti ────────────────────────────────────────────
          if (degisim != null) ...[
            const SizedBox(height: AppSizes.space8),
            _DegisimBadge(
              yuzde: degisim,
              etiket: data.karsilastirmaEtiketi,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dönem Pill'i ───────────────────────────────────────────────────────────

class _DonemPill extends StatelessWidget {
  final String donem;
  const _DonemPill({required this.donem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        donem,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Değişim Badge'i ────────────────────────────────────────────────────────

class _DegisimBadge extends StatelessWidget {
  final double yuzde;
  final String etiket;

  const _DegisimBadge({required this.yuzde, this.etiket = 'dünden'});

  @override
  Widget build(BuildContext context) {
    final artis = yuzde >= 0;
    // Semantik renk: kazanç → success, kayıp → danger (token §1).
    final renk = artis ? AppColors.success : AppColors.danger;
    final ikon =
        artis ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final yuzdeMetin = '${artis ? '+' : ''}${yuzde.toStringAsFixed(1)}%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yüzde pill'i (semantik tonlu yumuşak zemin)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space6,
            vertical: AppSizes.space2,
          ),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 12, color: renk),
              const SizedBox(width: AppSizes.space2),
              Text(
                yuzdeMetin,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: renk,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (etiket.isNotEmpty) ...[
          const SizedBox(width: AppSizes.space4),
          Flexible(
            child: Text(
              etiket,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
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

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık + seçici ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_secilenGun Günlük Satış',
                  style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: AppSizes.space16),

            // ── Grafik ──────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: veriAsync.when(
                loading: () => const BrandLoader(label: 'Yükleniyor…'),
                error: (e, _) => const Center(
                  child: Text(
                    'Veri yüklenemedi',
                    style: TextStyle(color: AppColors.textMuted),
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

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık + seçici ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_secilenAy Aylık Satış',
                  style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: AppSizes.space16),

            // ── Grafik ──────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: veriAsync.when(
                loading: () => const BrandLoader(label: 'Yükleniyor…'),
                error: (e, _) => const Center(
                  child: Text(
                    'Veri yüklenemedi',
                    style: TextStyle(color: AppColors.textMuted),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 28, color: AppColors.textMuted),
            SizedBox(height: AppSizes.space8),
            Text(
              'Bu aralıkta satış yok',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
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
            color: AppColors.textMuted.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),

        // Kenarlık
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
            left: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
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
                    fontFeatures: [FontFeature.tabularFigures()],
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
                  fontFeatures: [FontFeature.tabularFigures()],
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
            padding: const EdgeInsets.only(left: AppSizes.space4),
            child: GestureDetector(
              onTap: () => onSecim(s.deger),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space8,
                  vertical: AppSizes.space4,
                ),
                decoration: BoxDecoration(
                  color: aktif ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  border: Border.all(
                    color: aktif
                        ? AppColors.primary
                        : AppColors.textMuted.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  s.etiket,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
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
