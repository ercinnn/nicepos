import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// NicePOS ana projesiyle aynı Supabase projesini kullanır — kimlik bilgileri
// dart-define ile gömülür (bkz. nicepos/CLAUDE.md "Supabase Kimlik Bilgileri").
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

const _navy = Color(0xFF1B2A4A);
const _gold = Color(0xFFD4B86A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  }
  runApp(const StorefrontApp());
}

class StorefrontApp extends StatelessWidget {
  const StorefrontApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicePOS Online Satış',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _navy,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: !SupabaseConfig.isConfigured
            ? const _ConfigMissing()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 48, color: _navy),
                  const SizedBox(height: 16),
                  const Text(
                    'NicePOS Online Satış',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _navy),
                  ),
                  const SizedBox(height: 8),
                  const Text('Yakında burada olacak', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  const SizedBox(width: 120, child: Divider(color: _gold, thickness: 2)),
                ],
              ),
      ),
    );
  }
}

class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Supabase yapılandırması eksik.\nSUPABASE_URL / SUPABASE_ANON_KEY dart-define ile geçilmeli.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
