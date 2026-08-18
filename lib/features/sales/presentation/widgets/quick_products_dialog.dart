import 'package:flutter/material.dart';

import 'quick_products_panel.dart';

/// "Hızlı Ürünler" panelini mobilde bir diyalog penceresinde açar — ürün
/// seçilince sepete eklenir ve diyalog kapanır. Masaüstündeki inline panelle
/// (`QuickProductsPanel`) aynı widget, yalnız kapanma callback'i eklenir.
class QuickProductsDialog extends StatelessWidget {
  const QuickProductsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hızlı Ürünler'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: QuickProductsPanel(onProductSelected: () => Navigator.pop(context)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }
}
