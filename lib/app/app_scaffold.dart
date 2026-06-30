import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/utils/formatters.dart';
import '../core/utils/responsive.dart';
import '../features/auth/application/auth_provider.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _NavItem(this.label, this.icon, this.selectedIcon, this.route);
}

const _navItems = [
  _NavItem('Anasayfa', Icons.dashboard_outlined, Icons.dashboard, '/home'),
  _NavItem('Satış Yap', Icons.point_of_sale_outlined, Icons.point_of_sale, '/sales'),
  _NavItem('Raporlar', Icons.bar_chart_outlined, Icons.insert_chart, '/reports'),
  _NavItem('Müşteriler', Icons.people_outline, Icons.people, '/customers'),
  _NavItem('Ürünler', Icons.inventory_2_outlined, Icons.inventory_2, '/products'),
];

int _selectedNavIndex(String currentPath) {
  final index = _navItems.indexWhere((item) =>
      currentPath == item.route ||
      (item.route != '/home' && currentPath.startsWith(item.route)));
  return index < 0 ? 0 : index;
}


class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;

  const AppScaffold({super.key, required this.child, required this.currentPath});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _expanded = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _toggleSidebar() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserEmailProvider);

    if (context.isMobile) {
      return _MobileScaffold(
        scaffoldKey: _scaffoldKey,
        currentPath: widget.currentPath,
        email: email,
        child: widget.child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            currentPath: widget.currentPath,
            expanded: _expanded,
            onToggle: _toggleSidebar,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(email: email, onMenuTap: _toggleSidebar),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: AppColors.pageBg,
                    padding: const EdgeInsets.all(AppSizes.pagePadding),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile scaffold: Drawer + BottomNavigationBar
// ---------------------------------------------------------------------------

class _MobileScaffold extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String currentPath;
  final String? email;
  final Widget child;

  const _MobileScaffold({
    required this.scaffoldKey,
    required this.currentPath,
    required this.email,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textSecondary),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'NicePOS',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Çıkış',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      drawer: _MobileDrawer(currentPath: currentPath, email: email),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
      bottomNavigationBar: _MobileBottomNav(currentPath: currentPath),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobil alt navigasyon — Material 3 NavigationBar (lacivert zemin, altın
// seçili "pill" göstergesi + haptic). Yatay-scroll anti-pattern'inden çıkış.
// ---------------------------------------------------------------------------

class _MobileBottomNav extends StatelessWidget {
  final String currentPath;

  const _MobileBottomNav({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedNavIndex(currentPath);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(top: BorderSide(color: AppColors.primaryMid, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331B2A4A),
            blurRadius: 16,
            offset: Offset(0, -4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.goldLight.withValues(alpha: 0.18),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          height: 64,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
            );
          }),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              context.go(_navItems[index].route);
            },
            destinations: _navItems.map((item) {
              return NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final String currentPath;
  final String? email;

  const _MobileDrawer({required this.currentPath, required this.email});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.point_of_sale, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'NicePOS',
                    style: TextStyle(
                      color: AppColors.sidebarTextActive,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryMid),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _navItems.map((item) {
                  final selected = currentPath == item.route ||
                      (item.route != '/home' && currentPath.startsWith(item.route));
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor: AppColors.sidebarSelectedBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(item.route);
                    },
                  );
                }).toList(),
              ),
            ),
            if (email != null) ...[
              const Divider(height: 1, color: AppColors.primaryMid),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, color: AppColors.sidebarText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email!,
                        style: const TextStyle(fontSize: 12, color: AppColors.sidebarText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop sidebar (unchanged)
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final String currentPath;
  final bool expanded;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final width = expanded ? AppSizes.sidebarWidth : AppSizes.sidebarCollapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          _SidebarHeader(expanded: expanded, onToggle: onToggle),
          const Divider(height: 1, color: AppColors.primaryMid),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _navItems.map((item) {
                final selected = currentPath == item.route ||
                    (item.route != '/home' && currentPath.startsWith(item.route));
                return _SidebarTile(
                  item: item,
                  selected: selected,
                  expanded: expanded,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _SidebarHeader({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.topBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.point_of_sale, color: AppColors.primary, size: 22),
          if (expanded) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'NicePOS',
                style: TextStyle(
                  color: AppColors.sidebarTextActive,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          IconButton(
            onPressed: onToggle,
            tooltip: expanded ? 'Menüyü Daralt' : 'Menüyü Genişlet',
            icon: Icon(
              expanded ? Icons.chevron_left : Icons.chevron_right,
              color: AppColors.sidebarText,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final bool expanded;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.expanded,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.selected
        ? AppColors.sidebarSelectedBg
        : _hovered
            ? AppColors.sidebarHover
            : Colors.transparent;

    final iconColor = widget.selected ? AppColors.sidebarTextActive : AppColors.sidebarText;
    final textColor = widget.selected ? AppColors.sidebarTextActive : AppColors.sidebarText;

    return Tooltip(
      message: widget.expanded ? '' : widget.item.label,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(widget.item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: widget.selected
                  ? const Border(left: BorderSide(color: AppColors.goldLight, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.item.icon, color: iconColor, size: 20),
                if (widget.expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Canlı tarih + saat (üst bar'da arama kutusunun yerini alır)
// ---------------------------------------------------------------------------

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Her saniye güncelle
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            formatDateTime(_now),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  final String? email;
  final VoidCallback onMenuTap;

  const _TopBar({required this.email, required this.onMenuTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.cardBg,
      child: Row(
        children: [
          // Arama kutusu yerine: günün tarihi + canlı saat
          const _LiveClock(),
          const Spacer(),
          if (email != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 6),
                  Text(email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          TextButton.icon(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Çıkış', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
