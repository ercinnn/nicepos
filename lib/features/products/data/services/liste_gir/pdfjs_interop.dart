import 'dart:js_interop';

/// `web/vendor/pdfjs/pdfjs_bridge.js`'e (birinci parti köprü script) ham
/// JS-interop externs. Tüm dönüşler JSON string — Dart tarafı `jsonDecode`
/// yapar, JS nesne grafiği interop'una girilmez (bkz. plan notu).
@JS('nicePdfLoad')
external JSPromise<JSString> nicePdfLoad(JSUint8Array bytes);

@JS('nicePdfRenderAndExtract')
external JSPromise<JSString> nicePdfRenderAndExtract(
  JSString docId,
  JSNumber pageNum,
  JSNumber targetWidthPx,
);

@JS('nicePdfClose')
external void nicePdfClose(JSString docId);

@JS('niceOcrRecognize')
external JSPromise<JSString> niceOcrRecognize(JSString imageDataUrl, JSString lang);
