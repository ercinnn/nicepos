import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../state/cart_provider.dart';
import '../state/tenant_provider.dart';

// Dar ekranda (<600) arama satırının AppBar.bottom'da kapladığı ekstra
// yükseklik (TextField ~40 + üst/alt boşluk 8+8) — mevcut sabit `_kBase`
// (toolbar + altın çizgi) yükseklikten AYRI, yalnız açıkken eklenir.
const double _kNarrowSearchRowHeight = 56;
const double _kBaseHeight = 65; // mevcut sabit (toolbar + altın çizgi)

class StoreAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? searchField;

  // Dar ekran (<600) davranışı tamamen çağıran ekran tarafından kontrol
  // edilir — StoreAppBar'ın kendisi state TUTMAZ. Neden: `preferredSize`
  // Scaffold tarafından widget KURULURKEN (BuildContext'siz) okunur;
  // StoreAppBar'ın altında yaşayan bir State'in kendi içindeki setState'i
  // Scaffold'u yeniden derletmez (Scaffold, StoreAppBar'ın ATASI). Bu
  // yüzden hem darlık hem açık/kapalı bilgisi üst ekranın (ör. HomeScreen)
  // kendi State'inden, her build'de taze constructor parametresi olarak
  // gelir — üst ekran zaten MediaQuery'e bağımlı olduğundan pencere
  // genişliği değişince otomatik yeniden derlenir.
  final bool narrow;
  final bool searchExpanded;
  final VoidCallback? onToggleSearch;

  const StoreAppBar({
    super.key,
    this.searchField,
    this.narrow = false,
    this.searchExpanded = false,
    this.onToggleSearch,
  });

  bool get _showNarrowSearchRow =>
      narrow && searchField != null && searchExpanded;

  @override
  Size get preferredSize => Size.fromHeight(
    _kBaseHeight + (_showNarrowSearchRow ? _kNarrowSearchRowHeight : 0),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(
      cartProvider.select((items) => items.fold(0, (s, i) => s + i.quantity)),
    );
    final storeName = ref.watch(currentTenantProvider).name;

    return AppBar(
      // İnce altın çizgi — ana uygulamanın "altın ray" imzasının en küçük
      // yansıması, koyu app bar'ı sıradan bir Material AppBar olmaktan
      // çıkarır. Dar ekranda arama açıkken bunun ÜSTÜNE (aynı PreferredSize
      // katmanı içinde) tam genişlikte bir arama satırı eklenir — altın
      // çizginin YERİNE değil, onunla BİRLİKTE.
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 + (_showNarrowSearchRow ? _kNarrowSearchRowHeight : 0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showNarrowSearchRow)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SizedBox(height: 40, child: searchField),
              ),
            Container(
              height: 1,
              color: StoreColors.gold.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
      title: GestureDetector(
        onTap: () => context.go('/'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, color: StoreColors.goldLight),
            const SizedBox(width: 8),
            Text(storeName, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        // Geniş ekran (>=600): mevcut sabit 320px arama kutusu AYNEN kalır.
        if (searchField != null && !narrow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(width: 320, child: searchField),
          ),
        // Dar ekran (<600): sabit 320px kutu yerine yalnız bir ikon —
        // 375px genişlikte 320px + sepet ikonu + padding logo'yu sıfıra
        // sıkıştırıp arama kutusunun kendisini de kırpıyordu. Dokununca
        // tam genişlikte arama satırı `bottom`'da açılır/kapanır.
        if (searchField != null && narrow)
          IconButton(
            tooltip: searchExpanded ? 'Aramayı kapat' : 'Ara',
            onPressed: onToggleSearch,
            icon: Icon(searchExpanded ? Icons.close : Icons.search),
          ),
        IconButton(
          tooltip: 'Sepet',
          onPressed: () => context.go('/sepet'),
          icon: Badge(
            label: Text('$itemCount'),
            isLabelVisible: itemCount > 0,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
