import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';

// ═══════════════════════════════════════════════════════════════════════════
// InstrumentHero — Faz 2 paylaşılan "enstrüman okuma göstergesi" hero'su
// (design-tokens §6.3, Konsol Tasarım Dili v2.0).
//
// Dört Faz-2 hero'su (Raporlar · Kasa · Müşteri liste · Müşteri detay) BİREBİR
// aynı görünsün diye TEK bileşen. Dashboard `_HeroBand` (bespoke: ışıltı/asimetri,
// §4 v1.15) referans görsel değerlerdir; bu bileşen o değerlerle EŞLEŞİR ama
// STATİKTİR — §4 v1.15 gereği ışıltı animasyonu YALNIZ Dashboard'a aittir, burada
// yeni AnimationController AÇILMAZ / shimmer eklenmez.
//
// İçerik (§6.3):
//   • Koyu panel yüzeyi: primaryDark → primaryDeep gradyan (~155°), radiusLg,
//     elevatedShadow. Kenarlıksız (yalnız çok soluk graticule hairline, §5 hero
//     istisnası — altın border YOK).
//   • 4 köşe reticle (L-nişangâh), gold ~%18 alfa. Positioned DAİMA Stack'in
//     DOĞRUDAN çocuğu (CLAUDE.md ParentDataWidget tuzağı).
//   • Mikro-etiket (uppercase, panel.muted), hero tutar (type.display, beyaz),
//     tick'li okuma cetveli (ray) — ray rengi PARAMETRE (varsayılan altın;
//     müşteri hero'larında semantik danger/success geçilir).
//   • Sınırsız/sınırlı genişlik güvenliği: tutar+ray FittedBox(scaleDown) içinde,
//     ray SABİT yükseklikli Container'da (sonsuz-yükseklik yok).
// ═══════════════════════════════════════════════════════════════════════════

/// Koyu enstrüman paneli gradyanı (~155°, sol-üstten sağ-alta) — Dashboard
/// `_panelDecoration` ile birebir aynı değerler.
const _kPanelGradient = LinearGradient(
  begin: Alignment(-0.6, -1),
  end: Alignment(0.6, 1),
  colors: [AppColors.primaryDark, AppColors.primaryDeep],
);

/// Reticle (nişangâh) köşe rengi — gold ~%18 alfa (`panel.reticle`, §6.2).
const _kReticleRenk = Color(0x2EC9A84C);

/// Enstrüman paneli kutu dekorasyonu (§6.2): koyu gradyan + çok soluk graticule
/// kenar (`textMuted` ≤0.08) + yumuşak yükseltilmiş gölge — altın border YOK.
/// `InstrumentHero` bunu kullanır; loading/error yer tutucularının hero ile
/// aynı yüzeyi göstermesi için de dışa açıktır (Kasa hero placeholder'ı).
BoxDecoration instrumentPanelDecoration() => BoxDecoration(
      gradient: _kPanelGradient,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.08)),
      boxShadow: AppSizes.elevatedShadow,
    );

/// Koyu panel üstünde kategorik/koyu bir semantik rengi okunur kılmak için
/// beyazla harmanlar (§6.4 — koyu `danger` durağı koyu zeminde kaybolur; hue
/// korunur, yalnız parlaklık artar). Yeni hex değil, alfa kompozisyonu.
/// Kasa trailing (işletme giderleri) gibi panel üstü ikincil okumalarda kullanılır.
Color instrumentPanelReadable(Color c) =>
    Color.alphaBlend(Colors.white.withValues(alpha: 0.30), c);

