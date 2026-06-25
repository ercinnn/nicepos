import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 32),
                      SizedBox(width: 12),
                      Text('Supabase yapılandırması eksik',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Uygulamayı çalıştırırken Supabase proje bilgilerinizi '
                    '--dart-define ile geçmeniz gerekiyor:',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const SelectableText(
                      'flutter run -d chrome \\\n'
                      '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                      '  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bu değerleri Supabase Dashboard > Project Settings > API '
                    'sayfasından alabilirsiniz. Veritabanı tabloları için '
                    'supabase/migrations klasöründeki SQL dosyalarını sırasıyla '
                    'SQL Editor\'de çalıştırın.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
