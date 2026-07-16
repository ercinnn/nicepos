import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Barkod okutma sesi (KARAR v1.14.1) — uygulama geneli kısa sentetik bip.
//
// Ses dosyası (asset) YOK: kısa 16-bit PCM/WAV byte'ları Dart'ta sentezlenir ve
// `BytesSource` ile çalınır → tek codepath ile hem web hem Android'de çalışır.
//   • success = tek net yüksek ton (~920 Hz, kısa) → "okundu"
//   • fail    = daha alçak/sert çift ton (~240→200 Hz, hafif daha uzun) →
//               "danger" hissi (çözülemeyen barkod)
//
// Ses, mevcut HapticFeedback + görsel bildirimi DEĞİŞTİRMEZ, tamamlar. Ses
// çalınamazsa (izin, platform, autoplay kısıtı) sessizce yutulur — uygulama
// akışı bozulmaz.
// ═══════════════════════════════════════════════════════════════════════════

const int _kSampleRate = 44100;

// Tek paylaşılan oynatıcı — hızlı ardışık okutmalarda öncekini kesip yeniden çalar.
final AudioPlayer _player = AudioPlayer();

// WAV byte'ları bir kez üretilip önbelleğe alınır (her okutmada yeniden sentez yok).
Uint8List? _successWav;
Uint8List? _failWav;

/// Başarılı/başarısız barkod okutması için kısa bip çalar. [success] false ise
/// danger hissi veren alçak/sert uyarı sesi çalınır. Hata sessizce yutulur.
Future<void> playScanBeep({required bool success}) async {
  try {
    final bytes = success
        ? (_successWav ??= _buildSuccessWav())
        : (_failWav ??= _buildFailWav());
    await _player.stop();
    await _player.play(
      BytesSource(bytes, mimeType: 'audio/wav'),
      volume: 1.0,
    );
  } catch (_) {
    // Ses çalınamadı — akış bozulmasın (sessizce yut).
  }
}

// Kısa attack + decay zarfı (tık/pop sesini önler). [i] örnek indeksi, [n] toplam.
double _envelope(int i, int n) {
  const attack = 220; // ~5 ms
  final release = (n * 0.28).round(); // son ~%28 sönümlenir
  if (i < attack) return i / attack;
  if (i > n - release) return (n - i) / release;
  return 1.0;
}

// Başarı: tek net yüksek ton (~920 Hz, ~90 ms).
Uint8List _buildSuccessWav() {
  const freq = 920.0;
  final n = (_kSampleRate * 0.09).round();
  final samples = Int16List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _kSampleRate;
    final v = sin(2 * pi * freq * t) * _envelope(i, n) * 0.6;
    samples[i] = (v * 32767).round();
  }
  return _encodeWav(samples);
}

// Hata: alçak/sert çift ton (240 Hz → 200 Hz, aralarında kısa boşluk). Hafif
// kare-dalga karışımı sertlik/danger hissi verir; başarıdan belirgin farklı.
Uint8List _buildFailWav() {
  final segN = (_kSampleRate * 0.13).round(); // her ton ~130 ms
  final gapN = (_kSampleRate * 0.045).round(); // ~45 ms sessizlik
  final total = segN * 2 + gapN;
  final samples = Int16List(total);

  void fillTone(int start, double freq) {
    for (var i = 0; i < segN; i++) {
      final t = i / _kSampleRate;
      final s = sin(2 * pi * freq * t);
      // %55 kare + %45 sinüs → buzzer/uyarı tınısı (sert ama aşırı değil).
      final shaped = 0.55 * (s >= 0 ? 1.0 : -1.0) + 0.45 * s;
      final v = shaped * _envelope(i, segN) * 0.5;
      samples[start + i] = (v * 32767).round();
    }
  }

  fillTone(0, 240);
  fillTone(segN + gapN, 200);
  return _encodeWav(samples);
}

// 16-bit PCM mono örnekleri kanonik WAV (RIFF) konteynerine sarar.
Uint8List _encodeWav(Int16List samples) {
  final dataLen = samples.length * 2;
  final buf = BytesBuilder();

  void ascii4(String s) => buf.add(ascii.encode(s));
  void u32(int v) =>
      buf.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  void u16(int v) => buf.add([v & 0xff, (v >> 8) & 0xff]);

  ascii4('RIFF');
  u32(36 + dataLen);
  ascii4('WAVE');
  ascii4('fmt ');
  u32(16); // fmt chunk boyutu (PCM)
  u16(1); // format = PCM
  u16(1); // kanal = mono
  u32(_kSampleRate);
  u32(_kSampleRate * 2); // byte rate = sr * kanal * 2
  u16(2); // block align
  u16(16); // bit derinliği
  ascii4('data');
  u32(dataLen);

  final data = ByteData(dataLen);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  buf.add(data.buffer.asUint8List());
  return buf.toBytes();
}
