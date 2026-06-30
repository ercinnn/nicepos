import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../../../features/products/data/models/product_group.dart';
import '../../application/sales_cart_notifier.dart';

class QuickProductsPanel extends ConsumerStatefulWidget {
  const QuickProductsPanel({super.key});

  @override
  ConsumerState<QuickProductsPanel> createState() => _QuickProductsPanelState();
}

class _QuickProductsPanelState extends ConsumerState<QuickProductsPanel> {
  ProductGroup? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(productGroupsProvider);

    return groupsAsync.when(
      loading: () => const BrandLoader(),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (groups) {
        // Sadece show_on_sales_page=true olanları göster
        final salesGroups = groups.where((g) => g.showOnSalesPage).toList();
        if (salesGroups.isEmpty) {
          return const Center(
            child: Text(
              'Hızlı satış için grup yok.\nÜrün gruplarından "Satış sayfasında göster" aktif edin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        // İlk grubu seç (başlangıçta)
        _selectedGroup ??= salesGroups.first;

        // Seçili grubun hâlâ listede olduğunu kontrol et
        final stillExists = salesGroups.any((g) => g.id == _selectedGroup?.id);
        if (!stillExists) _selectedGroup = salesGroups.first;

        return Column(
          children: [
            // Grup sekmeleri
            Container(
              height: 40,
              color: AppColors.cardBg,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space8, vertical: AppSizes.space4),
                itemCount: salesGroups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final group = salesGroups[i];
                  final selected = _selectedGroup?.id == group.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGroup = group),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space12, vertical: AppSizes.space4),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Ürün grid
            Expanded(
              child: _selectedGroup == null
                  ? const SizedBox()
                  : _ProductList(groupId: _selectedGroup!.id),
            ),
          ],
        );
      },
    );
  }
}

class _ProductList extends ConsumerWidget {
  final String groupId;
  const _ProductList({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByGroupProvider(groupId));

    return productsAsync.when(
      loading: () => const SkeletonList(itemCount: 5, itemHeight: 44),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Text('Bu grupta ürün yok.', style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) {
            final product = products[i];
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(salesCartProvider.notifier).addProduct(product);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space12, vertical: AppSizes.space8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.barcode != null && product.barcode!.isNotEmpty)
                            SelectableText(
                              product.barcode!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatCurrency(product.price1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
