import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_config.dart';
import '../core/supabase/supabase_client_provider.dart';
import '../features/analiz/presentation/screens/analiz_screen.dart';
import '../features/audit/presentation/screens/audit_log_screen.dart';
import '../features/auth/presentation/screens/config_missing_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';
import '../features/customers/presentation/screens/customers_list_screen.dart';
import '../features/gorevler/presentation/screens/gorevler_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/kasa/presentation/screens/kasa_screen.dart';
import '../features/labels/presentation/screens/labels_screen.dart';
import '../features/online_satis/presentation/screens/online_satis_screen.dart';
import '../features/products/presentation/screens/product_form_screen.dart';
import '../features/products/presentation/screens/products_list_screen.dart';
import '../features/products/presentation/screens/products_tabs_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/sales/presentation/screens/sales_screen.dart';
import 'app_scaffold.dart';

/// Ana sekmeler için yumuşak fade + hafif yukarı kayma geçişi (M3 fade-through
/// hissi). Tüm shell rotalarında tutarlı sayfa geçişi sağlar.
CustomTransitionPage<void> _fadeThroughPage(
  GoRouterState state,
  Widget child,
) {
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return GoRouter(
      initialLocation: '/config',
      routes: [
        GoRoute(
          path: '/config',
          builder: (context, state) => const ConfigMissingScreen(),
        ),
      ],
      redirect: (context, state) =>
          state.matchedLocation == '/config' ? null : '/config',
    );
  }

  final client = ref.watch(supabaseClientProvider);
  final refreshStream = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final goingToLogin = state.matchedLocation == '/login';
      final goingToSignup = state.matchedLocation == '/signup';
      final goingToPublic = goingToLogin || goingToSignup;

      if (!loggedIn) return goingToPublic ? null : '/login';
      if (goingToPublic) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(currentPath: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/sales',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const SalesScreen()),
          ),
          GoRoute(
            path: '/products',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const ProductsTabsScreen()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProductFormScreen(productId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/stok',
            pageBuilder: (context, state) => _fadeThroughPage(
                state, const ProductsListScreen(activeOnly: true)),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const CustomersListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailScreen(
                  customerId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const ReportsScreen()),
          ),
          GoRoute(
            path: '/kasa',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const KasaScreen()),
          ),
          GoRoute(
            path: '/etiket',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const LabelsScreen()),
          ),
          GoRoute(
            path: '/online-satis',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const OnlineSatisScreen()),
          ),
          GoRoute(
            path: '/gorevler',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const GorevlerScreen()),
          ),
          GoRoute(
            path: '/analiz',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const AnalizScreen()),
          ),
          GoRoute(
            path: '/denetim',
            pageBuilder: (context, state) =>
                _fadeThroughPage(state, const AuditLogScreen()),
          ),
        ],
      ),
    ],
  );
});
