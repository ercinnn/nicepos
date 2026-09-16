import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../audit/data/repositories/audit_log_repository.dart';
import '../../application/products_provider.dart';
import '../../data/models/ai_group_suggestion.dart';
import '../../data/models/product_group.dart';

/// "AI ile Grupla" — grubu boş ürünler için `suggest_product_groups` RPC'sinin
/// (0063_product_group_suggestions.sql, pg_trgm tabanlı k-NN sınıflandırıcı)
/// önerilerini gösterir. Harici bir API çağrısı YOK — tamamen sunucu tarafında
/// tek bir SQL fonksiyonu, kullanıcının kendi ürün kataloğuyla "öğrenir".
/// Kullanıcı öneriyi gözden geçirip onaylar/düzeltir, sonra toplu uygulanır.
class AiGroupingDialog extends ConsumerStatefulWidget {
  /// Ekrandaki o anki arama/filtre kriterlerine uyan, grubu boş ürünlerin
  /// id kümesi (bkz. products_list_screen.dart çağrı noktası — `fetchAll`
  /// Excel Aktar ile AYNI desende, `_query`/`_selectedGroupId`/`_filters`
  /// geçirilerek hesaplanır). AI önerileri ve "Sınıflandırılamadı" listesi
  /// bu kümenin DIŞINDAKİ ürünleri dikkate ALMAZ — filtre dışı ürünler
  /// gruplandırma tercihine karışmaz.
  final Set<String> candidateProductIds;

  const AiGroupingDialog({super.key, required this.candidateProductIds});

  @override
  ConsumerState<AiGroupingDialog> createState() => _AiGroupingDialogState();
}

class _AiGroupingDialogState extends ConsumerState<AiGroupingDialog> {
  final Set<String> _approved = {};
  final Map<String, String> _overrides = {};
  bool _initializedApproval = false;
  bool _applying = false;
  String? _resultMessage;

  // Düşük güvenli (<%35 — RPC'nin p_min_similarity tabanıyla AYNI eşik)
  // öneriler varsayılan olarak İŞARETSİZ bırakılır — kısa/az bilgilendirici
  // ürün adlarında trigram benzerliği yanıltıcı yüksek çıkabilir, kullanıcı
  // bilinçli onaylasın. Eşik önceden %50'ydi (kullanıcı isteğiyle düşürüldü).
  static const _autoApproveThreshold = 0.35;

  void _initApprovalIfNeeded(List<AiGroupSuggestion> suggestions) {
    if (_initializedApproval) return;
    _initializedApproval = true;
    for (final s in suggestions) {
      if (s.confidence >= _autoApproveThreshold) _approved.add(s.productId);
    }
  }

  void _refresh() {
    _initializedApproval = false;
    _approved.clear();
    _overrides.clear();
    setState(() => _resultMessage = null);
    ref.invalidate(aiGroupSuggestionsProvider);
    ref.invalidate(unassignedGroupProductsProvider);
  }

