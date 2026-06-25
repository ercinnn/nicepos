import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'daily_report_screen.dart';
import 'historical_report_tab.dart';
import 'product_report_tab.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Raporlar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(icon: Icon(Icons.today_outlined, size: 18), text: 'Günlük Rapor'),
                Tab(
                    icon: Icon(Icons.date_range_outlined, size: 18),
                    text: 'Tarihsel Rapor'),
                Tab(
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                    text: 'Ürün Raporları'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: TabBarView(
              children: [
                DailyReportScreen(),
                HistoricalReportTab(),
                ProductReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
