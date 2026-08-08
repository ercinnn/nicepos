import 'package:flutter/material.dart';

import '../core/theme.dart';

// Breadcrumb örüntüsü — design-tokens.md §8. Gold KULLANILMAZ; son segment
// mevcut sayfayı temsil eder ve tıklanamaz.
class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbSegment({required this.label, this.onTap});
}

class StoreBreadcrumb extends StatelessWidget {
  final List<BreadcrumbSegment> segments;

  const StoreBreadcrumb({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: StoreColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        );
      }
      final isLast = i == segments.length - 1;
      children.add(_BreadcrumbItem(segment: segments[i], active: isLast));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // space.md
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children),
    );
  }
}

class _BreadcrumbItem extends StatefulWidget {
  final BreadcrumbSegment segment;
  final bool active;

  const _BreadcrumbItem({required this.segment, required this.active});

  @override
  State<_BreadcrumbItem> createState() => _BreadcrumbItemState();
}

class _BreadcrumbItemState extends State<_BreadcrumbItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Son segment (mevcut sayfa) tıklanamaz — aktifse onTap'i olsa bile yok
    // sayılır.
    final clickable = !widget.active && widget.segment.onTap != null;
    final text = Text(
      widget.segment.label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
        color: widget.active
            ? StoreColors.textPrimary
            : (_hovered ? StoreColors.textPrimary : StoreColors.textMuted),
      ),
    );
    if (!clickable) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.segment.onTap,
        child: text,
      ),
    );
  }
}
