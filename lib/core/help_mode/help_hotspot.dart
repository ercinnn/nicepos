import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'help_mode_provider.dart';

// ─── HelpHotspot (KARAR) ────────────────────────────────────────────────────
// Herhangi bir widget'ı sarıp Yardım Modu'na (`helpModeProvider`) bağlayan
// GENEL bileşen — ekrana özel değil, `lib/core/`'da yaşar (satıştan sonra
// diğer ekranlara da aynı şekilde uygulanacak).
//
// Yardım Modu KAPALIYKEN tamamen şeffaftır (`child` doğrudan döner, hiçbir
// gesture/overlay maliyeti yok). AÇIKKEN dokunma `AbsorbPointer` ile alttaki
// widget'a ULAŞMAZ (satışı tamamlama/silme gibi normal aksiyonlar kazara
// TETİKLENMEZ — kullanıcı kararı, "keşif güvenli" olmalı) — bunun yerine
// dokunulan noktanın yakınında kısa bir açıklama balonu açılır.
//
// Konumlandırma `CompositedTransformFollower`/`LayerLink` YERİNE ham
// `Overlay.insert` + tıklama noktasının global konumu kullanır (ekran
// kaydırılırken balonun takip etmesi gerekmiyor — kısa ömürlü, tek dokunuşluk
// bir ipucu) → ekran kenarına yakın hedeflerde taşmayı `MediaQuery` ile
// clamp'leyen basit bir hesap yeterli.
class HelpHotspot extends ConsumerWidget {
  final String title;
  final String text;
  final Widget child;

  const HelpHotspot({
    super.key,
    required this.title,
    required this.text,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(helpModeProvider);
    if (!active) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _showHelpBubble(context, details.globalPosition, title: title, text: text),
      child: AbsorbPointer(child: child),
    );
  }
}

void _showHelpBubble(
  BuildContext context,
  Offset anchor, {
  required String title,
  required String text,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  // Barrier'ın onTap'i ve kartın kapatma ikonu AYNI entry'yi kaldırabilir —
  // bazı giriş kaynaklarında (ör. otomasyon/çift pointer event) ikisi neredeyse
  // eşzamanlı tetiklenebiliyor. `OverlayEntry.remove()` ikinci çağrıda assert
  // fırlattığından (yaşanmış hata: "should be removed only once") kapatma tek
  // seferlik bir bayrakla korunur.
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    // Bazı giriş kaynaklarında (ör. sentetik/çift pointer event) barrier'ın
    // onTap'i ve kartın kapatma ikonu neredeyse eşzamanlı tetiklenip
    // `remove()`'a aynı frame'de iki kez girebiliyor — yukarıdaki bayrak
    // mantıksal olarak engeller, ancak framework'ün kendi assert'i (yalnız
    // debug/profile build'de aktif, release'te elenir) yine de araya girerse
    // konsolu kirletmesin diye try/catch ikinci bir güvenlik ağı.
    try {
      entry.remove();
    } catch (_) {}
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final size = MediaQuery.sizeOf(overlayContext);
      const bubbleWidth = 288.0;
      const margin = 12.0;

      var left = anchor.dx - bubbleWidth / 2;
      left = left.clamp(margin, (size.width - bubbleWidth - margin).clamp(margin, size.width));

      final showAbove = anchor.dy > size.height * 0.6;

      return Stack(
        children: [
          // Balonun dışına dokununca kapat.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: showAbove ? null : (anchor.dy + 16).clamp(margin, size.height - margin),
            bottom: showAbove ? (size.height - anchor.dy + 16).clamp(margin, size.height - margin) : null,
            width: bubbleWidth,
            child: _HelpBubbleCard(title: title, text: text, onClose: close),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

class _HelpBubbleCard extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onClose;

  const _HelpBubbleCard({required this.title, required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.info, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 16, color: AppColors.info),
                const SizedBox(width: AppSizes.space6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
