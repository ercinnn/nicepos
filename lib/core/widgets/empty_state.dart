import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Yeniden kullanılabilir boş-durum (empty state) bileşeni.
///
/// İkon (altın daire içinde) + başlık + opsiyonel açıklama + opsiyonel eylem.
/// Liste/sepet/sonuç boş olduğunda ham metin yerine kullanılır.
///
/// Örnek:
/// ```dart
/// EmptyState(
///   icon: Icons.people_outline,
///   title: 'Müşteri yok',
///   message: 'İlk müşteriyi ekleyerek başlayın.',
///   action: FilledButton(onPressed: ..., child: const Text('Müşteri Ekle')),
/// );
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.goldBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldSubtle),
              ),
              child: Icon(icon, size: 34, color: AppColors.gold),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
