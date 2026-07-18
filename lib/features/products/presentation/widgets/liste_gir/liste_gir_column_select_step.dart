import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/models/liste_gir/column_band.dart';
import '../../../data/models/liste_gir/column_type.dart';
import '../../../data/models/liste_gir/rendered_page.dart';

/// Sütun/dikdörtgen seçim adımı: render edilmiş sayfa görüntüsü üstünde
/// kullanıcı renkli bantlar çizer (KARAR: sütun başına tek bant, yalnız
/// X-aralığı — yükseklik otomatik tam sayfa boyu).
///
/// `bands` üst widget'ın (ListeGirScreen) sahip olduğu paylaşılan map —
/// bu widget doğrudan içine yazar ve her değişiklikte [onBandsChanged] çağırır
/// (iki ayrı state kopyası tutmamak için bilinçli tercih).
class ListeGirColumnSelectStep extends StatefulWidget {
  final RenderedPage page1;
  final int numPages;
  final Future<RenderedPage> Function(int pageNum) onLoadPreviewPage;
  final Map<ColumnType, ColumnBand> bands;
  final VoidCallback onBandsChanged;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const ListeGirColumnSelectStep({
    super.key,
    required this.page1,
    required this.numPages,
    required this.onLoadPreviewPage,
    required this.bands,
    required this.onBandsChanged,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<ListeGirColumnSelectStep> createState() => _ListeGirColumnSelectStepState();
}

class _ListeGirColumnSelectStepState extends State<ListeGirColumnSelectStep> {
  ColumnType? _armed;
  int _previewPageNum = 1;
  RenderedPage? _previewPage;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _previewPage = widget.page1;
  }

  bool get _isPage1 => _previewPageNum == 1;

  bool get _canConfirm =>
      widget.bands.containsKey(ColumnType.name) &&
      widget.bands.containsKey(ColumnType.quantity) &&
      widget.bands.containsKey(ColumnType.purchasePrice);

  Future<void> _goToPage(int pageNum) async {
    if (pageNum == _previewPageNum) return;
    if (pageNum == 1) {
      setState(() {
        _previewPageNum = 1;
        _previewPage = widget.page1;
      });
      return;
    }
    setState(() => _loadingPreview = true);
    final page = await widget.onLoadPreviewPage(pageNum);
    if (!mounted) return;
    setState(() {
      _previewPageNum = pageNum;
      _previewPage = page;
      _loadingPreview = false;
    });
  }

  void _onPanStart(DragStartDetails d) {
    final type = _armed;
    if (type == null || !_isPage1) return;
    final x = d.localPosition.dx.clamp(0.0, widget.page1.width);
    setState(() => widget.bands[type] = ColumnBand(type: type, left: x, right: x));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final type = _armed;
    if (type == null || !_isPage1) return;
    final band = widget.bands[type];
    if (band == null) return;
    setState(() => band.right = d.localPosition.dx.clamp(0.0, widget.page1.width));
  }

  void _onPanEnd(DragEndDetails d) {
    final type = _armed;
    if (type == null || !_isPage1) return;
    final band = widget.bands[type];
    if (band == null) return;
    if (band.left > band.right) {
      final tmp = band.left;
      band.left = band.right;
      band.right = tmp;
    }
    widget.onBandsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final page = _previewPage!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Renkli çiplerden birine dokunun, sonra görüntü üzerinde ilgili sütunun '
          'genişliğini sürükleyerek işaretleyin. Barkod isteğe bağlıdır.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        _buildChipsRow(),
        const SizedBox(height: 12),
        if (widget.numPages > 1) _buildPageNav(),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
            child: _loadingPreview
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: page.width,
                        height: page.height,
                        child: Stack(
                          children: [
                            Image.memory(page.imageBytes, width: page.width, height: page.height),
                            for (final band in widget.bands.values)
                              Positioned(
                                left: band.lo,
                                top: 0,
                                width: (band.hi - band.lo).clamp(0.0, page.width),
                                height: page.height,
                                child: IgnorePointer(
                                  child: Container(color: band.type.color.withValues(alpha: 0.22)),
                                ),
                              ),
                            if (_isPage1)
                              Positioned.fill(
                                child: MouseRegion(
                                  cursor: _armed != null ? SystemMouseCursors.precise : SystemMouseCursors.basic,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanStart: _onPanStart,
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
                                  ),
                                ),
                              ),
                            if (_isPage1)
                              for (final band in widget.bands.values) ...[
                                _edgeHandle(band, isLeft: true, pageHeight: page.height, pageWidth: page.width),
                                _edgeHandle(band, isLeft: false, pageHeight: page.height, pageWidth: page.width),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(onPressed: widget.onBack, child: const Text('Geri')),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _canConfirm ? widget.onConfirm : null,
              icon: const Icon(Icons.check),
              label: const Text('Sütunları Onayla'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _edgeHandle(ColumnBand band, {required bool isLeft, required double pageHeight, required double pageWidth}) {
    final x = isLeft ? band.left : band.right;
    return Positioned(
      left: (x - 4).clamp(0.0, pageWidth - 8),
      top: 0,
      width: 8,
      height: pageHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            setState(() {
              if (isLeft) {
                band.left = (band.left + d.delta.dx).clamp(0.0, band.right - 4);
              } else {
                band.right = (band.right + d.delta.dx).clamp(band.left + 4, pageWidth);
              }
            });
          },
          onPanEnd: (_) => widget.onBandsChanged(),
          child: Container(color: band.type.color.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _buildChipsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final type in ColumnType.values) _buildChip(type)],
    );
  }

  Widget _buildChip(ColumnType type) {
    final armed = _armed == type;
    final band = widget.bands[type];
    return InkWell(
      onTap: () => setState(() => _armed = armed ? null : type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: armed ? type.color.withValues(alpha: 0.18) : Colors.white,
          border: Border.all(color: type.color, width: armed ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: type.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (band != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            InkWell(
              onTap: () {
                setState(() {
                  widget.bands.remove(type);
                  if (_armed == type) _armed = null;
                });
                widget.onBandsChanged();
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 14, color: AppColors.textMuted),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildPageNav() {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: _previewPageNum > 1 ? () => _goToPage(_previewPageNum - 1) : null,
      ),
      Text('Sayfa $_previewPageNum / ${widget.numPages}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: _previewPageNum < widget.numPages ? () => _goToPage(_previewPageNum + 1) : null,
      ),
      const SizedBox(width: 8),
      if (!_isPage1)
        const Text(
          '(Yalnız 1. sayfada düzenlenebilir — aynı sütunlar tüm sayfalara uygulanır)',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
        ),
    ]);
  }
}
