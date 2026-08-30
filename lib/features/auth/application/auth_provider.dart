import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../sales/application/barcode_cache.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
}

@Riverpod(keepAlive: true)
String? currentUserEmail(CurrentUserEmailRef ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  return client.auth.currentUser?.email;
}

/// Oturum açan kullanıcının kiracı üyeliği (tenant_id + role). `memberships`
/// RLS ile zaten `user_id = auth.uid()`'e daraltıldığından burada ayrıca
/// filtre uygulamaya gerek yok. Rol-bazlı UI kısıtlaması (staff/admin/owner
/// ekran görünürlüğü) bu provider üzerine ayrı bir kararla inşa edilecek —
/// Faz B bu turda yalnızca veriyi sağlar, henüz hiçbir ekranı kısıtlamaz.
@Riverpod(keepAlive: true)
Future<Membership?> currentMembership(CurrentMembershipRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  if (client.auth.currentUser == null) return null;
  final rows = await client.from('memberships').select('tenant_id, role').limit(1);
  if (rows.isEmpty) return null;
  return Membership(tenantId: rows.first['tenant_id'] as String, role: rows.first['role'] as String);
}

class Membership {
  final String tenantId;
  final String role;
  const Membership({required this.tenantId, required this.role});
  bool get isOwnerOrAdmin => role == 'owner' || role == 'admin';
}

/// Oturum açan kullanıcının kiracısı (ad/slug/plan/aktiflik). `tenants` RLS'i
/// zaten `id = current_tenant_id()`'e daraltıldığından filtresiz `select` tam
/// olarak çağıranın kendi kiracı satırını döndürür (Faz C — bkz. app_scaffold.dart
/// "NicePOS" yerine kiracı adı gösterimi). Faz G altyapısı: `plan`/`is_active`
/// artık uygulama tarafında OKUNUYOR — `is_active=false` `AppScaffold`'da
/// kilitleme ekranına yönlendirir (bkz. app_scaffold.dart). Bu iki alan
/// platform-yönetim alanları — kendi kiracısını yönetemeyen owner/admin'in
/// self-servis değiştirebileceği bir alan DEĞİL, yalnız Supabase Table
/// Editor'dan elle değiştirilir (gerçek faturalama/ödeme entegre olmadan
/// self-servis plan seçimi anlamsız kalırdı).
@Riverpod(keepAlive: true)
Future<TenantInfo?> currentTenant(CurrentTenantRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  if (client.auth.currentUser == null) return null;
  final rows = await client
      .from('tenants')
      .select('id, name, slug, plan, is_active, storefront_image_aspect')
      .limit(1);
  if (rows.isEmpty) return null;
  final row = rows.first;
  return TenantInfo(
    id: row['id'] as String,
    name: row['name'] as String,
    slug: row['slug'] as String,
    plan: row['plan'] as String? ?? 'trial',
    isActive: row['is_active'] as bool? ?? true,
    storefrontImageAspect: row['storefront_image_aspect'] as String? ?? 'portrait',
  );
}

class TenantInfo {
  final String id;
  final String name;
  final String slug;
  final String plan;
  final bool isActive;
  final String storefrontImageAspect;
  const TenantInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.plan = 'trial',
    this.isActive = true,
    this.storefrontImageAspect = 'portrait',
  });
}

/// Gecikmeli e-posta onayı senaryosunu kapatır: kullanıcı `signUp()` anında
/// bir oturum ALMADIYSA (Confirm email açıksa) şirket adı/davet kodu
/// `user_metadata`'da bekler; kullanıcı e-postayı onaylayıp İLK kez giriş
/// yaptığında `memberships` hâlâ boştur — bu provider `ensure_tenant_bootstrap`
/// RPC'sini parametresiz çağırarak (metadata'dan okur) kurulumu tamamlar.
/// Zaten üyeliği olan kullanıcı için no-op'tur (RPC idempotent).
/// Router'ın redirect'i her navigasyonda bu future'ı bekler; ilk çözümden
/// sonra aynı auth state için yeniden hesaplanmaz (keepAlive + authStateChanges
/// yalnız GERÇEK bir auth geçişinde yeniden tetikler).
@Riverpod(keepAlive: true)
Future<void> ensureTenantProvisioned(EnsureTenantProvisionedRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (client.auth.currentUser == null) return;

  // ⚠️ Çapraz-kiracı yerel önbellek sızıntısı düzeltmesi (yaşanmış hata):
  // `BarcodeCache` (bellek-içi, tüm platformlar) ve `products_cache`/
  // `product_groups_cache`/`companies_cache` (native SQLite) hiçbiri
  // `tenant_id` taşımaz ve RLS'e hiç uğramaz. Aynı cihazda önce BAŞKA bir
  // kiracı oturum açtıysa bu önbellekler onun ürün/grup/firma verisini
  // tutmaya devam eder — Ürünler listesi her zaman taze/RLS'li sorgu
  // yaptığından doğru görünür, ama barkod okutma eski kiracının ürününü
  // sepete ekleyebilir. Yalnız GERÇEK bir yeni girişte (`signedIn` —
  // soğuk açılıştaki `initialSession`'da veya token yenilemede
  // TETİKLENMEZ) temizlenir; aksi halde dead-zone dayanıklılığı için
  // tutulan önbellek her token yenilemesinde boşuna silinirdi.
  if (authState?.event == AuthChangeEvent.signedIn) {
    ref.invalidate(barcodeCacheProvider);
    if (!kIsWeb) {
      try {
        await ref.read(appDatabaseProvider).clearTenantScopedCaches();
      } catch (_) {
        // Yerel DB henüz açılamadıysa sessizce geç — bir sonraki online
        // sorgu zaten taze veriyle üzerine yazar (replaceAll), risk yalnız
        // dead-zone'daki kısa bir pencerede kalır.
      }
    }
  }

  final existing = await client.from('memberships').select('id').limit(1);
  if (existing.isNotEmpty) return;

  try {
    await client.rpc('ensure_tenant_bootstrap');
  } catch (_) {
    // Geçersiz/süresi dolmuş davet kodu gibi kurtarılamaz bir durumda kullanıcı
    // güvenle çıkışa alınır — router bunu görüp /login'e döner. Sebep mesajı
    // burada yutulur (v1 basitleştirmesi); kullanıcı yeni bir davetle tekrar
    // dener.
    await client.auth.signOut();
  }
}
