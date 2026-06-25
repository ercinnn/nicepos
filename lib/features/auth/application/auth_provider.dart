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
