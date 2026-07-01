import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'companies_screen.dart';
import 'product_groups_screen.dart';
import 'products_list_screen.dart';

class ProductsTabsScreen extends StatelessWidget {
  const ProductsTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppColors.cardBg,
            child: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Ürünler'),
                Tab(text: 'Ürün Grupları'),
                Tab(text: 'Firmalar'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ProductsListScreen(),
                ProductGroupsScreen(),
                CompaniesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
