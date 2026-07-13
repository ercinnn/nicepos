// İmzalı PDF URL'sini yeni sekmede açma — platforma göre koşullu import
// (etiket_print.dart conditional-export deseninin birebir kopyası). Web'de
// yeni tarayıcı sekmesi açar (aç/indir + tarayıcı PDF yazdırma); native'de
// no-op (native tarafta url_launcher/Printing kullanılır — bkz. labels_screen).
export 'label_open_stub.dart'
    if (dart.library.js_interop) 'label_open_web.dart';
