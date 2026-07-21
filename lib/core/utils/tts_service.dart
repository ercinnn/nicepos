import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'english_number_words.dart';

/// Uygulama genelinde TEK bir FlutterTts örneği paylaşılır (paket dokümantasyonunun
/// önerdiği kullanım şekli — her çağrıda yeni örnek oluşturmak gerekmez).
final FlutterTts _tts = FlutterTts();
bool _voiceReady = false;
bool _basicsApplied = false;

/// Web Speech API'de `getVoices()` ASENKRON yüklenir — ilk çağrıda genelde BOŞ
/// liste döner (tarayıcının `voiceschanged` olayı henüz ateşlenmemiştir). Kısa
/// aralıklarla birkaç kez tekrar denenir.
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
  // "female" alt-dizesi "male"yi İÇERİR — female kontrolü male'den ÖNCE yapılmalı.
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

/// Perde/hız/dil ayarlarını uygular. `setLanguage('en-GB')` BİLEREK burada,
/// ses seçiminden BAĞIMSIZ kalır — bilinen-çalışan İLK sürümle aynı davranış:
/// dil ayarı tek başına motoru SUSTURMAZ, eşleşen bir ses bulunamazsa motor
/// kendi varsayılan sesine düşer (yanlış aksanla da olsa SES ÇIKAR).
Future<void> _applyBasics() async {
  if (_basicsApplied) return;
  _basicsApplied = true;
  try {
    await _tts.setPitch(0.85);
  } catch (e) {
    debugPrint('[TTS] setPitch HATA: $e');
  }
  try {
    await _tts.setSpeechRate(0.9);
  } catch (e) {
    debugPrint('[TTS] setSpeechRate HATA: $e');
  }
  try {
    await _tts.setLanguage('en-GB');
  } catch (e) {
    debugPrint('[TTS] setLanguage HATA: $e');
  }
}

/// En iyi İngilizce (tercihen İngiliz + erkek) sesi arar ve BULURSA `setVoice`
/// ile atar. Bulamazsa veya `setVoice` hata verirse SESSİZCE vazgeçilir — engine
/// zaten `_applyBasics`'te ayarlanan dil/varsayılanla okumaya devam eder.
Future<void> _resolveVoice() async {
  if (_voiceReady) return;
  try {
    final voices = await _loadVoicesWithRetry();
    debugPrint('[TTS] bulunan toplam ses sayisi: ${voices.length}');
    if (voices.isEmpty) return;

    final chosen = _firstMatch(voices, (v) => _isBritish(v) && _isMale(v)) ??
        _firstMatch(voices, _isBritish) ??
        _firstMatch(voices, (v) => _isEnglish(v) && _isMale(v)) ??
        _firstMatch(voices, _isEnglish);
    debugPrint('[TTS] secilen ses: ${chosen?['name']} / locale=${chosen?['locale']}');

    if (chosen != null) {
      await _tts.setVoice({
        'name': chosen['name'].toString(),
        'locale': chosen['locale'].toString(),
      });
      debugPrint('[TTS] setVoice tamam');
    }
  } catch (e) {
    debugPrint('[TTS] resolveVoice HATA: $e');
  } finally {
    _voiceReady = true;
  }
}

/// Sesi ÖNCEDEN ısıtır — "sesli oku" butonunu içeren widget ilk oluşturulduğunda
/// (`initState`) çağrılması ÖNERİLİR (tıklama anında ayrıca beklenmesin diye bir
/// optimizasyon) ama artık KRİTİK bir gereklilik değil — `speakAmountInEnglish`
/// zaten kendi içinde bu adımları (tamamlanmadıysa) bekler.
Future<void> warmupTts() async {
  await _applyBasics();
  await _resolveVoice();
}

/// Verilen TL tutarını İngilizce olarak sesli okur (ör. 20 → "twenty turkish lira").
/// Her hazırlık adımı AYRI AYRI try/catch korumalı — hiçbiri `_tts.speak()`
/// çağrısına ulaşılmasını ENGELLEYEMEZ (önceki bug'ların kök nedeni: bir hazırlık
/// adımındaki yakalanmamış hata `speak()`'e hiç ulaşılamamasına yol açıyordu).
Future<void> speakAmountInEnglish(num amount) async {
  final text = amountToEnglishWords(amount);
  debugPrint('[TTS] speak baslatiliyor: "$text"');
  try {
    await _applyBasics();
  } catch (e) {
    debugPrint('[TTS] applyBasics disaridan HATA: $e');
  }
  try {
    await _resolveVoice();
  } catch (e) {
    debugPrint('[TTS] resolveVoice disaridan HATA: $e');
  }
  try {
    await _tts.stop();
    debugPrint('[TTS] stop tamam');
  } catch (e) {
    debugPrint('[TTS] stop HATA: $e');
  }
  try {
    final result = await _tts.speak(text);
    debugPrint('[TTS] speak() tamamlandi, donen deger: $result');
  } catch (e) {
    debugPrint('[TTS] speak HATA: $e');
  }
}
