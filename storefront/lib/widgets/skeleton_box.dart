import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';

// Skeleton / shimmer yükleme durumu — design-tokens.md §5. Renk navy-alfa
// (ALTIN DEĞİL) — "yükleniyor" durumu hero/hover'ın imza rengiyle asla
// karışmaz (altın ekonomisi korunur).

/// Tek bir sweep altında bir veya birden çok [SkeletonBox] barındıran
/// shimmer sarmalayıcısı. Birden çok kutu aynı `Shimmer.fromColors` içinde
/// olursa sweep tüm kutularda senkron akar.
class StoreShimmer extends StatelessWidget {
  final Widget child;

  const StoreShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: StoreColors.navy.withValues(alpha: 0.06),
      highlightColor: StoreColors.navy.withValues(alpha: 0.12),
      child: child,
    );
  }
}

/// Tek bir düz skeleton dikdörtgeni/pili. Kendi başına kullanılacaksa bir
/// [StoreShimmer] ile sarılmalıdır — bileşik placeholder'lar (aşağıdaki
/// [SkeletonProductCard]/[SkeletonListRow]/[SkeletonImage]) bunu zaten yapar.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // width verilmezse varsayılan tam genişlik (double.infinity) — bounded
      // bir ata (grid hücresi/Expanded/sabit genişlikli kapsayıcı) olduğu
      // sürece güvenli; her çağrı yerinde ayrı ayrı genişlik zorunlu kılmak
      // yerine sıfır-genişliğe çökme riskini kaynağında kapatır.
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: StoreColors.navy.withValues(alpha: 0.06),
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Ürün kartı placeholder — `product_card.dart` ile birebir aynı köşe
/// yarıçapı (10): üstte görsel bloğu, altta iki metin bar (isim 2 satır,
/// fiyat 1 satır).
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: StoreColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: StoreColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: SkeletonBox(borderRadius: BorderRadius.zero),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 11),
                  SizedBox(height: 4),
                  SkeletonBox(height: 11, width: 90),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SkeletonBox(height: 14, width: 64),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satır placeholder — sepet satırı / sipariş özeti kalemi ile aynı 56×56
/// görsel kare + yanında iki metin bar.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreShimmer(
      child: Row(
        children: [
          const SkeletonBox(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 12),
                SizedBox(height: 6),
                SkeletonBox(height: 11, width: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tam genişlik görsel placeholder — ürün detay ana görseli (kare/4:3).
class SkeletonImage extends StatelessWidget {
  final double aspectRatio;
  final BorderRadius borderRadius;

  const SkeletonImage({
    super.key,
    this.aspectRatio = 1,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: StoreShimmer(child: SkeletonBox(borderRadius: borderRadius)),
    );
  }
}

/// Kategori chip placeholder — `_CategoryChip`'in (§7) stadium şekliyle aynı
/// yükseklik hissini verir, kategori listesi yüklenirken gösterilir.
class SkeletonChipRow extends StatelessWidget {
  final int count;

  const SkeletonChipRow({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return StoreShimmer(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          count,
          (i) => SkeletonBox(
            width: (64 + (i % 3) * 18).toDouble(),
            height: 30,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
