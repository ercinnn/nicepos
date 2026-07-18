/// pdf.js metin öğesi VEYA Tesseract OCR kelimesi için ortak, kaynak-bağımsız
/// şekil — render edilen sayfa görüntüsüyle aynı piksel koordinat uzayında.
class PositionedText {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;

  const PositionedText({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  factory PositionedText.fromMap(Map<String, dynamic> map) {
    return PositionedText(
      text: map['text'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
    );
  }
}