/// Faz-2 enstrüman hero'su.
///
/// [label] uppercase mikro-etiket (ör. `'TOPLAM CİRO · ₺'`).
/// [amount] hero tutar — `formatCurrency` ile tabular basılır.
/// [railColor] tick'li ray rengi; varsayılan altın. Müşteri hero'larında
///   semantik (borç → `danger`, alacak/sıfır → `success`) geçilir.
/// [trailing] panelin sağında opsiyonel ikincil okuma (Kasa işletme giderleri).
/// [trailingTight] `trailing` yerleşim kipi (§6.7(h)/1):
///   • `false` (VARSAYILAN, mevcut davranış BİREBİR korunur): trailing
///     `Expanded(flex: 2)` alır → hero ile 3:2 bölüşülür. Kasa'nın **geniş metin
///     okuması** gibi kendi başına satır kaplayan içerikler için doğrudur.
///   • `true` (kompakt): trailing `Expanded` ALMAZ, **intrinsic** genişlikte durur;
///     kalan tüm genişlik hero tutarına kalır. Satış ekranının 40×40'lık ikon
///     butonu gibi küçük kontroller için — aksi hâlde hero genişliğinin ~%40'ı
///     boşa gider ve tutar `FittedBox` ile gereksizce küçülür (§4 imzası zayıflar).
class InstrumentHero extends StatelessWidget {
  final String label;
  final num amount;
  final Color railColor;
  final Widget? trailing;
  final bool trailingTight;

  const InstrumentHero({
    super.key,
    required this.label,
    required this.amount,
    this.railColor = AppColors.gold,
    this.trailing,
    this.trailingTight = false,
  });

