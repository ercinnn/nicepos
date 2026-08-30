import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/store_tenant.dart';

// main.dart tenant çözümlemesini runApp'TEN ÖNCE, ProviderScope override ile
// bir kez yapar — her ekranın kendi async yükleme durumu OLMAZ. Gerçek değer
// her zaman override edilir (bkz. main.dart); throw eden default, yanlışlıkla
// override'sız kullanımı erken yakalar.
final currentTenantProvider = Provider<StoreTenant>((ref) {
  throw StateError('currentTenantProvider override edilmeden okundu');
});
