import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/tenant_context.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Kayıtlı raf etiketi PDF'leri — Supabase Storage repository (KARAR v1.11).
// Bucket: `etiket_pdfleri` (private). Yükle / listele / imzalı URL / indir / sil.
// Program'dan silme = Storage'dan silme (kullanıcı kararı). RLS: authenticated
// rolü bu bucket'ta select/insert/delete (bkz. 0014_etiket_storage.sql).
// ═══════════════════════════════════════════════════════════════════════════

/// Storage'da kayıtlı tek bir etiket PDF'inin özeti (liste satırı).
class SavedLabelFile {
  final String name; // görünen ad (ör. raf-etiket-20260713-1430.pdf)
  final String path; // bucket içi yol (kök seviye → ad ile aynı)
  final int size; // byte
  final DateTime? createdAt;

  const SavedLabelFile({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
  });
}

class LabelsStorageRepository {
  final SupabaseClient _client = Supabase.instance.client;

  static const String bucket = 'etiket_pdfleri';

  // Boş klasör göstergesi Supabase'in eklediği teknik nesnedir → listede gizle.
  static const String _placeholder = '.emptyFolderPlaceholder';

  // Mağaza logosu Storage anahtarı (KARAR v1.12) — PDF listesinden filtrelenir.
  static const String logoKey = '__store_logo.txt';

  // Etiket tagline'ı (İndirim Etiketi'nin logo altı slogan metni, Faz D
  // kiracı-bazı marka) Storage anahtarı — `logoKey` ile aynı desen,
  // PDF listesinden filtrelenir.
  static const String taglineKey = '__store_tagline.txt';

  /// PDF'i verilen adla yükler; çakışmada üzerine YAZMAZ → sona zaman damgası /
  /// sayaç ekleyerek benzersizleştirir. Kaydedilen nihai adı döndürür.
  Future<String> upload(String rawName, Uint8List bytes) async {
    // Faz E (0043): her anahtar kiracı öneki taşır — storage RLS'i bunu
    // (storage.foldername(name))[1] üzerinden zorunlu kılar.
    final tenantId = await currentTenantIdOrThrow(_client);
    var name = _sanitize(rawName);
    if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';

    // Mevcut adlarla çakışma kontrolü (üzerine yazma yok) — yalnız KENDİ
    // kiracımızın klasörü içinde.
    final existing = <String>{};
    try {
      final objs = await _client.storage.from(bucket).list(path: tenantId);
      for (final o in objs) {
        existing.add(o.name);
      }
    } catch (_) {
      // Listeleme başarısızsa çakışma kontrolünü atla (upload yine denenir).
    }

    var finalName = name;
    if (existing.contains(finalName)) {
      final base = name.substring(0, name.length - 4); // ".pdf" hariç
      final stamp = _timeStamp();
      finalName = '$base-$stamp.pdf';
      var i = 1;
      while (existing.contains(finalName)) {
        finalName = '$base-$stamp-$i.pdf';
        i++;
      }
    }

    await _client.storage.from(bucket).uploadBinary(
          '$tenantId/$finalName',
          bytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
    return finalName;
  }

  /// Kayıtlı PDF'leri listeler (yeni → eski). Ad · boyut · oluşturma tarihi.
  Future<List<SavedLabelFile>> list() async {
    final tenantId = await currentTenantIdOrThrow(_client);
    final objs = await _client.storage.from(bucket).list(path: tenantId);
    final files = objs
        .where((o) =>
            o.name != _placeholder &&
            o.name != logoKey &&
            o.name != taglineKey)
        .map((o) {
          final meta = o.metadata;
          final size = (meta?['size'] as num?)?.toInt() ?? 0;
          DateTime? created;
          final rawDate =
              o.createdAt ?? (meta?['lastModified'] as String?);
          if (rawDate != null) {
            created = DateTime.tryParse(rawDate)?.toLocal();
          }
          return SavedLabelFile(
            name: o.name,
            path: '$tenantId/${o.name}',
            size: size,
            createdAt: created,
          );
        })
        .toList();

    files.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return b.name.compareTo(a.name);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return files;
  }

  /// Aç/yazdır için 1 saatlik imzalı URL (private bucket).
  Future<String> signedUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, 60 * 60);

