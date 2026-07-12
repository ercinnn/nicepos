import 'dart:convert';

import 'package:barcode/barcode.dart' as bc;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';
import '../../../sales/application/barcode_cache.dart';
import '../../application/labels_provider.dart';
import '../../data/models/label_slot.dart';
import '../widgets/etiket_print.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Etiket (raf etiketi A4 yazdırma) ekranı — KARAR v1.10
//
// Araç/çalışma ekranı (stok listesi token dili; EKRAN HERO'SU YOK). İki bölge:
//   SOL  = 24 haneli barkod giriş sütunu (barkod okut → Enter → ürün çözülür,
//          imleç bir alt haneye geçer; satış ekranı _onBarcodeSubmitted deseni).
//   SAĞ  = canlı A4 önizleme (3 sütun × 8 satır = 24 etiket).
// Basılan etiketin kendi hero'su = FİYAT (iri bold, altın ray YOK). App krom'u
// altın/lacivert; baskı çıktısı siyah/beyaz + mağaza logosu (ayrı diller).
// ═══════════════════════════════════════════════════════════════════════════

// A4 önizleme sabit tuvali (96dpi): 210×297mm ≈ 794×1123px. FittedBox ile panele
// ölçeklenir; böylece font/ölçüler tek bir referans ölçekte hesaplanır.
const double _kA4Width = 794;
const double _kA4Height = 1123;

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final Set<int> _errors = {}; // çözülemeyen hane indeksleri (danger uyarı)
  int _activeIndex = 0; // aktif (odaklı) hane — aktif durum altını

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(kLabelCount, (_) => TextEditingController());
    _focusNodes = List.generate(kLabelCount, (i) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus && mounted) setState(() => _activeIndex = i);
      });
      return node;
    });
    // Barkod → Product bellek indeksini bir kez prefetch et (satış ekranıyla
    // paylaşılan keepAlive cache) → okutmada ağ turu beklemeden çözüm.
    ref.read(barcodeCacheProvider).ensureLoaded();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // Barkod okutma → ürün çözümü (satış ekranı _onBarcodeSubmitted birebir
  // uyarlaması): önce bellek cache, sonra fetchByBarcode, sonra fetchAll (tam
  // barkod eşleşmesi tercih edilir). Çözülünce hane dolar + imleç bir alta geçer.
  Future<void> _onSubmitted(int index, String raw) async {
    final query = raw.trim();
    final notifier = ref.read(labelSheetProvider.notifier);
    if (query.isEmpty) {
      notifier.clearSlot(index);
      setState(() => _errors.remove(index));
      return;
    }

    final cache = ref.read(barcodeCacheProvider);
    Product? product = cache.lookup(query);
    if (product == null) {
      final repo = ref.read(productRepositoryProvider);
      product = await repo.fetchByBarcode(query);
      if (product == null) {
        final matches = await repo.fetchAll(query: query);
        for (final p in matches) {
          if (p.barcode == query) {
            product = p;
            break;
          }
        }
        product ??= matches.isNotEmpty ? matches.first : null;
      }
      if (product != null) cache.put(product);
    }

    if (!mounted) return;
    if (product == null) {
      notifier.clearSlot(index);
      setState(() => _errors.add(index));
      return;
    }

    final resolved = product;
    final code = (resolved.barcode != null && resolved.barcode!.isNotEmpty)
        ? resolved.barcode!
        : query;
    notifier.setSlot(
      index,
      LabelSlot(
        barcode: code,
        productName: resolved.name,
        price: resolved.price1,
        createdAt: DateTime.now(),
      ),
    );
    _controllers[index].text = code;
    HapticFeedback.lightImpact();
    setState(() => _errors.remove(index));

    // Otomatik bir alt haneye geç (son hanede kal).
    if (index + 1 < kLabelCount) {
      _focusNodes[index + 1].requestFocus();
      _controllers[index + 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index + 1].text.length,
      );
    }
  }

  void _clearSlot(int index) {
    _controllers[index].clear();
    ref.read(labelSheetProvider.notifier).clearSlot(index);
    setState(() => _errors.remove(index));
    _focusNodes[index].requestFocus();
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    ref.read(labelSheetProvider.notifier).clearAll();
    setState(() => _errors.clear());
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final ext = (file.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    final dataUrl = 'data:$mime;base64,${base64Encode(file.bytes!)}';
    ref.read(labelSheetProvider.notifier).setLogo(dataUrl);
  }

  void _print() {
    final state = ref.read(labelSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    printLabelsA4(slots: state.slots, logoDataUrl: state.logoDataUrl);
  }

  void _pdf() {
    final state = ref.read(labelSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Açılan yazdırma penceresinde hedef olarak "PDF olarak kaydet" seçin.'),
      ),
    );
    printLabelsA4(slots: state.slots, logoDataUrl: state.logoDataUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobile();
    return _buildDesktop();
  }

  // ─── Masaüstü: iki bölge (sol giriş sütunu · sağ A4 önizleme) ──────────────
  Widget _buildDesktop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          filledCount: ref.watch(labelSheetProvider).filledCount,
          hasLogo: ref.watch(labelSheetProvider).logoDataUrl != null,
          onPickLogo: _pickLogo,
          onRemoveLogo: () =>
              ref.read(labelSheetProvider.notifier).setLogo(null),
          onClearAll: _clearAll,
          onPrint: _print,
          onPdf: _pdf,
        ),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOL: 24 haneli barkod giriş sütunu
              Expanded(
                flex: 5,
                child: _InputColumn(
                  controllers: _controllers,
                  focusNodes: _focusNodes,
                  errors: _errors,
                  activeIndex: _activeIndex,
                  onSubmitted: _onSubmitted,
                  onClear: _clearSlot,
                ),
              ),
              const SizedBox(width: AppSizes.space16),
              // SAĞ: canlı A4 önizleme
              Expanded(
                flex: 6,
                child: _PreviewPane(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Mobil: tek kolon (giriş üstte, önizleme altta) ────────────────────────
  Widget _buildMobile() {
    final state = ref.watch(labelSheetProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            filledCount: state.filledCount,
            hasLogo: state.logoDataUrl != null,
            onPickLogo: _pickLogo,
            onRemoveLogo: () =>
                ref.read(labelSheetProvider.notifier).setLogo(null),
            onClearAll: _clearAll,
            onPrint: _print,
            onPdf: _pdf,
            compact: true,
          ),
          const SizedBox(height: AppSizes.space16),
          // Giriş haneleri (iç scroll yok — sayfa scroll'una gömülü)
          ...List.generate(kLabelCount, (i) {
            return _SlotInputRow(
              index: i,
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              isActive: _activeIndex == i,
              isError: _errors.contains(i),
              onSubmitted: (v) => _onSubmitted(i, v),
              onClear: () => _clearSlot(i),
            );
          }),
          const SizedBox(height: AppSizes.space20),
          const _SectionLabel('A4 Önizleme'),
          const SizedBox(height: AppSizes.space8),
          LayoutBuilder(
            builder: (ctx, c) => SizedBox(
              width: c.maxWidth,
              height: c.maxWidth * (_kA4Height / _kA4Width),
              child: _PreviewPane(),
            ),
          ),
          const SizedBox(height: AppSizes.space20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Başlık + aksiyonlar (Yazdır / PDF Üret / Logo / Temizle)
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final int filledCount;
  final bool hasLogo;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onClearAll;
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final bool compact;

  const _Header({
    required this.filledCount,
    required this.hasLogo,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onClearAll,
    required this.onPrint,
    required this.onPdf,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      // Logo yükle
      OutlinedButton.icon(
        onPressed: onPickLogo,
        icon: const Icon(Icons.image_outlined, size: 18),
        label: Text(hasLogo ? 'Logoyu Değiştir' : 'Logo Yükle'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.goldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
        ),
      ),
      if (hasLogo)
        TextButton.icon(
          onPressed: onRemoveLogo,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Logoyu Kaldır'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
        ),
      TextButton.icon(
        onPressed: onClearAll,
        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
        label: const Text('Tümünü Temizle'),
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      ),
      // Yazdırma yalnız web'de (mobil/native no-op).
      if (kIsWeb) ...[
        OutlinedButton.icon(
          onPressed: onPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('PDF Üret'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.goldBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onPrint,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Yazdır'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Etiket',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Text(
                '$filledCount / $kLabelCount etiket',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space4),
        const Text(
          'Barkod okutun; her hane ürün adı + fiyatıyla A4 raf etiketine dönüşür.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSizes.space12),
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sol bölge: 24 haneli barkod giriş sütunu (iç scroll)
// ═══════════════════════════════════════════════════════════════════════════

class _InputColumn extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Set<int> errors;
  final int activeIndex;
  final Future<void> Function(int, String) onSubmitted;
  final void Function(int) onClear;

  const _InputColumn({
    required this.controllers,
    required this.focusNodes,
    required this.errors,
    required this.activeIndex,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(
                left: AppSizes.space4, bottom: AppSizes.space8),
            child: _SectionLabel('Barkod Haneleri'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: kLabelCount,
              itemBuilder: (context, i) {
                return _SlotInputRow(
                  index: i,
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  isActive: activeIndex == i,
                  isError: errors.contains(i),
                  onSubmitted: (v) => onSubmitted(i, v),
                  onClear: () => onClear(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }
}

// Tek hane satırı: [# no] [barkod input] [✕]. Çözülen ürün adı + fiyatı alanın
// altında minik gösterilir; çözülemeyen barkod → danger uyarı.
class _SlotInputRow extends ConsumerWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isActive;
  final bool isError;
  final Future<void> Function(String) onSubmitted;
  final VoidCallback onClear;

  const _SlotInputRow({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.isActive,
    required this.isError,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(
      labelSheetProvider.select((s) => s.slots[index]),
    );

    // Aktif hane = aktif durum altını (izinli: ince sol altın şerit + ink
    // kenarlık, §5). Hata → danger kenarlık.
    final Color borderColor = isError
        ? AppColors.danger
        : isActive
            ? AppColors.primary
            : AppColors.divider;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: borderColor, width: isActive ? 1.4 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aktif sol altın şerit (izinli aktif-durum vurgusu).
            Container(
              width: 3,
              height: 46,
              color: isActive ? AppColors.gold : Colors.transparent,
            ),
            // # numara
            Container(
              width: 28,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Barkod input + çözüm bilgisi
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Barkod okut / gir',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: onSubmitted,
                    ),
                    if (slot != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${slot.productName}  ·  ${formatNumber(slot.price)} TL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      )
                    else if (isError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Ürün bulunamadı.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ✕ temizle
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textMuted,
              tooltip: 'Haneyi temizle',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sağ bölge: canlı A4 önizleme (sabit tuval → FittedBox ile ölçeklenir)
// ═══════════════════════════════════════════════════════════════════════════

class _PreviewPane extends ConsumerWidget {
  const _PreviewPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelSheetProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: _A4Canvas(
            slots: state.slots,
            logoDataUrl: state.logoDataUrl,
          ),
        ),
      ),
    );
  }
}

class _A4Canvas extends StatelessWidget {
  final List<LabelSlot?> slots;
  final String? logoDataUrl;

  const _A4Canvas({required this.slots, required this.logoDataUrl});

  @override
  Widget build(BuildContext context) {
    const margin = 19.0; // ~5mm @96dpi
    // Logo bytes'ı tuval başına bir kez çöz (her hücrede tekrar decode etme).
    Uint8List? logoBytes;
    if (logoDataUrl != null) {
      final i = logoDataUrl!.indexOf(',');
      if (i >= 0) {
        try {
          logoBytes = base64Decode(logoDataUrl!.substring(i + 1));
        } catch (_) {
          logoBytes = null;
        }
      }
    }

    return Container(
      width: _kA4Width,
      height: _kA4Height,
      color: Colors.white,
      padding: const EdgeInsets.all(margin),
      child: Column(
        children: List.generate(kLabelRows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(kLabelColumns, (c) {
                final idx = r * kLabelColumns + c;
                return Expanded(
                  child: _LabelCell(
                    slot: slots[idx],
                    logoBytes: logoBytes,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

// Tek etiket hücresi (referans jpg dili): üst bant logo + FİYAT hero (baskın),
// ürün adı, barkod çizgileri, en altta barkod no + oluşturma tarihi. Baskı
// siyah/beyaz → burada da nötr siyah/gri (app altını hücreye taşınmaz).
class _LabelCell extends StatelessWidget {
  final LabelSlot? slot;
  final Uint8List? logoBytes;

  const _LabelCell({required this.slot, required this.logoBytes});

  @override
  Widget build(BuildContext context) {
    final s = slot;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          // İnce nötr hairline kesim kılavuzu (altın YOK).
          color: s == null
              ? const Color(0xFFE0E0E0)
              : const Color(0xFFB8B8B8),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: s == null
          ? const SizedBox.expand()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Üst bant: logo (sol) + FİYAT hero (baskın, sağ)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 53,
                      height: 38,
                      child: logoBytes != null
                          ? Image.memory(logoBytes!, fit: BoxFit.contain)
                          : const Icon(Icons.storefront,
                              color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${formatNumber(s.price)} TL',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1,
                          color: Colors.black,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                // Ürün adı (2 satır, taşarsa kısalt)
                Text(
                  s.productName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                // Barkod çizgileri (Code128)
                SizedBox(
                  height: 30,
                  width: double.infinity,
                  child: BarcodeWidget(
                    barcode: bc.Barcode.code128(),
                    data: s.barcode,
                    drawText: false,
                    color: Colors.black,
                    errorBuilder: (context, error) => const SizedBox.shrink(),
                  ),
                ),
                // En alt: barkod no (sol) + oluşturma tarihi (sağ)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        s.barcode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          letterSpacing: 0.5,
                          color: Colors.black,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      formatShortDate(s.createdAt),
                      style: const TextStyle(
                        fontSize: 6.5,
                        color: Color(0xFF555555),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
