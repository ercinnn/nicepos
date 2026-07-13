import 'package:web/web.dart' as web;

/// İmzalı URL'yi yeni tarayıcı sekmesinde açar (web). Aç/İndir ve tarayıcı PDF
/// yazdırma için kullanılır.
void openUrlInNewTab(String url) {
  web.window.open(url, '_blank');
}
