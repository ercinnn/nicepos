import 'package:flutter/material.dart';

import '../core/theme.dart';

// Boş durum örüntüsü — design-tokens.md §11 (kanonik referans: sepetin
// mevcut boş durumu). İkon + mesaj + opsiyonel ikincil/outline CTA (§6).
class StoreEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const StoreEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: StoreColors.textMuted),
            const SizedBox(height: 12), // space.md
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: StoreColors.textMuted),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16), // space.lg
              OutlinedButton(
                onPressed: onCta,
                style: OutlinedButton.styleFrom(
                  foregroundColor: StoreColors.navy,
                  side: const BorderSide(color: StoreColors.navy, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, // space.xl
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  overlayColor: StoreColors.navy.withValues(alpha: 0.04),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
