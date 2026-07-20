import 'package:flutter_tts/flutter_tts.dart';

import 'english_number_words.dart';

/// Uygulama genelinde TEK bir FlutterTts örneği paylaşılır (paket dokümantasyonunun
/// önerdiği kullanım şekli — her çağrıda yeni örnek oluşturmak gerekmez).
final FlutterTts _tts = FlutterTts();
bool _voiceReady = false;

/// Web Speech API'de `getVoices()` ASENKRON yüklenir — ilk çağrıda genelde BOŞ
/// liste döner (tarayıcının `voiceschanged` olayı henüz ateşlenmemiştir). Kısa
/// aralıklarla birkaç kez tekrar denenir; aksi halde hiç İngilizce ses
/// bulunamadığı sanılıp yanlışlıkla sistem varsayılanına (ör. Türkçe ses) düşülür
/// — "İngilizce metni Türkçe aksanla okuma" şikâyetinin kök nedeni budur.
Future<List<Map<String, dynamic>>> _loadVoicesWithRetry() async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    } catch (_) {
      return const [];
    }
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return const [];
}

bool _isFemale(Map<String, dynamic> v) {
  final gender = v['gender']?.toString().toLowerCase() ?? '';
  final name = v['name']?.toString().toLowerCase() ?? '';
  // "female" alt-dizesi "male"yi İÇERİR — female kontrolü male'den ÖNCE yapılmalı,
  // aksi halde "Google UK English Female" yanlışlıkla erkek ses sanılır.
  return gender == 'female' || name.contains('female');
}

bool _isMale(Map<String, dynamic> v) {
  if (_isFemale(v)) return false;
  final gender = v['gender']?.toString().toLowerCase() ?? '';
  final name = v['name']?.toString().toLowerCase() ?? '';
  return gender == 'male' || name.contains('male');
}

bool _isBritish(Map<String, dynamic> v) {
  final locale = v['locale']?.toString().toLowerCase() ?? '';
  return locale.contains('en-gb') || locale.contains('en_gb');
}

bool _isEnglish(Map<String, dynamic> v) {
  final locale = v['locale']?.toString().toLowerCase() ?? '';
  return locale.startsWith('en');
}

Map<String, dynamic>? _firstMatch(
  List<Map<String, dynamic>> voices,
  bool Function(Map<String, dynamic>) test,
) {
  for (final v in voices) {
    if (test(v)) return v;
  }
  return null;
}

/// İngilizce (tercihen İngiliz + erkek) bir ses bulmaya çalışır. Öncelik sırası:
/// en-GB erkek → en-GB (herhangi cinsiyet) → İngilizce erkek (herhangi bölge)
/// → İngilizce (herhangi). Hiç İngilizce ses yoksa yalnızca dil kodu 'en-GB'
/// bırakılır (motor kendi varsayılanını kullanır — nadir/beklenmeyen durum).
///
/// Ses listesi boş dönerse (ör. tarayıcı henüz yüklemediyse) `_voiceReady`
/// SET EDİLMEZ — bir sonraki "sesli oku" tıklamasında yeniden denenir; kalıcı
/// olarak yanlış/varsayılan sesle takılı kalınmaz.
Future<void> _ensureVoice() async {
  if (_voiceReady) return;
  await _tts.setPitch(0.85);
  // Kullanıcı geri bildirimi: önceki hız (0.45) çok yavaştı — 2 katına çıkarıldı.
  await _tts.setSpeechRate(0.9);
  await _tts.setLanguage('en-GB');

  final voices = await _loadVoicesWithRetry();
  if (voices.isEmpty) return;

  final chosen = _firstMatch(voices, (v) => _isBritish(v) && _isMale(v)) ??
      _firstMatch(voices, _isBritish) ??
      _firstMatch(voices, (v) => _isEnglish(v) && _isMale(v)) ??
      _firstMatch(voices, _isEnglish);

  if (chosen != null) {
    await _tts.setVoice({
      'name': chosen['name'].toString(),
      'locale': chosen['locale'].toString(),
    });
  }
  _voiceReady = true;
}

/// Verilen TL tutarını İngilizce olarak sesli okur (ör. 20 → "twenty turkish lira").
/// Ardışık çağrılarda önceki seslendirme kesilip yenisi başlar (üst üste binmez).
Future<void> speakAmountInEnglish(num amount) async {
  await _ensureVoice();
  await _tts.stop();
  await _tts.speak(amountToEnglishWords(amount));
}
