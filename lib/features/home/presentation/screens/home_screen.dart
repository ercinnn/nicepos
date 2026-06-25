import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../widgets/dashboard_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('Satış Yap', Icons.point_of_sale_outlined, '/sales'),
      ('Ürünler', Icons.inventory_2_outlined, '/products'),
      ('Ürün Grupları', Icons.category_outlined, '/products/groups'),
      ('Müşteriler', Icons.people_outline, '/customers'),
      ('Raporlar', Icons.bar_chart_outlined, '/reports'),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anasayfa',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Kısayol Butonları ──────────────────────────────────────────
          if (context.isMobile)
            // Mobil: GridView — daha yassı kart (childAspectRatio: 2.8)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8, // önceki: 1.4
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: shortcuts.map((s) {
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.go(s.$3),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            s.$2,
                            size: 20, // önceki: 32
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              s.$1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11), // önceki: 13
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            // Desktop: Wrap — daha küçük kart boyutu
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = (width / 160).floor().clamp(2, 5);
                final cardWidth = (width - (columns - 1) * 12) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: shortcuts.map((s) {
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.go(s.$3),
                        child: SizedBox(
                          width: cardWidth * 0.7,        // önceki: cardWidth
                          height: cardWidth * 0.35,      // önceki: cardWidth * 0.7
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  s.$2,
                                  size: 22,              // önceki: 32
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.$1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11), // önceki: 13
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          // ── Dashboard Bölümü ───────────────────────────────────────────
          const SizedBox(height: 24),
          const DashboardSection(),
        ],
      ),
    );
  }
}