  /// Native yazdırma için PDF byte'larını indirir.
  Future<Uint8List> download(String path) =>
      _client.storage.from(bucket).download(path);

  /// Program'dan silme = Storage'dan silme (KARAR v1.11).
  Future<void> remove(String path) =>
      _client.storage.from(bucket).remove([path]);

  // ─── Mağaza logosu kalıcılığı (KARAR v1.12) ────────────────────────────────
  // Logo, data URL string'i olarak `__store_logo.txt` anahtarında saklanır.
  // RLS update izni olmayabilir → upsert yerine remove+insert kullanılır.

  /// Logoyu (base64 data URL) Storage'a yazar. Önce mevcut logoyu siler.
  Future<void> uploadLogo(String dataUrl) async {
    final tenantId = await currentTenantIdOrThrow(_client);
    final key = '$tenantId/$logoKey';
    try {
      await _client.storage.from(bucket).remove([key]);
    } catch (_) {
      // Mevcut logo yoksa / silinemezse yükleme yine denenir.
    }
    final bytes = Uint8List.fromList(utf8.encode(dataUrl));
    await _client.storage.from(bucket).uploadBinary(
          key,
          bytes,
          fileOptions: const FileOptions(contentType: 'text/plain'),
        );
  }

  /// Kayıtlı logoyu (data URL) getirir; dosya yoksa/offline → null.
  Future<String?> fetchLogo() async {
    try {
      final tenantId = await currentTenantIdOrThrow(_client);
      final bytes = await _client.storage.from(bucket).download('$tenantId/$logoKey');
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Kayıtlı logoyu Storage'dan siler.
  Future<void> removeLogo() async {
    try {
      final tenantId = await currentTenantIdOrThrow(_client);
      await _client.storage.from(bucket).remove(['$tenantId/$logoKey']);
    } catch (_) {}
  }

  // ─── İndirim Etiketi tagline'ı (Faz D — kiracı-bazlı marka) ────────────────
  // `uploadLogo`/`fetchLogo`/`removeLogo` ile birebir aynı desen, düz metin.

  /// Tagline metnini Storage'a yazar. Önce mevcut değeri siler.
  Future<void> uploadTagline(String tagline) async {
    final tenantId = await currentTenantIdOrThrow(_client);
    final key = '$tenantId/$taglineKey';
    try {
      await _client.storage.from(bucket).remove([key]);
    } catch (_) {
      // Mevcut değer yoksa / silinemezse yükleme yine denenir.
    }
    final bytes = Uint8List.fromList(utf8.encode(tagline));
    await _client.storage.from(bucket).uploadBinary(
          key,
          bytes,
          fileOptions: const FileOptions(contentType: 'text/plain'),
        );
  }

  /// Kayıtlı tagline'ı getirir; dosya yoksa/offline → null.
  Future<String?> fetchTagline() async {
    try {
      final tenantId = await currentTenantIdOrThrow(_client);
      final bytes =
          await _client.storage.from(bucket).download('$tenantId/$taglineKey');
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  // Dosya adını Storage anahtarı için güvenli hale getirir: yol ayraçlarını ve
  // riskli karakterleri temizler, boşlukları tireye çevirir. Türkçe harfler ve
  // .-_ korunur. Boş kalırsa varsayılan ad.
  String _sanitize(String s) {
    var t = s.trim();
    t = t.replaceAll(RegExp(r'[\\/]+'), '-');
    t = t.replaceAll(RegExp(r'[^A-Za-z0-9ğüşıöçİĞÜŞÖÇ._ -]'), '');
    t = t.replaceAll(RegExp(r'\s+'), '-');
    t = t.replaceAll(RegExp(r'-+'), '-');
    if (t.isEmpty || t == '.pdf') t = 'raf-etiket';
    return t;
  }

  // Çakışmada eklenecek kısa zaman damgası: SSDDss (saat-dakika-saniye).
  String _timeStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
