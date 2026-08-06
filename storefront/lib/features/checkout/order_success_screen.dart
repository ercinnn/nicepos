import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/store_app_bar.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderCode;

  const OrderSuccessScreen({super.key, required this.orderCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StoreAppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: StoreColors.success),
            const SizedBox(height: 16),
            const Text('Siparişiniz alındı!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Sipariş kodu: $orderCode', style: const TextStyle(fontSize: 15, color: StoreColors.textMuted)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => context.go('/'), child: const Text('Alışverişe Devam Et')),
          ],
        ),
      ),
    );
  }
}
