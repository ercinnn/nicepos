import 'dart:typed_data';

import 'positioned_text.dart';

/// pdf.js'in bir sayfayı hem görüntüye render edip hem konumlu metnini
/// çıkardığı `nicePdfRenderAndExtract` çağrısının sonucu.
class RenderedPage {
  final Uint8List imageBytes;
  final double width;
  final double height;
  final List<PositionedText> textItems;

  const RenderedPage({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.textItems,
  });

  /// Toplam metin karakteri küçük bir eşiğin altındaysa sayfa "taranmış"
  /// (metin katmanı yok) kabul edilir → OCR yedek yoluna düşülmeli.
  bool get hasUsableTextLayer =>
      textItems.fold<int>(0, (sum, t) => sum + t.text.trim().length) >= 15;
}
