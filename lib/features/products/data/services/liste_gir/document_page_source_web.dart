import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../models/liste_gir/pdf_document_handle.dart';
import '../../models/liste_gir/positioned_text.dart';
import '../../models/liste_gir/rendered_page.dart';
import 'pdfjs_interop.dart' as bridge;

// `web/vendor/pdfjs/pdfjs_bridge.js`'i (pdf.js sarmalayıcı) tembel olarak
// enjekte eder — Liste Gir ekranı ilk açıldığında, her uygulama açılışında
// değil. Birden fazla eşzamanlı çağrı aynı Future'ı paylaşır.
Completer<void>? _bridgeLoading;

Future<void> _ensureBridgeLoaded() {
  final existing = _bridgeLoading;
  if (existing != null) return existing.future;

  final completer = Completer<void>();
  _bridgeLoading = completer;

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..type = 'module'
    ..src = 'vendor/pdfjs/pdfjs_bridge.js';
  script.addEventListener(
    'load',
    ((web.Event _) => completer.complete()).toJS,
  );
  script.addEventListener(
    'error',
    ((web.Event _) =>
            completer.completeError(Exception('pdfjs_bridge.js yüklenemedi')))
        .toJS,
  );
  web.document.head!.appendChild(script);
  return completer.future;
}

Future<PdfDocumentHandle> loadPdfDocument(Uint8List bytes) async {
  await _ensureBridgeLoaded();
  final resultJson = (await bridge.nicePdfLoad(bytes.toJS).toDart).toDart;
  final map = jsonDecode(resultJson) as Map<String, dynamic>;
  return PdfDocumentHandle.fromMap(map);
}

Future<RenderedPage> renderPdfPage({
  required String docId,
  required int pageNum,
  required double targetWidthPx,
}) async {
  await _ensureBridgeLoaded();
  final resultJson = (await bridge
          .nicePdfRenderAndExtract(docId.toJS, pageNum.toJS, targetWidthPx.toJS)
          .toDart)
      .toDart;
  final map = jsonDecode(resultJson) as Map<String, dynamic>;
  return _renderedPageFromMap(map, textKey: 'textItems');
}

void closePdfDocument(String docId) {
  bridge.nicePdfClose(docId.toJS);
}

Future<List<PositionedText>> ocrRecognize({
  required Uint8List imageBytes,
  String lang = 'tur',
}) async {
  await _ensureBridgeLoaded();
  final dataUrl = _toImageDataUrl(imageBytes);
  final resultJson =
      (await bridge.niceOcrRecognize(dataUrl.toJS, lang.toJS).toDart).toDart;
  final map = jsonDecode(resultJson) as Map<String, dynamic>;
  final words = (map['words'] as List? ?? [])
      .map((w) => PositionedText.fromMap(Map<String, dynamic>.from(w as Map)))
      .toList();
  return words;
}

RenderedPage _renderedPageFromMap(Map<String, dynamic> map, {required String textKey}) {
  final dataUrl = map['imageDataUrl'] as String;
  final base64Part = dataUrl.substring(dataUrl.indexOf(',') + 1);
  final imageBytes = base64Decode(base64Part);
  final items = (map[textKey] as List? ?? [])
      .map((t) => PositionedText.fromMap(Map<String, dynamic>.from(t as Map)))
      .toList();
  return RenderedPage(
    imageBytes: imageBytes,
    width: (map['width'] as num).toDouble(),
    height: (map['height'] as num).toDouble(),
    textItems: items,
  );
}

String _toImageDataUrl(Uint8List bytes) {
  final isPng = bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final mime = isPng ? 'image/png' : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
