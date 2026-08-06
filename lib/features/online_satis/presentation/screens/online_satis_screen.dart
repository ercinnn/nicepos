import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OnlineSatisScreen extends StatelessWidget {
  const OnlineSatisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Online Satış',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yakında burada olacak',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
