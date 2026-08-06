import 'package:flutter_test/flutter_test.dart';

import 'package:nicepos_storefront/core/supabase_config.dart';

void main() {
  test('SupabaseConfig dart-define geçilmeyince yapılandırılmamış sayılır', () {
    // Testte dart-define geçilmez; StorefrontApp Supabase.initialize
    // gerektirdiğinden (canlı ağ çağrısı) burada tam widget pump yerine
    // yalnız yapılandırma algılama mantığı doğrulanır.
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
