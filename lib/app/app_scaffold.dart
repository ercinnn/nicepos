import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/utils/responsive.dart';
import '../features/auth/application/auth_provider.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;

  const _NavItem(this.label, this.icon, this.route);
}

const _navItems = [
  _NavItem('Anasayfa', Icons.dashboard_outlined, '/home'),
  _NavItem('Satış Yap', Icons.point_of_sale_outlined, '/sales'),
  _NavItem('Raporlar', Icons.bar_chart_outlined, '/reports'),
  _NavItem('Müşteriler', Icons.people_outline, '/customers'),
  _NavItem('Ürünler', Icons.inventory_2_outlined, '/products'),
];


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
                color: AppColors.sidebarTextActive,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
      bottomNavigationBar: _ScrollableBottomNav(currentPath: currentPath),
    );
  }
}

class _ScrollableBottomNav extends StatelessWidget {
  final String currentPath;

  const _ScrollableBottomNav({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _navItems.map((item) {
                final selected = currentPath == item.route ||
                    (item.route != '/home' && currentPath.startsWith(item.route));
                return InkWell(
                  onTap: () => context.go(item.route),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: selected ? AppColors.goldLight : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? AppColors.sidebarTextActive : AppColors.sidebarText,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
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
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.pageBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
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
