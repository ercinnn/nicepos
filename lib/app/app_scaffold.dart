import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/connectivity/connectivity_status_service.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_sizes.dart';
import '../core/utils/formatters.dart';
import '../core/utils/responsive.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/presentation/widgets/edit_tenant_name_dialog.dart';
import '../features/auth/presentation/widgets/staff_invite_dialog.dart';
import '../features/gorevler/application/gorevler_provider.dart' show gorevlerTarihAnahtari;
import '../features/products/application/product_sync_service.dart';
import '../features/products/application/sync_status.dart';
import '../features/products/presentation/widgets/sync_status_badge.dart';
import '../features/sales/application/sale_sync_service.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  // Rol-bazlı kısıtlama (kullanıcı kararı): yalnız owner/admin görür. Staff
  // için menüden gizlenir (ekran kendisi de ayrıca guard'lı — bkz. KasaScreen).
  final bool ownerOrAdminOnly;

  const _NavItem(this.label, this.icon, this.selectedIcon, this.route,
      {this.ownerOrAdminOnly = false});
}

const _navItems = [
  _NavItem('Anasayfa', Icons.dashboard_outlined, Icons.dashboard, '/home'),
  _NavItem('Görevler', Icons.checklist_outlined, Icons.checklist, '/gorevler'),
  _NavItem('Analiz', Icons.query_stats_outlined, Icons.query_stats, '/analiz'),
  _NavItem('Satış Yap', Icons.point_of_sale_outlined, Icons.point_of_sale, '/sales'),
  _NavItem('Raporlar', Icons.bar_chart_outlined, Icons.insert_chart, '/reports'),
  _NavItem('Kasa', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '/kasa',
      ownerOrAdminOnly: true),
  _NavItem('Etiket', Icons.label_outline, Icons.label, '/etiket'),
  _NavItem('Online Satış', Icons.shopping_bag_outlined, Icons.shopping_bag, '/online-satis'),
  _NavItem('Müşteriler', Icons.people_outline, Icons.people, '/customers'),
  _NavItem('Ürünler', Icons.inventory_2_outlined, Icons.inventory_2, '/products'),
  _NavItem('Stok', Icons.playlist_add_check_outlined, Icons.playlist_add_check, '/stok'),
  _NavItem('Denetim Kaydı', Icons.history_outlined, Icons.history, '/denetim',
      ownerOrAdminOnly: true),
];

// Rol-bazlı görünür menü — staff için `ownerOrAdminOnly` öğeler filtrelenir.
List<_NavItem> _visibleNavItems(bool isOwnerOrAdmin) =>
    isOwnerOrAdmin ? _navItems : _navItems.where((i) => !i.ownerOrAdminOnly).toList();

