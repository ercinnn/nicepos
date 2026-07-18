import 'dart:typed_data';

import '../../models/liste_gir/pdf_document_handle.dart';
import '../../models/liste_gir/positioned_text.dart';
import '../../models/liste_gir/rendered_page.dart';

/// Liste Gir yalnız masaüstü/web'de gösterilir (`context.isDesktop` guard'ı,
/// `products_tabs_screen.dart`) — bu yol mobilde/native'de asla çağrılmamalı.
/// Sessiz no-op yerine gürültülü hata: bir şekilde tetiklenirse gerçek bir
/// hata olarak yüzeye çıksın, sessizce yutulmasın.
Never _unsupported() => throw UnsupportedError(
      'Liste Gir yalnız web platformunda desteklenir.',
    );

Future<PdfDocumentHandle> loadPdfDocument(Uint8List bytes) async => _unsupported();

Future<RenderedPage> renderPdfPage({
  required String docId,
  required int pageNum,
  required double targetWidthPx,
}) async =>
    _unsupported();

void closePdfDocument(String docId) => _unsupported();

Future<List<PositionedText>> ocrRecognize({
  required Uint8List imageBytes,
  String lang = 'tur',
}) async =>
    _unsupported();
