import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import 'companies_screen.dart';
import 'liste_gir_screen.dart';
import 'product_groups_screen.dart';
import 'products_list_screen.dart';

class ProductsTabsScreen extends StatelessWidget {
  const ProductsTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Liste Gir yalnız masaüstünde: dikdörtgen çizimi mouse ile yapılır,
    // pdf.js/Tesseract.js interop'u yalnız web'de çalışır (bkz. plan).
    final isDesktop = context.isDesktop;
    final tabs = [
      const Tab(text: 'Ürünler'),
      const Tab(text: 'Ürün Grupları'),
      const Tab(text: 'Firmalar'),
      if (isDesktop) const Tab(text: 'Liste Gir'),
    ];
    final views = [
      const ProductsListScreen(),
      const ProductGroupsScreen(),
      const CompaniesScreen(),
      if (isDesktop) const ListeGirScreen(),
    ];

    return DefaultTabController(
      length: tabs.length,
      // Sekme sayısı masaüstü/mobil kırılımında değişebilir (pencere
      // küçültme) — key olmadan TabController eski index'i korur ve
      // aktif sekme 4. iken 3'e düşerse index-out-of-range verir.
      key: ValueKey(tabs.length),
      child: Column(
        children: [
          Container(
            color: AppColors.cardBg,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: tabs,
            ),
          ),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}
