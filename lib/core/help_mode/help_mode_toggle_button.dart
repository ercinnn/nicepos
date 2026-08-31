import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import 'help_mode_provider.dart';

// Yardım Modu aç/kapa düğmesi — AppScaffold'un hem masaüstü `_TopBar`'ında hem
// mobil `AppBar`'ında ORTAK kullanılır (global chrome, ekrana özel değil).
// Açıkken dolu ikon + info-mavi vurgu ile durumu belli eder.
class HelpModeToggleButton extends ConsumerWidget {
  final bool compact;
  const HelpModeToggleButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(helpModeProvider);
    final button = IconButton(
      icon: Icon(active ? Icons.help : Icons.help_outline),
      color: active ? AppColors.info : AppColors.textSecondary,
      tooltip: active ? 'Yardım Modunu Kapat' : 'Yardım Modu',
      onPressed: () {
        final turningOn = !active;
        ref.read(helpModeProvider.notifier).toggle();
        if (turningOn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yardım modu açık — bir öğeye dokunarak ne işe yaradığını öğrenebilirsiniz.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );
    if (!active) return button;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: button,
    );
  }
}
