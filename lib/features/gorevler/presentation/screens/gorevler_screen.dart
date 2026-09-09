import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/instrument_hero.dart';
import '../../../home/application/dashboard_provider.dart';
import '../../../reports/presentation/screens/daily_report_screen.dart' show ReportEmptyCard;
import '../../application/gorevler_provider.dart';
import '../../data/models/gorev_item.dart';

/// Görevler — dün satılan ürünlerin raf-kontrol listesi. Uygulama o gün ilk
/// açıldığında otomatik gösterilir (bkz. `AppScaffold._maybeRedirectToGorevler`),
/// ayrıca kalıcı bir menü öğesi olarak da erişilebilir. Tamamlanma sunucuda
/// tutulur (`gorev_tamamlamalar`) — aynı (paylaşılan) kullanıcı başka bir
/// cihazdan girdiğinde Tamamlananlar sekmesinde aynı durumu görür.
class GorevlerScreen extends ConsumerWidget {
  const GorevlerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaySummaryProvider);
    final gorevlerAsync = ref.watch(gorevlerControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Görevler', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space4),
        const Text(
          'Dün satılan ürünleri kontrol edip rafları tamamlayın.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSizes.space16),
        // İmza: günlük ciro hero'su (Anasayfa/Raporlar ile BİREBİR aynı rakam,
        // `todaySummaryProvider`) — ışıltısız, statik `InstrumentHero` (§6.3).
        todayAsync.when(
          data: (d) => InstrumentHero(label: 'BUGÜNKÜ CİRO · ₺', amount: d.revenue),
          loading: () => const _GorevlerHeroPlaceholder(),
          error: (e, s) => const _GorevlerHeroPlaceholder(hata: true),
        ),
        const SizedBox(height: AppSizes.space20),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.primary,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.checklist_outlined, size: 18),
                        text: 'Yapılacaklar'
                            '${gorevlerAsync.valueOrNull != null ? ' (${gorevlerAsync.valueOrNull!.where((i) => !i.tamamlandi).length})' : ''}',
                      ),
                      Tab(
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        text: 'Tamamlananlar'
                            '${gorevlerAsync.valueOrNull != null ? ' (${gorevlerAsync.valueOrNull!.where((i) => i.tamamlandi).length})' : ''}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _GorevlerListesi(
                        async: gorevlerAsync,
                        tamamlandi: false,
                        bosMesaj:
                            'Bugün için kontrol edilecek ürün yok — dün satış olmamış ya da tüm raflar zaten tamamlanmış.',
                      ),
                      _GorevlerListesi(
                        async: gorevlerAsync,
                        tamamlandi: true,
                        bosMesaj: 'Bugün henüz tamamlanan görev yok.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [tamamlandi] durumuna göre filtrelenmiş liste — Yapılacaklar/Tamamlananlar
/// sekmeleri AYNI provider'ı paylaşır, yalnız süzgeç ters.
class _GorevlerListesi extends ConsumerWidget {
  final AsyncValue<List<GorevItem>> async;
  final bool tamamlandi;
  final String bosMesaj;

  const _GorevlerListesi({
    required this.async,
    required this.tamamlandi,
    required this.bosMesaj,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      data: (items) {
        final filtreli = items.where((i) => i.tamamlandi == tamamlandi).toList();
        if (filtreli.isEmpty) {
          return SingleChildScrollView(child: ReportEmptyCard(bosMesaj));
        }
        return SingleChildScrollView(
          child: Column(
            children: filtreli
                .map((item) => _GorevRow(
                      key: ValueKey(item.productId),
                      item: item,
                      initiallyChecked: tamamlandi,
                      onToggle: () {
                        final notifier = ref.read(gorevlerControllerProvider.notifier);
                        if (tamamlandi) {
                          notifier.geriAl(item.productId);
                        } else {
                          notifier.tamamla(item.productId);
                        }
                      },
                    ))
                .toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => SingleChildScrollView(
        child: ReportEmptyCard('Görevler yüklenemedi: $e'),
      ),
    );
  }
}

/// Hero yüklenirken/hata durumunda hero ile AYNI koyu enstrüman yüzeyini
/// gösteren yer tutucu (`_KasaHeroPlaceholder` ile aynı desen — layout
/// sıçraması olmaz).
class _GorevlerHeroPlaceholder extends StatelessWidget {
  final bool hata;
  const _GorevlerHeroPlaceholder({this.hata = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 116,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space20),
      decoration: instrumentPanelDecoration(),
      child: hata
          ? const Text('—', style: TextStyle(color: Colors.white, fontSize: 24))
          : const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
    );
  }
}

/// Tek görev satırı — hem Yapılacaklar (tikleyince tamamlanır) hem
/// Tamamlananlar (tikini kaldırınca geri alınır) sekmesinde kullanılır;
/// her iki yönde de kısa bir sönme animasyonuyla listeden çıkar (`onToggle`
/// gerçek sunucu güncellemesini üst provider'a devreder).
class _GorevRow extends StatefulWidget {
  final GorevItem item;
  final bool initiallyChecked;
  final VoidCallback onToggle;

  const _GorevRow({
    super.key,
    required this.item,
    required this.initiallyChecked,
    required this.onToggle,
  });

  @override
  State<_GorevRow> createState() => _GorevRowState();
}

class _GorevRowState extends State<_GorevRow> {
  late bool _checked = widget.initiallyChecked;
  bool _degisiyor = false;

  void _handleTap() {
    if (_degisiyor) return;
    setState(() {
      _checked = !_checked;
      _degisiyor = true;
    });
    Future.delayed(const Duration(milliseconds: 260), widget.onToggle);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _degisiyor ? 0 : 1,
      child: IgnorePointer(
        ignoring: _degisiyor,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSizes.space8),
          decoration: AppSizes.cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space12, vertical: AppSizes.space6),
          child: Row(
            children: [
              Checkbox(
                value: _checked,
                onChanged: (_) => _handleTap(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (widget.item.barcode != null)
                      Text(
                        widget.item.barcode!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    if (widget.item.completedAt != null)
                      Text(
                        '${DateFormat('HH:mm').format(widget.item.completedAt!)} tamamlandı',
                        style: const TextStyle(fontSize: 11, color: AppColors.success),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.space8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Text(
                  '${formatNumber(widget.item.quantity)} adet',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
