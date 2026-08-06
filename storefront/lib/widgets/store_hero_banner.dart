import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

// Anasayfa hero şeridi — NicePOS'un ana uygulamasındaki imza öğesi olan
// "altın ray" motifinin (bkz. design-tokens.md §4/§6.3) sıcak, perakende-
// uygun bir yorumu: koyu lacivert zemin + ince tikli altın çizgi. Ana
// uygulamadaki gibi ışıltı/animasyon YOK — burada sakin bir marka imzası,
// ürün grid'inin önüne geçmemesi için tek satır başlık + tek satır alt yazı
// ile kısa tutulur.
class StoreHeroBanner extends StatelessWidget {
  const StoreHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [StoreColors.navy, StoreColors.navyDeep],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NICEPOS ONLINE MAĞAZA',
                style: GoogleFonts.inter(
                  color: StoreColors.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'İhtiyacınız olan ürünler,\ntek ekranda.',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(width: 220, child: _TickRail()),
              const SizedBox(height: 14),
              Text(
                'Ürünleri inceleyin, sepete ekleyin, sipariş kodunuzla takip edin.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// İnce, tikli altın ray — ana uygulamanın hero imzasının küçük bir yansıması.
class _TickRail extends StatelessWidget {
  const _TickRail();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 6,
      child: CustomPaint(painter: _TickRailPainter()),
    );
  }
}

class _TickRailPainter extends CustomPainter {
  const _TickRailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = StoreColors.gold
      ..strokeWidth = 1.4;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);

    const tickCount = 8;
    final tickPaint = Paint()
      ..color = StoreColors.gold
      ..strokeWidth = 1.4;
    for (var i = 0; i <= tickCount; i++) {
      final x = size.width * (i / tickCount);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
