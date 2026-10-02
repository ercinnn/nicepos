import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../audit/data/repositories/audit_log_repository.dart';
import '../../../sales/application/concept_cache.dart';
import '../../application/concept_products_provider.dart';
import '../../data/models/concept_product.dart';
import '../widgets/concept_form_dialog.dart';

/// Konsept Ürünler — birden çok parçadan oluşan, tek barkodla satılan setler
/// (bkz. 0067_concept_products.sql). Konseptlerin kendi stoku yoktur, Ürünler
/// listesinde görünmez; satışta okutulunca parçalar sepete eklenir.
class ConceptProductsScreen extends ConsumerStatefulWidget {
  const ConceptProductsScreen({super.key});

  @override
  ConsumerState<ConceptProductsScreen> createState() => _ConceptProductsScreenState();
}

class _ConceptProductsScreenState extends ConsumerState<ConceptProductsScreen> {
  String _query = '';

  Future<void> _openForm([ConceptProduct? concept]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConceptFormDialog(concept: concept),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(concept == null ? 'Konsept eklendi.' : 'Konsept güncellendi.')));
    }
  }

  Future<void> _delete(ConceptProduct c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konsepti Sil'),
        content: Text('"${c.name}" (${c.barcode}) silinsin mi?\n'
            'Parça ürünler ve stokları etkilenmez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(conceptRepositoryProvider).delete(c.id);
      unawaited(AuditLogRepository().log(
        action: 'concept.delete',
        entityType: 'concept_product',
        entityId: c.id,
        summary: '${c.barcode} ${c.name}',
      ));
      ref.invalidate(conceptProductsProvider);
      ref.invalidate(conceptCacheProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${c.name}" silindi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final conceptsAsync = ref.watch(conceptProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Text('Konsept Ürünler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Konsept'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Konsept barkodu satışta okutulunca parçalar sepete eklenir ve stokları parçalardan düşer. '
          'Konseptin ayrıca stoku tutulmaz.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Konsept adı veya barkodu ara...',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: conceptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (concepts) {
              final filtered = _query.isEmpty
                  ? concepts
                  : concepts
                      .where((c) =>
                          c.name.toLowerCase().contains(_query) ||
                          c.barcode.toLowerCase().contains(_query))
                      .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    concepts.isEmpty ? 'Henüz konsept ürün eklenmemiş.' : 'Aramaya uyan konsept yok.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(conceptProductsProvider.future),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ConceptCard(
                    concept: filtered[i],
                    onEdit: () => _openForm(filtered[i]),
                    onDelete: () => _delete(filtered[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final ConceptProduct concept;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConceptCard({required this.concept, required this.onEdit, required this.onDelete});

  static String _fmtQty(num q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final c = concept;
    final total = c.componentsTotal;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    SelectableText(
                      c.barcode,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final i in c.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${_fmtQty(i.quantity)} × ${i.product?.name ?? 'Silinmiş ürün'}'
                          '${i.product?.barcode != null ? '  (${i.product!.barcode})' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCurrency(c.effectivePrice),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      )),
                  if (c.price != null && c.price != total)
                    Text('Parça toplamı ${formatCurrency(total)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        )),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Düzenle',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
