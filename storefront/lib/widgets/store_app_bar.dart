import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../state/cart_provider.dart';

class StoreAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? searchField;

  const StoreAppBar({super.key, this.searchField});

  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(
      cartProvider.select((items) => items.fold(0, (s, i) => s + i.quantity)),
    );

    return AppBar(
      // İnce altın çizgi — ana uygulamanın "altın ray" imzasının en küçük
      // yansıması, koyu app bar'ı sıradan bir Material AppBar olmaktan çıkarır.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: StoreColors.gold.withValues(alpha: 0.55),
        ),
      ),
      title: GestureDetector(
        onTap: () => context.go('/'),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, color: StoreColors.goldLight),
            SizedBox(width: 8),
            Text('NicePOS', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        if (searchField != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(width: 320, child: searchField),
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
