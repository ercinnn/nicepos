// Nice POS — Liste Gir köprü script'i (birinci parti, pdf.js/Tesseract.js sarmalayıcı).
//
// Bu dosya vendor edilen pdf.js'i (pdf.min.mjs) sarar ve Dart tarafının
// dart:js_interop ile çağırabileceği düz `window.nicePdf*` fonksiyonları
// sunar. Tüm dönüş değerleri JSON.stringify edilmiş string'lerdir — Dart
// tarafında sadece jsonDecode() yapılır, JS nesne grafiği interop'una
// (dartify) hiç girilmez.
//
// <script type="module" src=".../pdfjs_bridge.js"> olarak yüklenmelidir
// (relative import kullanıyor).

import * as pdfjsLib from './pdf.min.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('./pdf.worker.min.mjs', import.meta.url).href;

const _docs = new Map();
let _nextDocId = 1;

window.nicePdfLoad = async function (bytes) {
  const doc = await pdfjsLib.getDocument({ data: bytes }).promise;
  const docId = String(_nextDocId++);
  _docs.set(docId, doc);
  return JSON.stringify({ docId, numPages: doc.numPages });
};

window.nicePdfRenderAndExtract = async function (docId, pageNum, targetWidthPx) {
  const doc = _docs.get(docId);
  if (!doc) throw new Error('Bilinmeyen docId: ' + docId);
  const page = await doc.getPage(pageNum);

  const baseViewport = page.getViewport({ scale: 1 });
  const scale = targetWidthPx / baseViewport.width;
  const viewport = page.getViewport({ scale });

  const canvas = document.createElement('canvas');
  canvas.width = Math.round(viewport.width);
  canvas.height = Math.round(viewport.height);
  const ctx = canvas.getContext('2d');
  await page.render({ canvasContext: ctx, viewport }).promise;
  const imageDataUrl = canvas.toDataURL('image/png');

  const textContent = await page.getTextContent();
  const textItems = [];
  for (const item of textContent.items) {
    if (!item.str || !item.str.trim()) continue;
    // item.transform: [a,b,c,d,e,f] — e,f pdf-uzayında sol-alt köşe; pdf.js
    // metin öğeleri için d genelde yaklaşık font yüksekliğidir.
    const t = pdfjsLib.Util.transform(viewport.transform, item.transform);
    const x = t[4];
    const yBottom = t[5];
    const height = Math.hypot(t[2], t[3]) || Math.abs(item.height * scale) || 10;
    const width = item.width * scale;
    textItems.push({
      text: item.str,
      x: x,
      y: yBottom - height, // üst-sol köşeye çevir (Flutter/ekran koordinatıyla tutarlı)
      width: width,
      height: height,
    });
  }

  return JSON.stringify({
    imageDataUrl,
    width: canvas.width,
    height: canvas.height,
    textItems,
  });
};

window.nicePdfClose = function (docId) {
  const doc = _docs.get(docId);
  if (doc) {
    doc.destroy();
    _docs.delete(docId);
  }
};

let _tesseractLoaded = null;
function _ensureTesseractLoaded() {
  if (_tesseractLoaded) return _tesseractLoaded;
  _tesseractLoaded = new Promise((resolve, reject) => {
    if (window.Tesseract) { resolve(); return; }
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Tesseract.js yüklenemedi'));
    document.head.appendChild(script);
  });
  return _tesseractLoaded;
}

window.niceOcrRecognize = async function (imageDataUrl, lang) {
  await _ensureTesseractLoaded();
  const result = await window.Tesseract.recognize(imageDataUrl, lang || 'tur');
  const data = result.data;
  const words = (data.words || []).map((w) => ({
    text: w.text,
    x: w.bbox.x0,
    y: w.bbox.y0,
    width: w.bbox.x1 - w.bbox.x0,
    height: w.bbox.y1 - w.bbox.y0,
  }));
  return JSON.stringify({ width: 0, height: 0, words });
};
