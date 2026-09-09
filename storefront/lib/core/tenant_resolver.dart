// Storefront hangi kiracıya ait olduğunu iki kaynaktan çözer (Faz F, Adım 1):
//
//   1) `?magaza=<slug>` query parametresi — Cloudflare Pages'in tek
//      `nicepos-online-satis.pages.dev` adresinde HİÇBİR DNS/domain işi
//      olmadan bugün çalışır (elle paylaşılan link / QR kod).
//   2) Alt alan adı (`<slug>.<wildcard-domain>`) — kendi domain'imize
//      wildcard custom domain eklendiğinde (Faz F, Adım 2, henüz kurulmadı)
//      otomatik devreye girer, kod tarafında ek değişiklik gerekmez.
//
// İkisi de yoksa `null` döner — çağıran taraf (main.dart)
// [defaultTenantSlug]'a düşer, böylece mevcut tek-kiracı canlı site
// (bookmark/QR kodları dahil) davranış değiştirmeden çalışmaya devam eder.
//
// ⚠️ Kendi domain'ini bağlama (bir tenant'ın SATIN ALDIĞI domain'in doğrudan
// kendisi, alt alan adı DEĞİL) Faz F Adım 2'nin kapsamı — o zaman host'un
// TAMAMI bir tenant'a eşlenmeli (ayrı bir domain→tenant_id tablosu gerekir),
// burada ELE ALINMAZ.
const String defaultTenantSlug = 'ilk-magaza';

const Set<String> _reservedFirstLabels = {
  'www',
  'localhost',
  'nicepos-online-satis', // mevcut paylaşılan pages.dev adresi
};

String? resolveTenantSlugFromEnvironment() {
  final uri = Uri.base;

  final fromQuery = uri.queryParameters['magaza']?.trim();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  final host = uri.host;
  final labels = host.split('.');
  if (labels.length >= 3 && !_reservedFirstLabels.contains(labels.first)) {
    return labels.first;
  }
  return null;
}
