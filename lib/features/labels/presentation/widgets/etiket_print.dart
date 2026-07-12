// Raf etiketlerini A4 (3×8 = 24 etiket) olarak yazdırma — platforma göre koşullu
// import (satış sepeti yazdırma `sale_print.dart` deseninin birebir uyarlaması).
// Web'de gerçek yazdırma penceresi açılır; diğer platformlarda no-op (buton zaten
// yalnızca web'de gösterilir).
export 'etiket_print_stub.dart'
    if (dart.library.js_interop) 'etiket_print_web.dart';
