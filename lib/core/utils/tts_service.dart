import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'english_number_words.dart';

/// Uygulama genelinde TEK bir FlutterTts örneği paylaşılır (paket dokümantasyonunun
/// önerdiği kullanım şekli — her çağrıda yeni örnek oluşturmak gerekmez).
final FlutterTts _tts = FlutterTts();
bool _voiceReady = false;
bool _basicsApplied = false;
Future<void>? _warmupFuture;

/// Web Speech API'de `getVoices()` ASENKRON yüklenir — ilk çağrıda genelde BOŞ
/// liste döner (tarayıcının `voiceschanged` olayı henüz ateşlenmemiştir). Kısa
/// aralıklarla birkaç kez tekrar denenir; aksi halde hiç İngilizce ses
/// bulunamadığı sanılıp yanlışlıkla sistem varsayılanına (ör. Türkçe ses) düşülür.
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

/// Hızlı/yerel ayarlar (dil, perde, hız) — ağ/asenkron ses listesi beklemeden
/// hemen uygulanabilir, gecikme içermez. Her çağrı ayrı ayrı korumalı: bazı
/// tarayıcılar/platformlar bu metotlardan birini desteklemeyip hata atabilir —
/// biri başarısız olsa bile diğerleri denenir, hiçbiri yukarı sızmaz.
Future<void> _applyBasics() async {
  if (_basicsApplied) return;
  _basicsApplied = true;
  try {
    await _tts.setPitch(0.85);
  } catch (_) {}
  try {
    await _tts.setSpeechRate(0.9);
  } catch (_) {}
  try {
    await _tts.setLanguage('en-GB');
  } catch (_) {}
}

/// En iyi İngilizce (tercihen İngiliz + erkek) sesi arka planda arar — ses
/// listesinin yüklenmesi birkaç yüz milisaniye sürebilir (bkz. `_loadVoicesWithRetry`).
/// Öncelik sırası: en-GB erkek → en-GB (herhangi cinsiyet) → İngilizce erkek
/// (herhangi bölge) → İngilizce (herhangi). Ses listesi boş dönerse veya
/// `setVoice` platformda desteklenmiyor/hata veriyorsa SESSİZCE vazgeçilir —
/// motor kendi varsayılan sesiyle okumaya devam eder (hiçbir durumda `speak()`
/// çağrısının önüne geçilmez, bkz. `speakAmountInEnglish`).
Future<void> _resolveVoice() async {
  if (_voiceReady) return;
  await _applyBasics();
  try {
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
  } catch (_) {
    // Ses seçimi başarısız oldu (ör. bu tarayıcıda setVoice desteklenmiyor) —
    // motorun varsayılan sesiyle devam edilecek, uygulamayı çökertmez.
  } finally {
    // Başarısız olsa bile tekrar tekrar aynı hatayı denemeyi durdur.
    _voiceReady = true;
  }
}

/// Sesi ÖNCEDEN ısıtır — "sesli oku" butonunu içeren widget ilk oluşturulduğunda
/// (`initState`) çağrılmalıdır, tıklama anında DEĞİL. Birden çok kez çağrılması
/// güvenlidir (idempotent, aynı Future paylaşılır).
///
/// ⚠️ KRİTİK (deploy'da sessiz kalma bug'ının kök nedeni): bazı tarayıcılar
/// `speechSynthesis.speak()`'i yalnızca kullanıcı jestiyle (tıklama) SENKRONA
/// YAKIN bir akışta çağrılırsa kabul eder — `localhost` genelde bu konuda daha
/// gevşektir (Chrome'un medya/otomatik-oynatma politikaları localhost'u ayrıcalıklı
/// tutar), ama gerçek bir deploy origin'inde (ör. GitHub Pages) araya ses listesi
/// arama gecikmesi (yüzlerce ms – birkaç sn) girerse çağrı SESSİZCE reddedilebilir.
/// Bu yüzden ses arama işi tıklamadan ÖNCE (widget `initState`'inde) başlatılır;
/// `speakAmountInEnglish` bu işi ASLA beklemez.
///
/// `_resolveVoice()` bir `async` fonksiyon olsa da Dart'ta ilk `await`'e kadarki
/// kısmı SENKRON çalışır — o kısımda senkron bir hata oluşursa (nadir ama
/// mümkün) bu çağrının kendisi (initState içinde, sarmalayıcısız) çöker. Bu
/// yüzden burada da ayrıca try/catch var.
void warmupTts() {
  if (_warmupFuture != null) return;
  try {
    _warmupFuture = _resolveVoice();
  } catch (_) {
    _warmupFuture = Future.value();
  }
}

/// Verilen TL tutarını İngilizce olarak sesli okur (ör. 20 → "twenty turkish lira").
///
/// ⚠️ KRİTİK — deploy'da (GitHub Pages) sessiz kalma, localde çalışma bug'ının
/// kök nedeni: Chrome'un otomatik-oynatma/kullanıcı-jesti politikası `localhost`'u
/// AYRICALIKLI tutar (gevşek); gerçek bir deploy origin'inde ise
/// `speechSynthesis.speak()` çağrısı yalnızca kullanıcı jestiyle (tıklama)
/// SENKRONA ÇOK YAKIN bir akışta yapılırsa kabul edilir — araya TEK bir `await`
/// bile girse (ör. önce `stop()`'u beklemek) çağrı sessizce hiçbir etki
/// yaratmadan yok sayılabilir. Bu yüzden bu fonksiyon BİLEREK SENKRONDUR:
/// `_tts.speak()` hiçbir `await` ZİNCİRİ olmadan, tıklama işleyicisinin
/// (`_SpeakTotalButtonState._speak`) İÇİNDE DOĞRUDAN çağrılır. Dil/perde/hız/ses
/// seçimi ayrı ayrı arka planda (ateşle-unut) sürer; henüz oturmamışsa motor
/// o an elindeki varsayılanla okur — mükemmel ses yerine SES ÇIKMASI önceliklidir.
void speakAmountInEnglish(num amount) {
  warmupTts(); // henüz başlamadıysa ateşle-unut (idempotent, BEKLENMEZ)
  unawaited(_applyBasics()); // hızlı/yerel ayarlar — arka planda, BEKLENMEZ
  // stop() BİLEREK çağrılmaz/beklenmez — kullanıcı jesti bağlamını bozan asıl
  // adım buydu. speak() önceki bir konuşmayı zaten değiştirir/kuyruğa alır.
  try {
    _tts.speak(amountToEnglishWords(amount));
  } catch (_) {
    // Platform çağrısı senkron olarak hata verdi — sessizce yut.
  }
}
