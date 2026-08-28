import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

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

/// Oturum açan kullanıcının kiracısı (ad/slug). `tenants` RLS'i zaten
/// `id = current_tenant_id()`'e daraltıldığından filtresiz `select` tam
/// olarak çağıranın kendi kiracı satırını döndürür (Faz C — bkz. app_scaffold.dart
/// "NicePOS" yerine kiracı adı gösterimi).
@Riverpod(keepAlive: true)
Future<TenantInfo?> currentTenant(CurrentTenantRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateChangesProvider);
  if (client.auth.currentUser == null) return null;
  final rows = await client.from('tenants').select('id, name').limit(1);
  if (rows.isEmpty) return null;
  return TenantInfo(id: rows.first['id'] as String, name: rows.first['name'] as String);
}

class TenantInfo {
  final String id;
  final String name;
  const TenantInfo({required this.id, required this.name});
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
  ref.watch(authStateChangesProvider);
  if (client.auth.currentUser == null) return;

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
