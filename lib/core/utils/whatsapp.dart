import 'package:url_launcher/url_launcher.dart';

/// Türkiye cep numarasını wa.me'nin istediği uluslararası biçime (`905XXXXXXXXX`,
/// başında `+` YOK) çevirir. Boşluk/tire/parantez gibi ayraçlar yok sayılır.
/// Kabul edilen girişler: `05XX…` (11 hane), `5XX…` (10 hane), `905XX…` /
/// `+90 5XX…` / `0090 5XX…`. Geçersizse `null`.
String? normalizeTrPhone(String? raw) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 10 || !digits.startsWith('5')) return null;
  return '90$digits';
}

/// wa.me click-to-chat bağlantısı. Kişisel numaradan gönderim için resmi API
/// olmadığından (WhatsApp Business API ayrı işletme numarası ister) uygulama
/// WhatsApp'ı hazır mesajla AÇAR, "Gönder"e kullanıcı basar. `phone` null ise
/// WhatsApp alıcıyı kendisi seçtirir.
Uri whatsAppUri({String? phone, required String text}) {
  return Uri.parse('https://wa.me/${phone ?? ''}?text=${Uri.encodeComponent(text)}');
}

/// Bağlantıyı WhatsApp'ta açar — web'de yeni sekme (WhatsApp Web), native'de
/// WhatsApp uygulaması. Açılamazsa `false`.
Future<bool> openWhatsApp(Uri uri) async {
  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    return false;
  }
}
