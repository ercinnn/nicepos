import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/store_category.dart';

// Sol filtre sidebar'ı (design-tokens.md §15) — yalnız masaüstünde (`lg`,
// >=1024) `home_screen.dart` tarafından gösterilir; dar ekranlarda mevcut
// yatay kategori chip şeridi (§7) korunur. Editoryal dikey liste — pill/chip
// DEĞİL, sol kenarlıklı seçili-durum vurgusuyla düz metin listesi.
class FilterSidebar extends StatelessWidget {
  final List<StoreCategory> categories;
  final String? selectedGroupId;
  final ValueChanged<String?> onSelect;

  static const double width = 256; // w-64

  const FilterSidebar({
    super.key,
    required this.categories,
    required this.selectedGroupId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: StoreColors.pageBg,
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KATEGORİLER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: StoreColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            _FilterRow(
              label: 'Tümü',
              selected: selectedGroupId == null,
              onTap: () => onSelect(null),
            ),
            for (final category in categories)
              _FilterRow(
                label: category.name,
                selected: selectedGroupId == category.id,
                onTap: () => onSelect(category.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? StoreColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? StoreColors.textPrimary
                    : StoreColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
