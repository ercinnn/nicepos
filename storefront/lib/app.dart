import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/models/store_tenant.dart';
import 'features/cart/cart_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/checkout/order_success_screen.dart';
import 'features/home/home_screen.dart';
import 'features/product/product_detail_screen.dart';

// nicepos ana uygulamasındaki `_fadeThroughPage` ile aynı geçiş dili (M3
// fade-through hissi: hafif yukarı kayma + fade) — iki ayrı Flutter projesi
// olsa da marka tutarlılığı için birebir aynı eğri/süre kopyalanır.
CustomTransitionPage<void> _fadeThroughPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final storeRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fadeThroughPage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/urun/:id',
      pageBuilder: (context, state) => _fadeThroughPage(
        state,
        ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/sepet',
      pageBuilder: (context, state) => _fadeThroughPage(state, const CartScreen()),
    ),
    GoRoute(
      path: '/odeme',
      pageBuilder: (context, state) => _fadeThroughPage(state, const CheckoutScreen()),
    ),
    GoRoute(
      path: '/siparis-alindi/:code',
      pageBuilder: (context, state) => _fadeThroughPage(
        state,
        OrderSuccessScreen(
          orderCode: state.pathParameters['code']!,
          summary: state.extra as OrderSummary?,
        ),
      ),
    ),
  ],
);

class StorefrontApp extends StatelessWidget {
  final StoreTenant tenant;

  const StorefrontApp({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '${tenant.name} — Online Satış',
      debugShowCheckedModeBanner: false,
      theme: buildStoreTheme(),
      routerConfig: storeRouter,
    );
  }
}
