import 'package:flutter/material.dart';

/// Hızlı nakit tutar butonları: ödenen tutara ekler, tam tutarı ayarlar veya temizler.
class NumericCashPad extends StatelessWidget {
  final ValueChanged<num> onAdd;
  final VoidCallback onExact;
  final VoidCallback onClear;

  const NumericCashPad({super.key, required this.onAdd, required this.onExact, required this.onClear});

  static const _amounts = [5, 10, 20, 50, 100, 200];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._amounts.map((amount) => OutlinedButton(
              onPressed: () => onAdd(amount),
              child: Text('+$amount'),
            )),
        ElevatedButton(onPressed: onExact, child: const Text('Tam Tutar')),
        OutlinedButton(onPressed: onClear, child: const Text('Temizle')),
      ],
    );
  }
}
