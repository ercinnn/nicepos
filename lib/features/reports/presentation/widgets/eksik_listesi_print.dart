// Eksik Listesi'ni A4 dikey olarak yazdırma — platforma göre koşullu import.
// `sale_print.dart`'ın BİREBİR kopyası: web'de gerçek yazdırma penceresi
// açılır; diğer platformlarda no-op (buton zaten yalnızca web'de gösterilir).
export 'eksik_listesi_print_stub.dart'
    if (dart.library.js_interop) 'eksik_listesi_print_web.dart';
