import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

// Yasal/iletişim sayfaları (KVKK, Mesafeli Satış Sözleşmesi, gerçek iletişim
// bilgileri) henüz yok — bu ayrı bir sonraki aşama (bkz. sohbet geçmişi:
// "önce görsel cila"). Burada gerçek olmayan iletişim bilgisi UYDURULMAZ,
// yalnız marka + hızlı bağlantılar + telif hakkı satırı gösterilir.
class StoreFooter extends StatelessWidget {
  const StoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: StoreColors.navyDeep,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 480;
                  final brand = _BrandBlock();
                  final links = _LinksBlock();
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [brand, const SizedBox(height: 24), links],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: brand),
                      Expanded(child: links),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 16),
              Text(
                '© ${DateTime.now().year} NicePOS — Tüm hakları saklıdır.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.storefront_outlined,
              color: StoreColors.goldLight,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'NicePOS',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 280,
          child: Text(
            'Ürün kataloğumuzu inceleyin, sepetinize ekleyin, sipariş kodunuzla takip edin.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinksBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final linkStyle = GoogleFonts.inter(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 13,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HIZLI BAĞLANTILAR',
          style: GoogleFonts.inter(
            color: StoreColors.goldLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.go('/'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Anasayfa', style: linkStyle),
          ),
        ),
        InkWell(
          onTap: () => context.go('/sepet'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Sepetim', style: linkStyle),
          ),
        ),
      ],
    );
  }
}