  @override
  Widget build(BuildContext context) {
    final mobil = context.isMobile;
    return DecoratedBox(
      decoration: instrumentPanelDecoration(),
      child: Stack(
        children: [
          // İçerik — Stack'in konumsuz (non-positioned) çocuğu paneli boyutlandırır.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space20,
              vertical: AppSizes.space20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mikro-etiket (§6.3): uppercase enstrüman okuma etiketi,
                // panel.muted (textMuted) soğuk çelik ton.
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSizes.space20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Hero tutar + tick'li ray — kalan genişliği kaplar,
                    // taşarsa FittedBox ile küçülür (asla overflow yok).
                    // trailing yokken tek çocuk → tüm genişlik hero'nundur;
                    // varken 3:2 bölünür (her iki taraf da bounded → FittedBox
                    // güvenle küçülür, overflow yok). `trailingTight` ile trailing
                    // esnek olmaktan çıkar → tek esnek çocuk hero kalır, kalan
                    // genişliğin tamamını alır (flex değeri o kipte etkisizdir).
                    Expanded(
                      flex: 3,
                      child: _HeroReading(
                        amount: amount,
                        railColor: railColor,
                        mobil: mobil,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSizes.space16),
                      // Kompakt kip: Row, esnek olmayan çocuğu ana eksende
                      // sınırsız ölçer → trailing kendi doğal (intrinsic)
                      // genişliğini alır; taşma riski yok çünkü hero tarafı
                      // Expanded + FittedBox(scaleDown) ile küçülebilir.
                      if (trailingTight) trailing! else Expanded(flex: 2, child: trailing!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // ── Reticle köşeler (§6.3) — Positioned DAİMA Stack'in DOĞRUDAN çocuğu.
          const Positioned(
            top: 10,
            left: 10,
            child: IgnorePointer(
              child: _ReticleCorner(kose: Alignment.topLeft, renk: _kReticleRenk),
            ),
          ),
          const Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: _ReticleCorner(kose: Alignment.topRight, renk: _kReticleRenk),
            ),
          ),
          const Positioned(
            bottom: 10,
            left: 10,
            child: IgnorePointer(
              child: _ReticleCorner(kose: Alignment.bottomLeft, renk: _kReticleRenk),
            ),
          ),
          const Positioned(
            bottom: 10,
            right: 10,
            child: IgnorePointer(
              child: _ReticleCorner(kose: Alignment.bottomRight, renk: _kReticleRenk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero tutar + altında tick'li ray. Ray genişliği tutarın ~%40'ı (§6.3);
/// tümü FittedBox(scaleDown) içinde → dar genişlikte kırpılmadan küçülür.
class _HeroReading extends StatelessWidget {
  final num amount;
  final Color railColor;
  final bool mobil;

  const _HeroReading({
    required this.amount,
    required this.railColor,
    required this.mobil,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Column(
          // stretch: ray + %40 kesir, üstündeki tutarın TAM genişliğine göre
          // ölçülür (IntrinsicWidth = tutar genişliği).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(amount),
              maxLines: 1,
              style: TextStyle(
                fontSize: mobil ? 30 : 38,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
                color: Colors.white, // panel.ink
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [
                  // Ray rengine bağlı yumuşak parıltı (statik) — enstrüman his.
                  Shadow(
                    color: railColor.withValues(alpha: 0.22),
                    blurRadius: 26,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space6),
            // Ray = tutarın ~%40'ı (§4/§6.3).
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.4,
              child: _TickRail(color: railColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tick'li okuma cetveli (§6.3) — STATİK. Dashboard `_AnimatedRail`'in
/// `reduceMotion` (animasyon kapalı) dalıyla aynı görsel: renk → açık tonu →
/// beyaz → şeffaf gradyan + yumuşak parıltı gölgesi + 4 minik dikey tick.
/// Yeni controller/shimmer YOK.
///
/// ⚠️ Tick'ler `CustomPaint` ile çizilir (Dashboard'daki `LayoutBuilder + Stack`
/// yerine): bu ray `_HeroReading`'te `IntrinsicWidth` altında yaşar; `LayoutBuilder`
/// intrinsic ölçümü desteklemez ("does not support returning intrinsic dimensions")
/// ve çökertirdi. `CustomPaint` intrinsic genişliği 0 bildirir → güvenli; tutar
/// genişliği IntrinsicWidth'i belirler, ray 4px SABİT yükseklikte kalır
/// (sonsuz-yükseklik tuzağı yok).
class _TickRail extends StatelessWidget {
  final Color color;

  const _TickRail({required this.color});

  /// Rayın orta (açık) durağı. Altın için goldLight (Dashboard'la birebir eşleşme);
  /// semantik renkler için beyaza doğru harmanlanmış açık ton. Yeni marka hex'i
  /// değil — gradyanın "açık tonu" durağı (§6.3 "ray rengi → açık tonu → şeffaf").
  Color get _orta => color == AppColors.gold
      ? AppColors.goldLight
      : Color.lerp(color, Colors.white, 0.5)!;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: CustomPaint(
        // Tick'ler gradyanın üstüne çizilir (foreground).
        foregroundPainter: const _TickPainter(),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, _orta, Colors.white, Colors.transparent],
              stops: const [0.0, 0.48, 0.72, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.75),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ray boyunca minik dikey çentikler ("okuma cetveli" tick'leri, §6.3). Ray
/// gradyanı sağa soluklaştığı için soldaki tick'ler daha belirgin okunur
/// (kasıtlı — ölçek başı solda). Dashboard ile aynı kesirler + renk.
class _TickPainter extends CustomPainter {
  const _TickPainter();

  static const _tickKesirleri = [0.12, 0.30, 0.48, 0.66];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8C081226) // primaryDeep ~%55
      ..strokeWidth = 1.5;
    for (final f in _tickKesirleri) {
      final x = size.width * f;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => false;
}

/// L-şekilli köşe nişangâhı — "enstrüman göstergesi çerçevesi" hissi (§6.3).
/// Dashboard `_ReticleCorner` ile birebir aynı (kol 12px, kalınlık 1.5px).
class _ReticleCorner extends StatelessWidget {
  final Alignment kose;
  final Color renk;

  const _ReticleCorner({required this.kose, required this.renk});

  static const double _kol = 12;
  static const double _kalinlik = 1.5;

  @override
  Widget build(BuildContext context) {
    final ust = kose.y < 0;
    final sol = kose.x < 0;
    final kenar = BorderSide(color: renk, width: _kalinlik);
    return SizedBox(
      width: _kol,
      height: _kol,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: ust ? kenar : BorderSide.none,
            bottom: ust ? BorderSide.none : kenar,
            left: sol ? kenar : BorderSide.none,
            right: sol ? BorderSide.none : kenar,
          ),
        ),
      ),
    );
  }
}
