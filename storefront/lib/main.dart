import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_config.dart';
import 'core/tenant_resolver.dart';
import 'core/theme.dart';
import 'data/models/store_tenant.dart';
import 'data/store_repository.dart';
import 'state/tenant_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StoreTenant? tenant;
  String? tenantError;

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );

    // Kiracı çözümlemesi runApp'TEN ÖNCE, bir kez yapılır (bkz.
    // tenant_provider.dart) — ekranlar async yükleme durumu yönetmez, doğrudan
    // ref.watch(currentTenantProvider) okur.
    final slug = resolveTenantSlugFromEnvironment() ?? defaultTenantSlug;
    try {
      tenant = await StoreRepository().resolveTenant(slug);
      if (tenant == null) {
        tenantError = 'Mağaza bulunamadı: "$slug"';
      }
    } catch (_) {
      tenantError = 'Mağaza bilgisi yüklenemedi. Lütfen sayfayı yenileyin.';
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (tenant != null) currentTenantProvider.overrideWithValue(tenant),
      ],
      child: _Root(tenant: tenant, tenantError: tenantError),
    ),
  );
}

class _Root extends StatelessWidget {
  final StoreTenant? tenant;
  final String? tenantError;

  const _Root({required this.tenant, required this.tenantError});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const _MessageApp(
        'Supabase yapılandırması eksik.\nSUPABASE_URL / SUPABASE_ANON_KEY dart-define ile geçilmeli.',
      );
    }
    if (tenant == null) {
      return _MessageApp(
        tenantError ?? 'Mağaza yüklenemedi.',
      );
    }
    return StorefrontApp(tenant: tenant!);
  }
}

class _MessageApp extends StatelessWidget {
  final String message;

  const _MessageApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: StoreColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}
