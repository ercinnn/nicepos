import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/cart/cart_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/checkout/order_success_screen.dart';
import 'features/home/home_screen.dart';
import 'features/product/product_detail_screen.dart';

final storeRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/urun/:id',
      builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/sepet', builder: (context, state) => const CartScreen()),
    GoRoute(path: '/odeme', builder: (context, state) => const CheckoutScreen()),
    GoRoute(
      path: '/siparis-alindi/:code',
      builder: (context, state) => OrderSuccessScreen(orderCode: state.pathParameters['code']!),
    ),
  ],
);

class StorefrontApp extends StatelessWidget {
  const StorefrontApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NicePOS Online Satış',
      debugShowCheckedModeBanner: false,
      theme: buildStoreTheme(),
      routerConfig: storeRouter,
    );
  }
}
