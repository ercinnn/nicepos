import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/product_group.dart';
import '../../application/products_provider.dart';
import '../widgets/product_group_form_dialog.dart';

class ProductGroupsScreen extends ConsumerWidget {
  const ProductGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(productGroupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Ürün Grupları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Grup Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: groupsAsync.when(
              data: (groups) => _GroupsTable(groups: groups, onEdit: (g) => _openForm(context, ref, g)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, ProductGroup? group) async {
    final groups = ref.read(productGroupsProvider).value ?? [];
    await showDialog(
      context: context,
      builder: (_) => ProductGroupFormDialog(group: group, allGroups: groups),
    );
    ref.invalidate(productGroupsProvider);
  }
}

class _GroupsTable extends ConsumerWidget {
  final List<ProductGroup> groups;
  final void Function(ProductGroup) onEdit;

  const _GroupsTable({required this.groups, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groups.isEmpty) {
      return const Center(child: Text('Henüz ürün grubu eklenmemiş.'));
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Grup Adı')),
            DataColumn(label: Text('Üst Grup')),
            DataColumn(label: Text('Satış Sayfası')),
            DataColumn(label: Text('Fiyat Listesi')),
            DataColumn(label: Text('Gruptaki Toplam Ürün')),
            DataColumn(label: Text('İşlem')),
          ],
          rows: List.generate(groups.length, (i) {
            final g = groups[i];
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(g.name)),
              DataCell(Text(g.parentGroupName ?? '-')),
              DataCell(Icon(
                g.showOnSalesPage ? Icons.check_circle : Icons.remove_circle_outline,
                size: 18,
                color: g.showOnSalesPage ? AppColors.success : AppColors.textMuted,
              )),
              DataCell(Icon(
                g.showOnPriceList ? Icons.check_circle : Icons.remove_circle_outline,
                size: 18,
                color: g.showOnPriceList ? AppColors.success : AppColors.textMuted,
              )),
              DataCell(Text('${g.productCount}')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(g),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: AppColors.danger),
                    onPressed: () => _delete(context, ref, g),
                  ),
                ],
              )),
            ]);
          }),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProductGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Grubu Sil'),
        content: Text('"${g.name}" grubunu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(productGroupRepositoryProvider).delete(g.id);
      ref.invalidate(productGroupsProvider);
    }
  }
}
