import 'package:flutter/material.dart';

import '../widgets/dashboard_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dashboard Bölümü ───────────────────────────────────────────
          const DashboardSection(),
        ],
      ),
    );
  }
}
