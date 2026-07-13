import 'dart:convert';

import 'package:barcode/barcode.dart' as bc;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';
import '../../../sales/application/barcode_cache.dart';
import '../../application/labels_provider.dart';
import '../../data/label_pdf.dart';
import '../../data/labels_storage_repository.dart';
import '../../data/models/label_slot.dart';
import '../widgets/etiket_print.dart';
import '../widgets/label_open.dart';

// Etiket ekranı üst sekmeleri (KARAR v1.11): mevcut 24-hane akışı + kayıtlı PDF'ler.
enum _LabelTab { yeni, kayitli }

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
  _LabelTab _tab = _LabelTab.yeni; // aktif sekme (Yeni Etiket / Kayıtlı Dosyalar)

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

  // PDF Kaydet (her platformda) — dosya adı sor → gerçek PDF üret → Supabase
  // Storage'a yükle (KARAR v1.11). Yerel cihaz kaydı YOK; yalnız Storage.
  Future<void> _savePdf() async {
    final state = ref.read(labelSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    final name = await _askFileName();
    if (name == null || !mounted) return;

    // Üretim + yükleme sırasında kısa engelleyici gösterge.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildLabelsPdf(
        slots: state.slots,
        logoDataUrl: state.logoDataUrl,
      );
      final saved =
          await ref.read(labelsStorageRepositoryProvider).upload(name, bytes);
      ref.invalidate(savedLabelFilesProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // göstergeyi kapat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedildi: $saved')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF kaydedilemedi: $e')),
      );
    }
  }

  // Dosya adı soran dialog (varsayılan raf-etiket-<tarih>). Vazgeç → null.
  Future<String?> _askFileName() {
    final controller =
        TextEditingController(text: 'raf-etiket-${_fileStamp()}');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('PDF Kaydet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dosya adı verin (.pdf otomatik eklenir).',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.space12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'raf-etiket',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (v) =>
                    Navigator.of(dialogContext).pop(v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // Varsayılan dosya adı için kompakt tarih damgası: YYYYAAGG-SSDD.
  String _fileStamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final selector = _TabSelector(
      tab: _tab,
      mobile: mobile,
      onChanged: (t) => setState(() => _tab = t),
    );

    // ── Sekme 2: Kayıtlı Dosyalar ──────────────────────────────────────────
    if (_tab == _LabelTab.kayitli) {
      if (mobile) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              selector,
              const SizedBox(height: AppSizes.space16),
              const _SavedFilesTab(compact: true),
              const SizedBox(height: AppSizes.space20),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          const SizedBox(height: AppSizes.space16),
          const Expanded(child: _SavedFilesTab(compact: false)),
        ],
      );
    }

    // ── Sekme 1: Yeni Etiket (mevcut akış) ─────────────────────────────────
    return mobile ? _buildMobile(selector) : _buildDesktop(selector);
  }

  // ─── Masaüstü: iki bölge (sol giriş sütunu · sağ A4 önizleme) ──────────────
  Widget _buildDesktop(Widget selector) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        const SizedBox(height: AppSizes.space16),
        _Header(
          filledCount: ref.watch(labelSheetProvider).filledCount,
          hasLogo: ref.watch(labelSheetProvider).logoDataUrl != null,
          onPickLogo: _pickLogo,
          onRemoveLogo: () =>
              ref.read(labelSheetProvider.notifier).setLogo(null),
          onClearAll: _clearAll,
          onPrint: _print,
          onSavePdf: _savePdf,
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
  Widget _buildMobile(Widget selector) {
    final state = ref.watch(labelSheetProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          const SizedBox(height: AppSizes.space16),
          _Header(
            filledCount: state.filledCount,
            hasLogo: state.logoDataUrl != null,
            onPickLogo: _pickLogo,
            onRemoveLogo: () =>
                ref.read(labelSheetProvider.notifier).setLogo(null),
            onClearAll: _clearAll,
            onPrint: _print,
            onSavePdf: _savePdf,
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
  final VoidCallback onSavePdf;
  final bool compact;

  const _Header({
    required this.filledCount,
    required this.hasLogo,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onClearAll,
    required this.onPrint,
    required this.onSavePdf,
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
      // PDF Kaydet — her platformda (Supabase Storage'a kaydeder; yerel kayıt yok).
      OutlinedButton.icon(
        onPressed: onSavePdf,
        icon: const Icon(Icons.save_alt_outlined, size: 18),
        label: const Text('PDF Kaydet'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.goldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
        ),
      ),
      // Yazdır yalnız web'de (window.print; native/mobilde no-op → gizli).
      if (kIsWeb)
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

// ═══════════════════════════════════════════════════════════════════════════
// Üst sekme seçici (KARAR v1.11): Yeni Etiket · Kayıtlı Dosyalar. Kasa sekme
// dili (SegmentedButton, aktif sekme token dili). Responsive: mobilde kısa
// etiket "Dosyalar" + ikonsuz → dar ekranda taşmaz (kasa KARAR v1.9.5 emsali).
// ═══════════════════════════════════════════════════════════════════════════

class _TabSelector extends StatelessWidget {
  final _LabelTab tab;
  final bool mobile;
  final ValueChanged<_LabelTab> onChanged;

  const _TabSelector({
    required this.tab,
    required this.mobile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_LabelTab>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _LabelTab.yeni,
            label: const Text('Yeni Etiket', maxLines: 1, softWrap: false),
            icon: mobile ? null : const Icon(Icons.add_box_outlined, size: 18),
          ),
          ButtonSegment(
            value: _LabelTab.kayitli,
            label: Text(
              mobile ? 'Dosyalar' : 'Kayıtlı Dosyalar',
              maxLines: 1,
              softWrap: false,
            ),
            icon: mobile ? null : const Icon(Icons.folder_outlined, size: 18),
          ),
        ],
        selected: {tab},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sekme 2: Kayıtlı Dosyalar (KARAR v1.11) — Storage'daki PDF'ler. EKRAN HERO'SU
// YOK (stok listesi/rapor dili). cardDecoration + goldBg başlık. Masaüstü tablo /
// mobil kart. Satır aksiyonları: Aç/İndir · Yazdır · Sil (danger + onay).
// ═══════════════════════════════════════════════════════════════════════════

class _SavedFilesTab extends ConsumerWidget {
  final bool compact;
  const _SavedFilesTab({required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(savedLabelFilesProvider);

    Widget body = filesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSizes.space24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Text(
          'Dosyalar yüklenemedi: $e',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.space24),
            child: Center(
              child: Text(
                'Kayıtlı etiket dosyası yok.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          );
        }
        if (compact) {
          return Column(
            children: [
              for (final f in files) _SavedFileCard(file: f),
            ],
          );
        }
        // Masaüstü: başlık + kaydırılabilir tablo (bounded height → Expanded).
        return Expanded(
          child: Column(
            children: [
              const _FilesHeaderRow(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final f in files) _SavedFileRow(file: f),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              const _SectionLabel('Kayıtlı Dosyalar'),
              const Spacer(),
              IconButton(
                onPressed: () => ref.invalidate(savedLabelFilesProvider),
                icon: const Icon(Icons.refresh, size: 18),
                color: AppColors.textMuted,
                tooltip: 'Yenile',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          body,
        ],
      ),
    );
  }
}

// Masaüstü tablo başlığı (goldBg zemin).
class _FilesHeaderRow extends StatelessWidget {
  const _FilesHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusSm)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12, vertical: AppSizes.space8),
      child: Row(
        children: const [
          Expanded(flex: 5, child: _HeaderCell('Ad')),
          Expanded(flex: 3, child: _HeaderCell('Tarih')),
          Expanded(flex: 2, child: _HeaderCell('Boyut')),
          SizedBox(width: 132, child: _HeaderCell('İşlem')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// Masaüstü tablo satırı.
class _SavedFileRow extends ConsumerWidget {
  final SavedLabelFile file;
  const _SavedFileRow({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12, vertical: AppSizes.space8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              file.createdAt != null ? formatDateTime(file.createdAt!) : '—',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtSize(file.size),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionIcon(
                  icon: Icons.open_in_new,
                  tooltip: 'Aç / İndir',
                  color: AppColors.primary,
                  onTap: () => _openSaved(context, ref, file),
                ),
                _actionIcon(
                  icon: Icons.print_outlined,
                  tooltip: 'Yazdır',
                  color: AppColors.textSecondary,
                  onTap: () => _printSaved(context, ref, file),
                ),
                _actionIcon(
                  icon: Icons.delete_outline,
                  tooltip: 'Sil',
                  color: AppColors.danger,
                  onTap: () => _deleteSaved(context, ref, file),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Mobil kart.
class _SavedFileCard extends ConsumerWidget {
  final SavedLabelFile file;
  const _SavedFileCard({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space8),
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSizes.space4),
          Row(
            children: [
              Text(
                file.createdAt != null ? formatDateTime(file.createdAt!) : '—',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                _fmtSize(file.size),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openSaved(context, ref, file),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Aç'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
              TextButton.icon(
                onPressed: () => _printSaved(context, ref, file),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Yazdır'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _deleteSaved(context, ref, file),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger,
                tooltip: 'Sil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _actionIcon({
  required IconData icon,
  required String tooltip,
  required Color color,
  required VoidCallback onTap,
}) {
  return IconButton(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    color: color,
    tooltip: tooltip,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}

// ─── Kayıtlı dosya aksiyonları (Aç/İndir · Yazdır · Sil) ─────────────────────
// Platform ayrımı: web → imzalı URL yeni sekmede (window.open, mevcut
// conditional-export deseni); native → url_launcher (aç) / Printing.layoutPdf
// (gerçek yazdırma).

Future<void> _openSaved(
    BuildContext context, WidgetRef ref, SavedLabelFile f) async {
  final repo = ref.read(labelsStorageRepositoryProvider);
  try {
    final url = await repo.signedUrl(f.path);
    if (kIsWeb) {
      openUrlInNewTab(url);
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    if (context.mounted) _snack(context, 'Dosya açılamadı: $e');
  }
}

Future<void> _printSaved(
    BuildContext context, WidgetRef ref, SavedLabelFile f) async {
  final repo = ref.read(labelsStorageRepositoryProvider);
  try {
    if (kIsWeb) {
      final url = await repo.signedUrl(f.path);
      openUrlInNewTab(url); // tarayıcı PDF yazdırma
    } else {
      final bytes = await repo.download(f.path);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  } catch (e) {
    if (context.mounted) _snack(context, 'Yazdırılamadı: $e');
  }
}

Future<void> _deleteSaved(
    BuildContext context, WidgetRef ref, SavedLabelFile f) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Dosyayı Sil'),
      content: Text('"${f.name}" kalıcı olarak silinsin mi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.textOnDark,
          ),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(labelsStorageRepositoryProvider).remove(f.path);
    ref.invalidate(savedLabelFilesProvider);
    if (context.mounted) _snack(context, 'Silindi: ${f.name}');
  } catch (e) {
    if (context.mounted) _snack(context, 'Silinemedi: $e');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

// Byte boyutunu okunur biçimler (B / KB / MB).
String _fmtSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
