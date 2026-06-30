import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Yükleme durumları için shimmer'lı iskelet (skeleton) kutusu.
///
/// Kendi içinde animasyonludur — bir gradyan, kutu üzerinde soldan sağa süpürür.
/// Boş spinner yerine içeriğin yerini tutan gri bloklar göstererek daha
/// premium bir yükleme hissi verir.
///
/// Örnek:
/// ```dart
/// const Skeleton(width: 120, height: 16);
/// const Skeleton(height: 40, radius: 12); // tam genişlik
/// ```
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.margin,
  });

  /// Dairesel iskelet (avatar / ikon yer tutucu).
  const Skeleton.circle({super.key, double size = 40, this.margin})
      : width = size,
        height = size,
        radius = 999;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _base = Color(0xFFEFE9DA);      // açık altın-gri taban
  static const _highlight = Color(0xFFFBF7EC);  // parlak vurgu

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0..1
        // Süpürme: gradyan hizasını -1.5 → 1.5 aralığında kaydır.
        final dx = -1.5 + t * 3.0;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: const [_base, _highlight, _base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// İskelet bloklarını dikey hizalamak için yardımcı satır boşluğu.
class SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Skeleton(height: height),
    );
  }
}

/// Liste yükleme yer tutucusu — birkaç iskelet satır kartı.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 56,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Row(
        children: [
          const Skeleton.circle(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SkeletonLine(widthFactor: 0.6, height: 13),
                SizedBox(height: 6),
                SkeletonLine(widthFactor: 0.35, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Skeleton(width: 64, height: 16, radius: 6, margin: EdgeInsets.zero),
        ],
      ),
    );
  }
}

/// Marka rengiyle tutarlı, daha "premium" bir dairesel yükleme göstergesi
/// (boş Material spinner yerine).
class BrandLoader extends StatelessWidget {
  final double size;
  final String? label;

  const BrandLoader({super.key, this.size = 28, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.gold,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(
              label!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