int _selectedNavIndex(List<_NavItem> items, String currentPath) {
  final index = items.indexWhere((item) =>
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
  void initState() {
    super.initState();
    // Mobil çevrimdışı ürün+satış senkronu — uygulama açılışında bir kez,
    // önceki oturumdan kalan bekleyen kayıt varsa hemen göndermeyi dener.
    // Paylaşılan `ConnectivityStatusService.probeAndNotify()` TEK bir prob
    // yapar ve online ise KAYITLI tüm bağımlıları (ürün+satış) birlikte
    // tetikler — `ProductSyncService`/`SaleSyncService.syncNow()` artık
    // doğrudan çağrılmaz (kendi prob'ları yok). `AppScaffold` `ShellRoute`
    // içinde tüm ekranları sardığından bu State bir oturumda yalnız bir kez
    // kurulur (rota değişimlerinde yeniden çalışmaz). Yalnız native — web'de
    // sqflite/connectivity_plus hiç kullanılmaz.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify();
      });
    }
    // Görevler (dünkü satışların raf-kontrol listesi) uygulama o gün ilk
    // açıldığında otomatik gösterilir — `AppScaffold` bir oturumda yalnız bir
    // kez kurulduğundan bu da oturum başına yalnız bir kez tetiklenir; tarih
    // anahtarı SharedPreferences'ta saklandığından aynı gün içinde tekrar
    // açılış/route değişimi yeniden yönlendirmez. Tüm platformlarda (web dahil)
    // geçerli — "uygulama" burada cihaz/platform ayrımı gözetmez.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirectToGorevler());
  }

  Future<void> _maybeRedirectToGorevler() async {
    final prefs = await SharedPreferences.getInstance();
    final bugun = gorevlerTarihAnahtari();
    final sonAcilis = prefs.getString('gorevler_son_acilis_tarihi');
    if (sonAcilis == bugun) return;
    await prefs.setString('gorevler_son_acilis_tarihi', bugun);
    if (mounted) context.go('/gorevler');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserEmailProvider);

    // Kiracı provizyonu garantisi (gecikmeli e-posta onayı senaryosu — bkz.
    // auth_provider.dart `ensureTenantProvisionedProvider`). ⚠️ Bilinçli
    // olarak router'ın `redirect`'inde DEĞİL, burada widget seviyesinde
    // beklenir: `redirect` içinde `await` edilen bir asenkron kontrol,
    // go_router'ın `refreshListenable`'ı (auth state değişimleri) ile
    // çakışıp TÜM uygulamanın canlıda kalıcı beyaz ekranda kilitlenmesine
    // yol açmıştı (ölçülmüş hata) — router her zaman senkron kalmalı, yükleme
    // durumu bir widget'ın normal build akışında (burada) gösterilmeli.
    final provisioning = ref.watch(ensureTenantProvisionedProvider);
    if (provisioning.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Faz G altyapısı — `tenants.is_active=false` (yalnız Supabase Table
    // Editor'dan elle set edilir, bkz. auth_provider.dart) uygulamayı
    // kilitler. Provizyon kontrolüyle AYNI desen: widget seviyesinde, router
    // `redirect`'inde DEĞİL. Henüz çözülmediyse (`valueOrNull == null`)
    // ENGELLENMEZ — owner/admin çoğunluk senaryosunda gecikme yaşamasın.
    final tenant = ref.watch(currentTenantProvider).valueOrNull;
    if (tenant != null && !tenant.isActive) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: AppSizes.space16),
                const Text(
                  'Hesabınız pasifleştirildi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                const Text(
                  'Bu işletme hesabı şu an aktif değil. Devam etmek için '
                  'destek ile iletişime geçin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.space20),
                OutlinedButton.icon(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobil çevrimdışı ürün senkronu — arka planda (kullanıcı hiç dokunmadan,
    // ör. periyodik prob veya connectivity geri gelince) sessizce tamamlanan
    // bir senkron döngüsünü bildirir. `AppScaffold` tüm rotaları sardığından
    // kullanıcı hangi ekranda olursa olsun görür. Yalnız native — web'de
    // `ProductSyncService` hiç tetiklenmez (bkz. plan notu, sync_status.dart
    // `lastSyncedCount`).
    if (!kIsWeb) {
      ref.listen<SyncStatus>(productSyncServiceProvider, (prev, next) {
        if (next.lastSyncedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${next.lastSyncedCount} ürün kaydı senkronize edildi')));
        }
      });
      ref.listen<SyncStatus>(saleSyncServiceProvider, (prev, next) {
        if (next.lastSyncedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${next.lastSyncedCount} satış senkronize edildi')));
        }
      });
    }

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
    // Faz C: uygulama içi marka metni artık kiracının kendi adı — yalnız
    // pre-login ekranlarda (giriş/kayıt) "NicePOS" platform adı kalır.
    final tenantName = ref.watch(currentTenantProvider).valueOrNull?.name ?? 'NicePOS';

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
        title: Row(
          children: [
            const Icon(Icons.point_of_sale, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              tenantName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          // Mobil çevrimdışı ürün senkronu — yalnız native (bkz. plan notu:
          // `!kIsWeb` guard, `context.isMobile` DEĞİL, çünkü bir Android
          // tablet yatayda "masaüstü" `_TopBar`'ı render edebilir).
          if (!kIsWeb) const SyncStatusBadge(),
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
// Mobil alt navigasyon — yatay kaydırılabilir şerit. 9 madde sabit-genişlikli
// `NavigationBar` içinde sığmıyordu (etiketler sıkışıp okunaksızlaşıyordu);
// bunun yerine her öğe sabit genişlikte, taşan kısım yana kaydırılarak
// erişilir. Seçili öğe rota değişince görünür alana otomatik kaydırılır.
// ---------------------------------------------------------------------------

class _MobileBottomNav extends ConsumerStatefulWidget {
  final String currentPath;

  const _MobileBottomNav({required this.currentPath});

  @override
  ConsumerState<_MobileBottomNav> createState() => _MobileBottomNavState();
}

class _MobileBottomNavState extends ConsumerState<_MobileBottomNav> {
  static const _itemWidth = 76.0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: false));
  }

  @override
  void didUpdateWidget(covariant _MobileBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _scrollToSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected({required bool animate}) {
    if (!_scrollController.hasClients) return;
    final isOwnerOrAdmin =
        ref.read(currentMembershipProvider).valueOrNull?.isOwnerOrAdmin == true;
    final index =
        _selectedNavIndex(_visibleNavItems(isOwnerOrAdmin), widget.currentPath);
    final viewport = _scrollController.position.viewportDimension;
    final target = (index * _itemWidth) - (viewport / 2) + (_itemWidth / 2);
    final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(clamped, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnerOrAdmin =
        ref.watch(currentMembershipProvider).valueOrNull?.isOwnerOrAdmin == true;
    final items = _visibleNavItems(isOwnerOrAdmin);
    final selectedIndex = _selectedNavIndex(items, widget.currentPath);

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
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return _BottomNavItem(
                item: item,
                selected: selected,
                width: _itemWidth,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.go(item.route);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.sidebarTextActive : AppColors.sidebarText;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.goldLight.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Icon(selected ? item.selectedIcon : item.icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends ConsumerWidget {
  final String currentPath;
  final String? email;

  const _MobileDrawer({required this.currentPath, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    final tenantName = ref.watch(currentTenantProvider).valueOrNull?.name ?? 'NicePOS';
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
                  Expanded(
                    child: Text(
                      tenantName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.sidebarTextActive,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryMid),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _visibleNavItems(membership?.isOwnerOrAdmin == true)
                    .map((item) {
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
            if (membership?.isOwnerOrAdmin == true) ...[
              const Divider(height: 1, color: AppColors.primaryMid),
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined,
                    color: AppColors.sidebarText, size: 20),
                title: const Text('Personel Davet Et',
                    style: TextStyle(fontSize: 14, color: AppColors.sidebarText)),
                onTap: () {
                  Navigator.of(context).pop();
                  showStaffInviteDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: AppColors.sidebarText, size: 20),
                title: const Text('İşletme Adını Düzenle',
                    style: TextStyle(fontSize: 14, color: AppColors.sidebarText)),
                onTap: () {
                  Navigator.of(context).pop();
                  showEditTenantNameDialog(context, currentName: tenantName);
                },
              ),
            ],
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

class _Sidebar extends ConsumerWidget {
  final String currentPath;
  final bool expanded;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = expanded ? AppSizes.sidebarWidth : AppSizes.sidebarCollapsedWidth;
    final isOwnerOrAdmin =
        ref.watch(currentMembershipProvider).valueOrNull?.isOwnerOrAdmin == true;

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
              children: _visibleNavItems(isOwnerOrAdmin).map((item) {
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

class _SidebarHeader extends ConsumerWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _SidebarHeader({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(currentTenantProvider).valueOrNull?.name ?? 'NicePOS';
    return SizedBox(
      height: AppSizes.topBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.point_of_sale, color: AppColors.primary, size: 22),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tenantName,
                style: const TextStyle(
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
  // Sol (aynı sekme) ve sağ (yeni sekme) bölge hover'ı AYRI izlenir: altın SADECE
  // sağ bölge hover olunca çıksın diye (KARAR v1.5 — altın ekonomisi). Sol bölge
  // hover'ı yalnızca mevcut sidebarHover zeminini verir.
  bool _leftHovered = false;
  bool _rightHovered = false;

  // Sağ 1/5: öğeyi YENİ sekmede açar. url_launcher'ın Link'i hash-route + relative
  // uri ile _blank'i web'de güvenilir açmadığı için launchUrl + webOnlyWindowName
  // kullanılır. Hedef URL mevcut hash stratejisi korunarak Uri.base'ten türetilir:
  // Uri.base = https://host/nicepos/#/mevcut → fragment'i route ile değiştir →
  // https://host/nicepos/#/sales (path /nicepos/ korunur, fragment '#' olmadan verilir).
  void _openInNewTab() {
    final target = Uri.base.replace(fragment: widget.item.route);
    launchUrl(target, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    // Daraltılmış sidebar (56px, ikon-only): çift-bölge KAPALI → tek Link (aynı
    // sekme). Yeni-sekme bölgesi yalnız genişletilmiş modda görünür (1/5 ≈ 9px
    // tıklanamaz olurdu). KARAR v1.5.
    return widget.expanded ? _buildExpanded() : _buildCollapsed();
  }

  // Daraltılmış: tek buton, tek Link, ikon-only (eski davranış birebir).
  Widget _buildCollapsed() {
    final bgColor = widget.selected
        ? AppColors.sidebarSelectedBg
        : _leftHovered
            ? AppColors.sidebarHover
            : Colors.transparent;
    final iconColor = widget.selected ? AppColors.sidebarTextActive : AppColors.sidebarText;

    return Tooltip(
      message: widget.item.label,
      preferBelow: false,
      child: Link(
        uri: Uri(path: widget.item.route),
        builder: (context, followLink) => MouseRegion(
          onEnter: (_) => setState(() => _leftHovered = true),
          onExit: (_) => setState(() => _leftHovered = false),
          child: GestureDetector(
            onTap: followLink,
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
              child: Icon(widget.item.icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  // Genişletilmiş: çift-bölge. Tek radius'lu ortak kapsayıcı (seçili altın sol
  // şerit + ortak zemin) içinde 0px gap ile iki bitişik tıklama bölgesi → "tek
  // buton" hissi. ClipRRect ile köşeler ortak; IntrinsicHeight ile sağ bölge sol
  // bölgenin yüksekliğine uzar (gold hover fill boşluksuz dolar).
  //
  //  - Sol (~4/5): Link (url_launcher) → followLink → uygulama içi (SPA) navigasyon;
  //    tam sayfa yenilenmez. uri: Uri(path: route) → HASH stratejisi + base-href
  //    /nicepos/ ile href '/nicepos/#/sales' üretilir. (Aynı sekme — DEĞİŞMEDİ.)
  //  - Sağ (~1/5): launchUrl(Uri.base.replace(fragment: route), webOnlyWindowName:
  //    '_blank') → yeni sekme. Link + _blank web'de güvenilir olmadığı için
  //    launchUrl kullanılır (bkz. _openInNewTab).
  Widget _buildExpanded() {
    final iconColor = widget.selected ? AppColors.sidebarTextActive : AppColors.sidebarText;
    final textColor = iconColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.selected ? AppColors.sidebarSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: widget.selected
            ? const Border(left: BorderSide(color: AppColors.goldLight, width: 3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Sol ~4/5: aynı sekmede aç (mevcut SPA navigasyon) ---
              Expanded(
                flex: 4,
                child: Link(
                  uri: Uri(path: widget.item.route),
                  builder: (context, followLink) => MouseRegion(
                    onEnter: (_) => setState(() => _leftHovered = true),
                    onExit: (_) => setState(() => _leftHovered = false),
                    child: GestureDetector(
                      onTap: followLink,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        // Seçili değilken sol hover → sidebarHover; seçiliyken ortak
                        // kapsayıcının sidebarSelectedBg zemini korunur (altın YOK).
                        color: (_leftHovered && !widget.selected)
                            ? AppColors.sidebarHover
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(widget.item.icon, color: iconColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.item.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                  fontWeight:
                                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // --- Sağ ~1/5: yeni sekmede aç (web'de _blank) ---
              // Dinlenme: yalnız soluk ↗ ikonu, ayraç YOK, altın YOK (token v1.5.1:
              // beyaz dikey divider hairline lacivert zeminde "tek buton" hissini
              // bozuyordu). Hover: sağ bölge zemini düşük alfa altına döner + ↗ altına döner.
              // launchUrl + webOnlyWindowName '_blank' (Link yerine) → güvenilir yeni sekme.
              Expanded(
                flex: 1,
                child: Tooltip(
                  message: 'Yeni sekmede aç',
                  preferBelow: false,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _rightHovered = true),
                    onExit: (_) => setState(() => _rightHovered = false),
                    child: GestureDetector(
                      onTap: _openInNewTab,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _rightHovered
                              ? AppColors.gold.withValues(alpha: 0.20)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          Icons.open_in_new,
                          size: 15,
                          color: _rightHovered
                              ? AppColors.sidebarTextActive
                              : AppColors.sidebarText.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    final tenantName = ref.watch(currentTenantProvider).valueOrNull?.name ?? 'NicePOS';

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.cardBg,
      child: Row(
        children: [
          // Arama kutusu yerine: günün tarihi + canlı saat
          const _LiveClock(),
          const Spacer(),
          // Personel davet + işletme adı düzenleme — yalnız owner/admin
          // (Faz B/C, bkz. staff_invite_dialog.dart / edit_tenant_name_dialog.dart).
          if (membership?.isOwnerOrAdmin == true) ...[
            TextButton.icon(
              onPressed: () =>
                  showEditTenantNameDialog(context, currentName: tenantName),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('İşletme Adı', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
            TextButton.icon(
              onPressed: () => showStaffInviteDialog(context),
              icon: const Icon(Icons.person_add_alt_outlined, size: 16),
              label: const Text('Personel Davet Et', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
          ],
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
          // Mobil çevrimdışı ürün senkronu — bir Android tablet yatayda bu
          // "masaüstü" `_TopBar`'ı render edebileceğinden `!kIsWeb` guard'ı
          // burada da geçerli (bkz. `initState` notu).
          if (!kIsWeb) ...[
            const SyncStatusBadge(),
            const SizedBox(width: 4),
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
