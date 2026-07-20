import 'package:flutter_tts/flutter_tts.dart';

import 'english_number_words.dart';

/// Uygulama genelinde TEK bir FlutterTts örneği paylaşılır (paket dokümantasyonunun
/// önerdiği kullanım şekli — her çağrıda yeni örnek oluşturmak gerekmez).
final FlutterTts _tts = FlutterTts();
bool _voiceResolved = false;

/// Erkek sese en yakın İngiliz (en-GB) sesi BİR KEZ arar ve seçer — platformlar
/// arası kesin "erkek ses" garantisi YOKTUR (Web Speech API / Android TTS motoru
/// hangi seslerin yüklü olduğuna göre değişir); bulunamazsa varsayılan sesle
/// devam edilir, düşük pitch ile daha kalın/erkeksi bir ton hedeflenir.
Future<void> _ensureVoice() async {
  if (_voiceResolved) return;
  _voiceResolved = true;
  await _tts.setLanguage('en-GB');
  await _tts.setPitch(0.85);
  await _tts.setSpeechRate(0.45);
  try {
    final dynamic rawVoices = await _tts.getVoices;
    if (rawVoices is List) {
      for (final v in rawVoices) {
        if (v is! Map) continue;
        final locale = v['locale']?.toString().toLowerCase() ?? '';
        final name = v['name']?.toString().toLowerCase() ?? '';
        final gender = v['gender']?.toString().toLowerCase() ?? '';
        final looksMale = gender == 'male' || name.contains('male');
        final looksBritish = locale.contains('en-gb') || locale.contains('en_gb');
        if (looksBritish && looksMale) {
          await _tts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale'].toString(),
          });
          return;
        }
      }
    }
  } catch (_) {
    // Bazı platformlarda getVoices desteklenmez/hata verir — varsayılan sesle devam.
  }
}

/// Verilen TL tutarını İngilizce olarak sesli okur (ör. 20 → "twenty turkish lira").
/// Ardışık çağrılarda önceki seslendirme kesilip yenisi başlar (üst üste binmez).
Future<void> speakAmountInEnglish(num amount) async {
  await _ensureVoice();
  await _tts.stop();
  await _tts.speak(amountToEnglishWords(amount));
}
