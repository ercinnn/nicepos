// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authStateChangesHash() => r'62dfa64033c62e46f889962498753329774f0414';

/// See also [authStateChanges].
@ProviderFor(authStateChanges)
final authStateChangesProvider = StreamProvider<AuthState>.internal(
  authStateChanges,
  name: r'authStateChangesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateChangesRef = StreamProviderRef<AuthState>;
String _$currentUserEmailHash() => r'1d83025adcc9e98c37b99a66783ebdbb94680ea8';

/// See also [currentUserEmail].
@ProviderFor(currentUserEmail)
final currentUserEmailProvider = Provider<String?>.internal(
  currentUserEmail,
  name: r'currentUserEmailProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserEmailRef = ProviderRef<String?>;
String _$currentMembershipHash() => r'877e360fb2ba6f80232289ed0e8e207bd7c64f8d';

/// Oturum açan kullanıcının kiracı üyeliği (tenant_id + role). `memberships`
/// RLS ile zaten `user_id = auth.uid()`'e daraltıldığından burada ayrıca
/// filtre uygulamaya gerek yok. Rol-bazlı UI kısıtlaması (staff/admin/owner
/// ekran görünürlüğü) bu provider üzerine ayrı bir kararla inşa edilecek —
/// Faz B bu turda yalnızca veriyi sağlar, henüz hiçbir ekranı kısıtlamaz.
///
/// Copied from [currentMembership].
@ProviderFor(currentMembership)
final currentMembershipProvider = FutureProvider<Membership?>.internal(
  currentMembership,
  name: r'currentMembershipProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentMembershipHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentMembershipRef = FutureProviderRef<Membership?>;
String _$currentTenantHash() => r'b84cd6133f4f4e33cc1106dc0fd22fa4016af50d';

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
///
/// Copied from [currentTenant].
@ProviderFor(currentTenant)
final currentTenantProvider = FutureProvider<TenantInfo?>.internal(
  currentTenant,
  name: r'currentTenantProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentTenantHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentTenantRef = FutureProviderRef<TenantInfo?>;
String _$ensureTenantProvisionedHash() =>
    r'b73fe4ae73a11cc733cafd9f30c459d15a57decf';

/// Gecikmeli e-posta onayı senaryosunu kapatır: kullanıcı `signUp()` anında
/// bir oturum ALMADIYSA (Confirm email açıksa) şirket adı/davet kodu
/// `user_metadata`'da bekler; kullanıcı e-postayı onaylayıp İLK kez giriş
/// yaptığında `memberships` hâlâ boştur — bu provider `ensure_tenant_bootstrap`
/// RPC'sini parametresiz çağırarak (metadata'dan okur) kurulumu tamamlar.
/// Zaten üyeliği olan kullanıcı için no-op'tur (RPC idempotent).
/// Router'ın redirect'i her navigasyonda bu future'ı bekler; ilk çözümden
/// sonra aynı auth state için yeniden hesaplanmaz (keepAlive + authStateChanges
/// yalnız GERÇEK bir auth geçişinde yeniden tetikler).
///
/// Copied from [ensureTenantProvisioned].
@ProviderFor(ensureTenantProvisioned)
final ensureTenantProvisionedProvider = FutureProvider<void>.internal(
  ensureTenantProvisioned,
  name: r'ensureTenantProvisionedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ensureTenantProvisionedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EnsureTenantProvisionedRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
