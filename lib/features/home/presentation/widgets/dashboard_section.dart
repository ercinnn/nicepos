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
    final mobil = context.isMobile;

    // Tüm dashboard içeriği tek bir Column'da; hero · stat kartları · günlük
    // grafik · yıllık grafik hepsi AYNI genişlikte hizalı. Masaüstünde dış
    // container %90 genişliği yönetir (grafiklerde ayrı sarmalayıcı YOK);
    // mobilde tam genişlik kalır.
    final icerik = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── İmza: Hero bandı (bugünkü ciro) ──────────────────────────────
        const _HeroBand(),
        const SizedBox(height: AppSizes.space16),

        // ── Destek stat kartları (hero'yu tekrar etmez) ─────────────────
        _StatCardsRow(),
        const SizedBox(height: AppSizes.space16),

        // ── Grafik: Günlük Satış Grafiği ─────────────────────────────────
        // Web: 8/15/30 gün seçilebilir (varsayılan 30). Mobil: sabit 8 gün.
        // Genişlik dış container tarafından yönetilir.
        _DailySalesChartCard(compact: mobil),
        const SizedBox(height: AppSizes.space16),

        // ── Grafik: Yıllık Ciro Karşılaştırma (çok-yıl, Oca–Ara) ─────────
        const _YillikKarsilastirmaCard(),
        const SizedBox(height: AppSizes.space16),

        // ── Grafik: Yıllık Ortalama Ciro (kümülatif günlük ortalama) ─────
        const _YillikOrtalamaCiroCard(),
      ],
    );

    // Mobilde sarma; masaüstünde tek ortalanmış %90 max-genişlik container.
    if (mobil) return icerik;
    return LayoutBuilder(
      builder: (ctx, c) => Center(
        child: SizedBox(width: c.maxWidth * 0.9, child: icerik),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// İmza Öğesi — Hero Bandı (design-tokens §4: Hero Tutar + Altın Ray)
// ═══════════════════════════════════════════════════════════════════════════

/// Ekranın TEK kahramanı: bugünkü toplam ciro (₺). İri tabular rakam +
/// hemen altında ince altın aksan rayı (rakam genişliğinin ~%40'ı, pill).
/// Veri: mevcut `todaySummaryProvider` (`d.revenue`) — yeni provider yok.
// -12° cinsinden radyan (yalnız hero'nun asimetrik köşe kaması için) —
// `dart:math` import etmeye değmeyecek tek kullanımlık sabit.
const double _kHeroWedgeAngle = -0.2094395102393195;

/// Anasayfa hero bandı — KARAR v1.15 (gradyan + asimetrik "dijital platform"
/// yönü). §4 imzası (Hero Tutar + Altın Ray) korunur; yalnız hero'nun KENDİ
/// yüzeyi zenginleşir — geri kalan uygulama (kartlar, tablolar, sidebar)
/// sakin/beyaz kalmaya devam eder ("boldness tek yerde"). Yeni renk YOK,
/// yalnız mevcut lacivert/altın rampasının bir durağı eklendi (`primaryDeep`).
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // 3 duraklı lacivert gradyan (155°'ye yakın, sol-üstten sağ-alta) —
          // mevcut primary/primaryDark/primaryDeep rampası, yeni ton yok.
          gradient: const LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.6, 1),
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
              AppColors.primaryDeep,
            ],
            stops: [0.0, 0.58, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Asimetrik altın parıltı — yalnız sağ-üst köşede (imza altını,
            // §5 "altın ekonomisi": dekor değil, hero'nun kendi vurgusu).
            Positioned(
              top: -70,
              right: -50,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.32),
                        AppColors.gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // İnce ışık kaması — asimetriyi güçlendiren tek dekoratif öğe.
            Positioned(
              top: -90,
              right: -110,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: _kHeroWedgeAngle,
                  child: Container(
                    width: 320,
                    height: 420,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.55],
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space20,
                vertical: AppSizes.space20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiket + karşılaştırma rozeti — sağa/üste yaslı (asimetri).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BUGÜNKÜ CİRO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      if (degisim != null)
                        _DegisimBadgeOnDark(yuzde: degisim, etiket: 'dünden'),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space20),
                  // Hero tutar (solda/altta) + gradyanlı ray · Satış Adedi (sağda) — çapraz denge.
                  todayAsync.when(
                    loading: () =>
                        const Skeleton(width: 220, height: 40, radius: 8),
                    error: (e, s) => Text(
                      '—',
                      style: TextStyle(
                        fontSize: mobil ? 30 : 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    data: (d) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currencyFmt.format(d.revenue),
                                style: TextStyle(
                                  fontSize: mobil ? 30 : 38,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSizes.space8),
                              // Altın ray artık düz dolgu değil, sağa doğru
                              // soluklaşan gradyan + hafif parıltı (§4 imzası
                              // korunur — ray yalnız hero'nun altında).
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: mobil ? 0.55 : 0.46,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusPill),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gold,
                                        AppColors.goldLight,
                                        AppColors.goldLight
                                            .withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.65, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.55),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!mobil) ...[
                          const SizedBox(width: AppSizes.space16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SATIŞ ADEDİ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: AppSizes.space2),
                              Text(
                                '${d.count} adet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `_DegisimBadge`'in koyu (gradyan hero) zemin varyantı — camsı/parlayan
/// pill. Diğer stat kartları (beyaz zemin) hâlâ `_DegisimBadge` kullanır,
/// bu widget yalnız hero bandına özeldir.
class _DegisimBadgeOnDark extends StatelessWidget {
  final double yuzde;
  final String etiket;

  const _DegisimBadgeOnDark({required this.yuzde, this.etiket = 'dünden'});

  @override
  Widget build(BuildContext context) {
    final artis = yuzde >= 0;
    final renk = artis ? AppColors.success : AppColors.danger;
    final glowRenk = artis ? const Color(0xFF3CC77C) : const Color(0xFFE0776A);
    final ikon =
        artis ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final yuzdeMetin = '${artis ? '+' : ''}${yuzde.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: glowRenk.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 12, color: glowRenk),
          const SizedBox(width: AppSizes.space2),
          Text(
            yuzdeMetin,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: glowRenk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (etiket.isNotEmpty) ...[
            const SizedBox(width: AppSizes.space4),
            Text(
              etiket,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5 Stat Kartı Satırı (masaüstü: yanyana tek satır; mobil: 2 sütunlu grid)
// ═══════════════════════════════════════════════════════════════════════════

class _StatCardsRow extends ConsumerWidget {
  const _StatCardsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaySummaryProvider);
    final yesterdayAsync = ref.watch(yesterdaySummaryProvider);
    final monthAsync = ref.watch(monthSummaryProvider);
    final lastMonthAsync = ref.watch(lastMonthRevenueProvider);
    final ytdAsync = ref.watch(yearToDateRevenueProvider);
    final last365Async = ref.watch(last365DaysRevenueProvider);

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
      _StatCardData(
        baslik: 'Yıllık Ciro',
        donem: 'Bu Yıl',
        asyncDeger: ytdAsync.when(
          data: (v) => _currencyFmt.format(v),
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisim: null, // YTD karşılaştırması yok
        karsilastirmaEtiketi: '',
      ),
      _StatCardData(
        baslik: 'Son 365 Günlük Ciro',
        donem: '365 Gün',
        asyncDeger: last365Async.when(
          data: (v) => _currencyFmt.format(v),
          loading: () => null,
          error: (e, s) => '—',
        ),
        degisim: null,
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

    // IntrinsicHeight: kaydırılabilir sayfada (sınırsız yükseklik) stretch'li
    // Row'a sınırlı yükseklik verir; aksi halde "infinite height" render hatası
    // tüm dashboard'u çökertir.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSizes.space12),
            Expanded(child: _StatCard(data: cards[i])),
          ],
        ],
      ),
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
// Günlük Satış Grafiği Kartı (son 8/15/30 gün)
// ═══════════════════════════════════════════════════════════════════════════
// Web: 8/15/30 gün seçilebilir (varsayılan 30). Mobil (compact): sabit 8 gün,
// seçici yok. X ekseninde her günün tarihi (GG/AA/YY) + altında Türkçe gün
// kısaltması (Pzt..Pzr) gösterilir.

const _gunKisaltma = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Pzr'];

String _ggAaYy(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${(dt.year % 100).toString().padLeft(2, '0')}';

class _DailySalesChartCard extends ConsumerStatefulWidget {
  /// Mobil için sıkıştırılmış mod: sabit 8 gün, gün seçici gösterilmez.
  final bool compact;
  const _DailySalesChartCard({required this.compact});

  @override
  ConsumerState<_DailySalesChartCard> createState() =>
      _DailySalesChartCardState();
}

class _DailySalesChartCardState extends ConsumerState<_DailySalesChartCard> {
  late int _secilenGun = widget.compact ? 8 : 30;
  static const _gunSecenekleri = [8, 15, 30];

  @override
  Widget build(BuildContext context) {
    final veriAsync = ref.watch(dailySalesProvider(_secilenGun));

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık + (web) gün seçici ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$_secilenGun Günlük Satış Grafiği',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!widget.compact)
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

          // ── Grafik ────────────────────────────────────────────────────
          SizedBox(
            height: 250,
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
                formatEtiket: _ggAaYy,
                // X ekseninde her gün için tarih + gün adı (iki satır).
                bottomLabelBuilder: (dt) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ggAaYy(dt),
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1.2,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _gunKisaltma[dt.weekday - 1],
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                bottomReservedSize: 36,
                showAllBottom: true,
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

  /// X ekseni etiketini özel bir widget olarak çizer (ör. tarih + gün adı).
  /// null ise [formatEtiket] tek satır metin olarak kullanılır.
  final Widget Function(DateTime)? bottomLabelBuilder;

  /// X ekseni etiket alanı yüksekliği.
  final double bottomReservedSize;

  /// true ise her veri noktası için etiket gösterilir (seyreltme yapılmaz).
  final bool showAllBottom;

  const _SatisLineChart({
    required this.veriler,
    required this.formatEtiket,
    this.bottomLabelBuilder,
    this.bottomReservedSize = 22,
    this.showAllBottom = false,
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

    // Hafta sonu bantları (KARAR v1.7): Cumartesi = altın, Pazar = kızıl,
    // her ikisi de düşük-alfa faint wash (bilgi amaçlı, imza rayı DEĞİL).
    // Bantlar çizgilerin ALTINDA (arka planda) kalır; 0.5 taşmayı grafik kırpar.
    final haftaSonuBantlari = <VerticalRangeAnnotation>[
      for (var idx = 0; idx < veriler.length; idx++)
        if (veriler[idx].date.weekday == DateTime.saturday ||
            veriler[idx].date.weekday == DateTime.sunday)
          VerticalRangeAnnotation(
            x1: idx - 0.5,
            x2: idx + 0.5,
            color: (veriler[idx].date.weekday == DateTime.saturday
                    ? AppColors.gold
                    : AppColors.danger)
                .withValues(alpha: 0.09),
          ),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (veriler.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,

        // Hafta sonu dikey bantları (arka plan).
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: haftaSonuBantlari,
        ),

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
              reservedSize: bottomReservedSize,
              interval: showAllBottom ? 1 : adim.toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= veriler.length) {
                  return const SizedBox.shrink();
                }
                if (!showAllBottom && idx % adim != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: bottomLabelBuilder != null
                      ? bottomLabelBuilder!(veriler[idx].date)
                      : Text(
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
// Yıllık Ciro Karşılaştırma Kartı (çok-yıl, Oca–Ara)
// ═══════════════════════════════════════════════════════════════════════════
// design-tokens KARAR v1.4: Günlük satış grafiğinin altında, aynı eksende her
// yıl ayrı seri. Yıllar aç/kapa toggle chip ile seçilir (çoklu-seçim, radyo
// DEĞİL). HERO değildir — altın ray/kenarlık yok. Seri renkleri kategorik
// ayraçtır (semantik/imza rolü taşımaz), sıra: yıl indeksine göre atanır.

const _ayKisaltma = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

const int _baslangicYil = 2021;

/// Seri renk paleti (§1) — yıl indeksine göre kategorik renk atar.
/// `renk = liste[(yıl − 2021) % liste.length]`.
Color _yilRengi(int yil) {
  const palet = [
    AppColors.primary, // lacivert
    AppColors.success, // yeşil
    AppColors.pos, // çelik mavi
    AppColors.splitPayment, // mor
    AppColors.gold, // altın (burada imza değil, kategorik)
    AppColors.danger, // kiremit (burada hata değil, kategorik)
  ];
  final idx = ((yil - _baslangicYil) % palet.length + palet.length) %
      palet.length;
  return palet[idx];
}

class _YillikKarsilastirmaCard extends ConsumerStatefulWidget {
  const _YillikKarsilastirmaCard();

  @override
  ConsumerState<_YillikKarsilastirmaCard> createState() =>
      _YillikKarsilastirmaCardState();
}

class _YillikKarsilastirmaCardState
    extends ConsumerState<_YillikKarsilastirmaCard> {
  late final int _buYil = DateTime.now().year;
  // Varsayılan: bu yıl + geçen yıl açık.
  late final Set<int> _acikYillar = {_buYil, _buYil - 1};

  @override
  Widget build(BuildContext context) {
    // Cari yıl AYRI (küçük/hızlı sorgu → hemen gelir), geçmiş yıllar AYRI
    // (arkadan yüklenip içeri dolar). İki provider bağımsız izlenir.
    final currentAsync = ref.watch(currentYearMonthlyProvider);
    final historicalAsync = ref.watch(historicalYearlyProvider);

    // Birleştirilmiş veri: geçmiş + cari. Cari yıl anahtarı DAİMA current'tan
    // gelir (spread sırası: current en sonda → çakışmada o kazanır).
    final merged = <int, List<num>>{
      ...?historicalAsync.valueOrNull,
      ...?currentAsync.valueOrNull,
    };

    // Chip'ler artımlı belirir: yalnız merged'te olan yıllar için görünür
    // (cari yıl hızlı gelir; geçmiş yıllar geçmiş sorgusu bitince eklenir).
    final mevcutYillar = merged.keys.toList()..sort();

    final historicalYukleniyor = historicalAsync.isLoading;
    final ikisiDeHata = currentAsync.hasError && historicalAsync.hasError;

    return Container(
      // HERO değil: yalnızca gölge + yuvarlatma, altın kenarlık/ray YOK.
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yıllık Ciro Karşılaştırma (Oca–Ara)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.space12),

          // ── Yıl aç/kapa toggle chip'leri (çoklu-seçim) ───────────────
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            children: mevcutYillar
                .map((yil) => _YilChip(
                      yil: yil,
                      renk: _yilRengi(yil),
                      acik: _acikYillar.contains(yil),
                      onTap: () => setState(() {
                        if (!_acikYillar.remove(yil)) _acikYillar.add(yil);
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSizes.space16),

          // ── Grafik ────────────────────────────────────────────────────
          SizedBox(
            height: 300,
            child: _grafikAlani(
              merged: merged,
              historicalYukleniyor: historicalYukleniyor,
              ikisiDeHata: ikisiDeHata,
            ),
          ),
        ],
      ),
    );
  }

  // Grafik alanının durum mantığı (kademeli veri yükleme).
  Widget _grafikAlani({
    required Map<int, List<num>> merged,
    required bool historicalYukleniyor,
    required bool ikisiDeHata,
  }) {
    // ── Henüz hiç veri yok ────────────────────────────────────────────────
    if (merged.isEmpty) {
      // İkisi de hata → veri yüklenemedi. Aksi halde (biri/ikisi yükleniyor)
      // boş grafik iskeleti + "Yükleniyor…" ipucu.
      if (ikisiDeHata) {
        return const Center(
          child: Text(
            'Veri yüklenemedi',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      return Stack(
        children: const [
          _YillikLineChart(veri: {}, acikYillar: []),
          _YukleniyorIpucu(),
        ],
      );
    }

    // ── Veri var → yalnız merged'te bulunan açık yılları çiz ──────────────
    // (merged'te OLMAYAN açık yılı filtrele → null liste hatası olmasın.)
    final acik = _acikYillar.where(merged.containsKey).toList()..sort();
    if (acik.isEmpty) {
      return const Center(
        child: Text(
          'Karşılaştırmak için en az bir yıl seçin',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final grafik = _YillikLineChart(veri: merged, acikYillar: acik);
    // Geçmiş yıllar HÂLÂ yükleniyorsa: cari yıl çizgisi hemen görünür, sağ
    // üstte küçük "Yükleniyor…" ipucu korunur (geçmiş gelince fl_chart
    // animasyonuyla içeri dolar, ipucu kalkar).
    if (historicalYukleniyor) {
      return Stack(
        children: [
          grafik,
          const _YukleniyorIpucu(),
        ],
      );
    }
    return grafik;
  }
}

// ── Grafik sağ üstünde küçük "Yükleniyor…" ipucu (kademeli yükleme) ──────────

class _YukleniyorIpucu extends StatelessWidget {
  const _YukleniyorIpucu();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      right: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: AppSizes.space6),
          Text(
            'Yükleniyor…',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yıl toggle chip'i (renk noktası + yıl etiketi) ──────────────────────────

class _YilChip extends StatelessWidget {
  final int yil;
  final Color renk;
  final bool acik;
  final VoidCallback onTap;

  const _YilChip({
    required this.yil,
    required this.renk,
    required this.acik,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space6,
        ),
        decoration: BoxDecoration(
          color: acik ? renk.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: acik ? renk : AppColors.textMuted.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Renk noktası — kapalıyken soluk.
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: acik ? renk : renk.withValues(alpha: 0.30),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.space6),
            Text(
              '$yil',
              style: TextStyle(
                fontSize: 12,
                fontWeight: acik ? FontWeight.w700 : FontWeight.w500,
                color: acik ? AppColors.textPrimary : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Çok-serili yıllık çizgi grafik ──────────────────────────────────────────

class _YillikLineChart extends StatelessWidget {
  final Map<int, List<num>> veri;
  final List<int> acikYillar;

  const _YillikLineChart({required this.veri, required this.acikYillar});

  @override
  Widget build(BuildContext context) {
    // Y ekseni max — yalnızca açık yılların değerlerinden.
    var maxY = 0.0;
    for (final yil in acikYillar) {
      for (final v in (veri[yil] ?? const <num>[])) {
        final d = v.toDouble();
        if (d > maxY) maxY = d;
      }
    }
    final yMax = maxY == 0 ? 100.0 : maxY * 1.2;

    // Her açık yıl için bir çizgi (dolgusuz, 2px, kategorik renk).
    final barlar = acikYillar.map((yil) {
      final aylik = veri[yil] ?? List<num>.filled(12, 0);
      final spots = [
        for (var ay = 0; ay < 12; ay++)
          FlSpot(ay.toDouble(), aylik[ay].toDouble()),
      ];
      final renk = _yilRengi(yil);
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        preventCurveOverShooting: true,
        color: renk,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false), // dolgu YOK
      );
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: yMax,

        // Izgara (nötr hairline ~0.15)
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textMuted.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),

        // Eksen kenarlığı (nötr ~0.25)
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
            left: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
          ),
        ),

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
              interval: 1,
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _ayKisaltma[idx],
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

        // Tooltip: yıl + ay + tutar (her açık seri için).
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary.withValues(alpha: 0.90),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final ay = s.x.round().clamp(0, 11);
              // barIndex → açık yıl sırası ile eşleşir.
              final yil = (s.barIndex >= 0 && s.barIndex < acikYillar.length)
                  ? acikYillar[s.barIndex]
                  : null;
              final onEk = yil != null ? '$yil · ' : '';
              return LineTooltipItem(
                '$onEk${_ayKisaltma[ay]}\n${_currencyFmt.format(s.y)}',
                TextStyle(
                  color: yil != null ? _yilRengi(yil) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            }).toList(),
          ),
        ),

        lineBarsData: barlar,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Yıllık Ortalama Ciro Kartı (kümülatif günlük ortalama, yıl-içi)
// ═══════════════════════════════════════════════════════════════════════════
// Her yıl KENDİ İÇİNDE değerlendirilir (Ocak'ta sıfırlanır). Ay sonu noktası =
// o yılın Ocak'ından o aya kadarki TOPLAM ciro ÷ o tarihe kadarki TOPLAM gün
// sayısı — o ayın KENDİ ortalaması DEĞİL. Cari yılın henüz bitmemiş ayı (ör.
// bugün 17 Temmuzsa Temmuz noktası yalnız ilk 17 günü kapsar) `bugün.day` ile
// hesaplanır; `sales_monthly_totals` zaten yalnızca gerçekleşmiş satışları
// içerdiği için ekstra sorguya gerek yok — "Yıllık Ciro Karşılaştırma"
// kartıyla AYNI iki provider (`currentYearMonthlyProvider` /
// `historicalYearlyProvider`) yeniden kullanılır.
// Yıl seçimi sabit 3 yılla sınırlı: bu yıl ve önceki 2 yıl (bugün için
// 2024/2025/2026) — chip'lerle aç/kapa (çoklu-seçim).

/// [aylik]: 12 elemanlı (0=Ocak..11=Aralık) [yil]'ın AY BAŞINA toplam cirosu.
/// Dönüş: cari ay dahil o ana kadarki ayların kümülatif ortalama noktaları
/// (cari yılda henüz gelmemiş aylar için nokta ÜRETİLMEZ).
List<FlSpot> _kumulatifOrtalamaSpots(
  int yil,
  List<num> aylik,
  int buYil,
  DateTime bugun,
) {
  final sonAy = yil == buYil ? bugun.month : 12;
  final spots = <FlSpot>[];
  num toplamCiro = 0;
  var toplamGun = 0;
  for (var ay = 1; ay <= sonAy; ay++) {
    toplamCiro += aylik[ay - 1];
    final ayGunSayisi = (yil == buYil && ay == bugun.month)
        ? bugun.day
        : DateTime(yil, ay + 1, 0).day; // ay'ın takvim gün sayısı (artık yıl dahil)
    toplamGun += ayGunSayisi;
    spots.add(FlSpot(
      (ay - 1).toDouble(),
      toplamGun == 0 ? 0 : toplamCiro / toplamGun,
    ));
  }
  return spots;
}

class _YillikOrtalamaCiroCard extends ConsumerStatefulWidget {
  const _YillikOrtalamaCiroCard();

  @override
  ConsumerState<_YillikOrtalamaCiroCard> createState() =>
      _YillikOrtalamaCiroCardState();
}

class _YillikOrtalamaCiroCardState
    extends ConsumerState<_YillikOrtalamaCiroCard> {
  late final int _buYil = DateTime.now().year;
  late final List<int> _yillar = [_buYil - 2, _buYil - 1, _buYil];
  // Varsayılan: sabit 3 yılın hepsi açık (karşılaştırma amacı).
  late final Set<int> _acikYillar = _yillar.toSet();

  @override
  Widget build(BuildContext context) {
    // Aynı iki provider "Yıllık Ciro Karşılaştırma" kartıyla paylaşılır →
    // Riverpod cache sayesinde ekstra ağ isteği olmaz.
    final currentAsync = ref.watch(currentYearMonthlyProvider);
    final historicalAsync = ref.watch(historicalYearlyProvider);

    final merged = <int, List<num>>{
      ...?historicalAsync.valueOrNull,
      ...?currentAsync.valueOrNull,
    };

    final mevcutYillar = _yillar.where(merged.containsKey).toList()..sort();
    final yukleniyor = currentAsync.isLoading || historicalAsync.isLoading;
    final ikisiDeHata = currentAsync.hasError && historicalAsync.hasError;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yıllık Ortalama Ciro (Kümülatif Günlük Ortalama)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.space12),

          // ── Yıl aç/kapa toggle chip'leri (çoklu-seçim, sabit 3 yıl) ─────
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            children: mevcutYillar
                .map((yil) => _YilChip(
                      yil: yil,
                      renk: _yilRengi(yil),
                      acik: _acikYillar.contains(yil),
                      onTap: () => setState(() {
                        if (!_acikYillar.remove(yil)) _acikYillar.add(yil);
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSizes.space16),

          SizedBox(
            height: 300,
            child: _ortalamaGrafikAlani(
              merged: merged,
              yukleniyor: yukleniyor,
              ikisiDeHata: ikisiDeHata,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ortalamaGrafikAlani({
    required Map<int, List<num>> merged,
    required bool yukleniyor,
    required bool ikisiDeHata,
  }) {
    if (merged.isEmpty) {
      if (ikisiDeHata) {
        return const Center(
          child: Text(
            'Veri yüklenemedi',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      return Stack(
        children: const [
          _YillikOrtalamaLineChart(veri: {}, acikYillar: []),
          _YukleniyorIpucu(),
        ],
      );
    }

    final acik = _acikYillar.where(merged.containsKey).toList()..sort();
    if (acik.isEmpty) {
      return const Center(
        child: Text(
          'Karşılaştırmak için en az bir yıl seçin',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final grafik = _YillikOrtalamaLineChart(veri: merged, acikYillar: acik);
    if (yukleniyor) {
      return Stack(
        children: [grafik, const _YukleniyorIpucu()],
      );
    }
    return grafik;
  }
}

// ── Kümülatif ortalama çok-serili çizgi grafik ──────────────────────────────

class _YillikOrtalamaLineChart extends StatelessWidget {
  final Map<int, List<num>> veri;
  final List<int> acikYillar;

  const _YillikOrtalamaLineChart({
    required this.veri,
    required this.acikYillar,
  });

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final buYil = bugun.year;

    final serilerSpot = <int, List<FlSpot>>{
      for (final yil in acikYillar)
        yil: _kumulatifOrtalamaSpots(
          yil,
          veri[yil] ?? List<num>.filled(12, 0),
          buYil,
          bugun,
        ),
    };

    var maxY = 0.0;
    for (final spots in serilerSpot.values) {
      for (final s in spots) {
        if (s.y > maxY) maxY = s.y;
      }
    }
    final yMax = maxY == 0 ? 100.0 : maxY * 1.2;

    final barlar = acikYillar.map((yil) {
      final renk = _yilRengi(yil);
      return LineChartBarData(
        spots: serilerSpot[yil]!,
        isCurved: true,
        curveSmoothness: 0.25,
        preventCurveOverShooting: true,
        color: renk,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: yMax,

        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textMuted.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),

        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
            left: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.25)),
          ),
        ),

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
              interval: 1,
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _ayKisaltma[idx],
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

        // Tooltip: yıl + ay + o ana kadarki kümülatif günlük ortalama.
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary.withValues(alpha: 0.90),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final ay = s.x.round().clamp(0, 11);
              final yil = (s.barIndex >= 0 && s.barIndex < acikYillar.length)
                  ? acikYillar[s.barIndex]
                  : null;
              final onEk = yil != null ? '$yil · ' : '';
              return LineTooltipItem(
                '$onEk${_ayKisaltma[ay]}\n${_currencyFmt.format(s.y)}',
                TextStyle(
                  color: yil != null ? _yilRengi(yil) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            }).toList(),
          ),
        ),

        lineBarsData: barlar,
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