  Future<void> _apply(List<AiGroupSuggestion> suggestions) async {
    final map = <String, String>{};
    for (final s in suggestions) {
      if (!_approved.contains(s.productId)) continue;
      map[s.productId] = _overrides[s.productId] ?? s.suggestedGroupId;
    }
    if (map.isEmpty) return;

    setState(() => _applying = true);
    final result = await ref.read(productRepositoryProvider).bulkAssignGroups(map);
    if (!mounted) return;

    unawaited(AuditLogRepository().log(
      action: 'product.ai_group_bulk_assign',
      entityType: 'product',
      entityId: 'bulk',
      summary: '${result.updated} ürün AI önerisiyle gruplandı',
    ));

    ref.invalidate(productGroupsProvider);
    ref.invalidate(aiGroupSuggestionsProvider);
    ref.invalidate(unassignedGroupProductsProvider);

    setState(() {
      _applying = false;
      _initializedApproval = false;
      _approved.clear();
      _overrides.clear();
      _resultMessage = result.failed > 0
          ? '${result.updated} ürün gruplandı, ${result.failed} üründe hata oluştu.'
          : '${result.updated} ürün gruplandı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(aiGroupSuggestionsProvider);
    final unassignedAsync = ref.watch(unassignedGroupProductsProvider);
    final groups = ref.watch(productGroupsProvider).valueOrNull ?? const <ProductGroup>[];

    // Yalnız ekrandaki o anki arama/filtreye uyan ürünler dikkate alınır —
    // filtre dışı kalan ürünler için üretilen öneriler (RPC tüm etiketsiz
    // ürünler için hesaplar) burada elenir. `actions`'taki "Uygula" butonu
    // da bu filtrelenmiş listeyi kullanır.
    final rawSuggestions = suggestionsAsync.valueOrNull;
    final filteredSuggestions = (rawSuggestions == null || widget.candidateProductIds.isEmpty)
        ? const <AiGroupSuggestion>[]
        : rawSuggestions.where((s) => widget.candidateProductIds.contains(s.productId)).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
          const SizedBox(width: AppSizes.space8),
          const Expanded(child: Text('AI ile Grupla')),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _applying ? null : _refresh,
          ),
        ],
      ),
      content: SizedBox(
        width: 820,
        height: 560,
        child: suggestionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Hata: $e', style: const TextStyle(color: AppColors.danger)),
          ),
          data: (_) {
            final suggestions = filteredSuggestions;
            _initApprovalIfNeeded(suggestions);
            final unassigned = unassignedAsync.valueOrNull;
            final suggestedIds = suggestions.map((s) => s.productId).toSet();
            final unclassified = unassigned == null
                ? const <Map<String, String>>[]
                : unassigned
                    .where((p) =>
                        !suggestedIds.contains(p['id']) && widget.candidateProductIds.contains(p['id']))
                    .toList();

            if (widget.candidateProductIds.isEmpty) {
              return const EmptyState(
                icon: Icons.psychology_outlined,
                title: 'Aday ürün yok',
                message: 'Geçerli arama/filtreye uyan, grubu boş bir ürün yok. '
                    'Filtreleri değiştirip tekrar deneyin.',
              );
            }

            if (suggestions.isEmpty) {
              return EmptyState(
                icon: Icons.psychology_outlined,
                title: 'Öneri üretilemedi',
                message: (unassigned != null &&
                        !unassigned.any((p) => widget.candidateProductIds.contains(p['id'])))
                    ? 'Filtrelenmiş ürünler arasında grubu boş ürün yok — hepsi zaten gruplanmış.'
                    : 'Filtrelenmiş ürünler arasında yeterince benzer, zaten gruplanmış bir ürün '
                        'bulunamadı. Önce birkaç ürünü elle gruplandırın, AI bunlardan öğrenir.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_resultMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.space12),
                    margin: const EdgeInsets.only(bottom: AppSizes.space12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _resultMessage!,
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(
                  '${suggestions.length} öneri bulundu (güveni %35\'in altında olanlar varsayılan seçili değil).',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSizes.space8),
                Expanded(
                  child: ListView.separated(
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final s = suggestions[index];
                      return _SuggestionRow(
                        suggestion: s,
                        approved: _approved.contains(s.productId),
                        overrideGroupId: _overrides[s.productId],
                        groups: groups,
                        onToggle: (v) => setState(() {
                          if (v) {
                            _approved.add(s.productId);
                          } else {
                            _approved.remove(s.productId);
                          }
                        }),
                        onOverride: (groupId) => setState(() {
                          _overrides[s.productId] = groupId;
                          _approved.add(s.productId);
                        }),
                      );
                    },
                  ),
                ),
                if (unclassified.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.space8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Sınıflandırılamadı (${unclassified.length})',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView(
                          shrinkWrap: true,
                          children: unclassified
                              .map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '• ${p['name']}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          onPressed: _applying || rawSuggestions == null || _approved.isEmpty
              ? null
              : () => _apply(filteredSuggestions),
          icon: _applying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text('Seçilenleri Uygula (${_approved.length})'),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final AiGroupSuggestion suggestion;
  final bool approved;
  final String? overrideGroupId;
  final List<ProductGroup> groups;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onOverride;

  const _SuggestionRow({
    required this.suggestion,
    required this.approved,
    required this.overrideGroupId,
    required this.groups,
    required this.onToggle,
    required this.onOverride,
  });

  // Bir grubun "üst grup"u: kendi parentGroupId'si varsa o, yoksa (kendisi
  // zaten üst-seviye bir grupsa) kendi id'si — `productGroupsProvider`'daki
  // HER satır (üst-seviye dahil) tek düz listede geldiğinden bu şekilde
  // türetiliyor, ayrı bir "üst gruplar" sorgusu gerekmiyor.
  static String _rootIdOf(ProductGroup g) => g.parentGroupId ?? g.id;

  ProductGroup? _findGroup(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroupId = overrideGroupId ?? suggestion.suggestedGroupId;
    final selectedGroup = _findGroup(selectedGroupId);
    final rootId = selectedGroup == null ? null : _rootIdOf(selectedGroup);

    final rootOptions = groups.where((g) => g.parentGroupId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Bir üst grubun "Grup" seçenekleri: kendisi (alt grubu olmayan/doğrudan
    // atanan ürünler için) + doğrudan çocukları.
    final childOptions = rootId == null
        ? const <ProductGroup>[]
        : (groups.where((g) => g.id == rootId || g.parentGroupId == rootId).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: approved, onChanged: (v) => onToggle(v ?? false)),
          const SizedBox(width: AppSizes.space8),
          Expanded(
            flex: 3,
            child: Text(
              suggestion.productName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          // Üst Grup seçimi kendi kendini yansıtır (yalnız kullanıcı bu
          // dropdown'dan seçince değişir) — sabit key, dış etkenle
          // yeniden kurulmaz.
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                key: ValueKey('root-${suggestion.productId}'),
                width: constraints.maxWidth,
                initialSelection: rootId,
                enableFilter: true,
                requestFocusOnTap: true,
                label: const Text('Üst Grup', style: TextStyle(fontSize: 11)),
                textStyle: const TextStyle(fontSize: 12),
                inputDecorationTheme: const InputDecorationTheme(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                dropdownMenuEntries: rootOptions
                    .map((g) => DropdownMenuEntry<String>(value: g.id, label: g.name))
                    .toList(),
                onSelected: (v) {
                  // Üst grup değişince varsayılan olarak üst grubun
                  // KENDİSİ seçilir — "Grup" dropdown'u bunu bir alt grup
                  // seçenekleri arasından değiştirebilir.
                  if (v != null) onOverride(v);
                },
              ),
            ),
          ),
          const SizedBox(width: AppSizes.space8),
          // Grup seçenekleri seçili üst gruba göre değişir — üst grup
          // değiştiğinde `key` de değişip dropdown'u güncel seçenek/değerle
          // yeniden kurar (aksi halde eski üst gruba ait bir seçim ekranda
          // asılı kalabilirdi).
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                key: ValueKey('group-${suggestion.productId}-$rootId'),
                width: constraints.maxWidth,
                enabled: childOptions.isNotEmpty,
                initialSelection: childOptions.any((g) => g.id == selectedGroupId) ? selectedGroupId : null,
                enableFilter: true,
                requestFocusOnTap: true,
                label: const Text('Grup', style: TextStyle(fontSize: 11)),
                textStyle: const TextStyle(fontSize: 12),
                inputDecorationTheme: const InputDecorationTheme(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                dropdownMenuEntries: childOptions
                    .map((g) => DropdownMenuEntry<String>(value: g.id, label: g.name))
                    .toList(),
                onSelected: (v) {
                  if (v != null) onOverride(v);
                },
              ),
            ),
          ),
          const SizedBox(width: AppSizes.space8),
          Tooltip(
            message: suggestion.sampleMatches.isEmpty
                ? 'Eşleşen örnek yok'
                : 'Benzer bulunan ürünler: ${suggestion.sampleMatches}',
            child: _ConfidenceBadge(confidence: suggestion.confidence),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (confidence >= 0.8) {
      color = AppColors.success;
    } else if (confidence >= 0.35) {
      color = AppColors.warning;
    } else {
      color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '%${(confidence * 100).round()}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
