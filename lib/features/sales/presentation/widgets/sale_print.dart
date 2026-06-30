// Satış sepetini A4 dikey olarak yazdırma — platforma göre koşullu import.
// Web'de gerçek yazdırma penceresi açılır; diğer platformlarda no-op (buton
// zaten yalnızca web'de gösterilir).
export 'sale_print_stub.dart'
    if (dart.library.js_interop) 'sale_print_web.dart';
