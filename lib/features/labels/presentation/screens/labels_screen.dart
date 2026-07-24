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
import '../../../../core/utils/scan_sound.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';
import '../../../sales/application/barcode_cache.dart';
import '../../application/labels_provider.dart';
import '../../data/label_pdf.dart';
import '../../data/labels_storage_repository.dart';
import '../../data/models/label_slot.dart';
import '../../data/models/product_label_item.dart';
import '../widgets/etiket_print.dart';
import '../widgets/label_open.dart';
import '../widgets/label_scan_sheet.dart';

// Etiket ekranı üst sekmeleri (KARAR v1.14 / v1.19 / v1.21): dar 24-hane akışı +
// Geniş Logo 10-hane akışı + Büyük Etiket 4-hane akışı + Ürün Etiketi (adet-
// tabanlı 6×12) + kayıtlı PDF'ler.
enum _LabelTab { yeni, genis, buyuk, urun, kayitli }

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

  // Geniş Logo sekmesi (KARAR v1.14) — 10 haneli ayrı giriş durumu.
  late final List<TextEditingController> _wideControllers;
  late final List<FocusNode> _wideFocusNodes;
  final Set<int> _wideErrors = {};
  int _wideActiveIndex = 0;
  Uint8List? _figurBytes; // marka figürü (yazdırma için bir kez okunur)

  // Büyük Etiket sekmesi (KARAR v1.19) — 4 haneli ayrı giriş durumu.
  late final List<TextEditingController> _quadControllers;
  late final List<FocusNode> _quadFocusNodes;
  final Set<int> _quadErrors = {};
  int _quadActiveIndex = 0;

  // Ürün Etiketi sekmesi (KARAR v1.21) — adet-tabanlı tek giriş satırı (barkod +
  // adet). Çözülen ürün "bekleyen kalem" olarak tutulur; adet onaylanınca listeye
  // eklenir.
  late final TextEditingController _prodBarcodeController;
  late final TextEditingController _prodQtyController;
  late final FocusNode _prodBarcodeFocus;
  late final FocusNode _prodQtyFocus;
  Product? _prodPending; // barkodu çözülmüş, adet bekleyen ürün
  bool _prodError = false; // son barkod çözülemedi (danger uyarı)
  bool _prodBarcodeActive = false; // barkod hanesi odaklı mı (aktif altını)

  _LabelTab _tab = _LabelTab.yeni; // aktif sekme

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
    _wideControllers =
        List.generate(kWideCount, (_) => TextEditingController());
    _wideFocusNodes = List.generate(kWideCount, (i) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus && mounted) setState(() => _wideActiveIndex = i);
      });
      return node;
    });
    _quadControllers =
        List.generate(kQuadCount, (_) => TextEditingController());
    _quadFocusNodes = List.generate(kQuadCount, (i) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus && mounted) setState(() => _quadActiveIndex = i);
      });
      return node;
    });
    // Ürün Etiketi sekmesi (KARAR v1.21) — barkod + adet giriş kontrolleri.
    _prodBarcodeController = TextEditingController();
    _prodQtyController = TextEditingController(text: '1');
    _prodBarcodeFocus = FocusNode();
    _prodBarcodeFocus.addListener(() {
      if (mounted) {
        setState(() => _prodBarcodeActive = _prodBarcodeFocus.hasFocus);
      }
    });
    _prodQtyFocus = FocusNode();
    // Barkod → Product bellek indeksini bir kez prefetch et (satış ekranıyla
    // paylaşılan keepAlive cache) → okutmada ağ turu beklemeden çözüm.
    ref.read(barcodeCacheProvider).ensureLoaded();
    // Kayıtlı mağaza logosunu Storage'dan geri yükle (KARAR v1.12) — login/logout
    // sonrası korunur. Fire-and-forget (await gerekmez).
    _loadPersistedLogo();
  }

  // Storage'da kayıtlı logoyu (varsa) sayfaya geri yükler (KARAR v1.12).
  Future<void> _loadPersistedLogo() async {
    // Mevcut oturumda logo zaten yüklenmişse dokunma.
    if (ref.read(labelSheetProvider).logoDataUrl != null) return;
    final dataUrl = await ref.read(labelsStorageRepositoryProvider).fetchLogo();
    if (!mounted || dataUrl == null || dataUrl.isEmpty) return;
    ref.read(labelSheetProvider.notifier).setLogo(dataUrl);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _wideControllers) {
      c.dispose();
    }
    for (final n in _wideFocusNodes) {
      n.dispose();
    }
    for (final c in _quadControllers) {
      c.dispose();
    }
    for (final n in _quadFocusNodes) {
      n.dispose();
    }
    _prodBarcodeController.dispose();
    _prodQtyController.dispose();
    _prodBarcodeFocus.dispose();
    _prodQtyFocus.dispose();
    super.dispose();
  }

  // Barkodu ürüne çözer (satış ekranı deseni): önce bellek cache (anında +
  // internetsiz), miss ise ağ fallback (fetchByBarcode → fetchAll, tam barkod
  // eşleşmesi tercih). Ağ hatası/offline → cache miss'te null döner. Bulunan
  // ürün cache'e yazılır (sonraki okutmalar da hızlı/offline olur).
  Future<Product?> _resolveBarcode(String query) async {
    final cache = ref.read(barcodeCacheProvider);
    Product? product = cache.lookup(query);
    if (product == null) {
      try {
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
      } catch (_) {
        // Offline / ağ hatası — cache miss ise çözülemez (null).
      }
    }
    return product;
  }

  // İlk boş hane indeksi (hepsi doluysa -1).
  int _nextEmptyIndex() {
    final slots = ref.read(labelSheetProvider).slots;
    for (var i = 0; i < kLabelCount; i++) {
      if (slots[i] == null) return i;
    }
    return -1;
  }

  // Elle giriş / tam barkod Enter: haneyi çöz + doldur, imleç bir alta geçer.
  Future<void> _onSubmitted(int index, String raw) async {
    final query = raw.trim();
    final notifier = ref.read(labelSheetProvider.notifier);
    if (query.isEmpty) {
      notifier.clearSlot(index);
      setState(() => _errors.remove(index));
      return;
    }

    final product = await _resolveBarcode(query);
    if (!mounted) return;
    if (product == null) {
      notifier.clearSlot(index);
      setState(() => _errors.add(index));
      playScanBeep(success: false); // danger uyarı sesi (KARAR v1.14.1)
      return;
    }

    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    notifier.setSlot(
      index,
      LabelSlot(
        barcode: code,
        productName: product.name,
        price: product.price1,
        createdAt: DateTime.now(),
      ),
    );
    _controllers[index].text = code;
    HapticFeedback.lightImpact();
    playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
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

  // Sürekli kamera taraması: bir okutma → çöz → ilk boş haneye yerleştir.
  // Kamera sayfası (LabelScanSheet) her okutmada bunu çağırır; dönüş değeri üst
  // ilerleme + alt sonuç kartını canlı besler. Çözüm bellek cache'ten geldiği
  // için internetsiz de hızlı çalışır.
  Future<LabelScanFeedback> _handleCameraScan(String raw) async {
    final query = raw.trim();
    int filled() => ref.read(labelSheetProvider).filledCount;
    if (query.isEmpty) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final index = _nextEmptyIndex();
    if (index < 0) {
      return LabelScanFeedback(
          status: LabelScanStatus.full, filledCount: filled());
    }
    final product = await _resolveBarcode(query);
    if (!mounted || product == null) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    ref.read(labelSheetProvider.notifier).setSlot(
          index,
          LabelSlot(
            barcode: code,
            productName: product.name,
            price: product.price1,
            createdAt: DateTime.now(),
          ),
        );
    _controllers[index].text = code;
    setState(() => _errors.remove(index));
    return LabelScanFeedback(
      status: LabelScanStatus.placed,
      productName: product.name,
      price: product.price1,
      filledCount: filled(),
    );
  }

  // Kamera ile sürekli tarama sayfasını açar (yalnız native). Cache'i garanti
  // et → okutma anında/offline çözülür.
  Future<void> _startCameraScan() async {
    if (kIsWeb) return;
    await ref.read(barcodeCacheProvider).ensureLoaded();
    if (!mounted) return;
    await openLabelScanSheet(
      context,
      onScan: _handleCameraScan,
      totalCount: kLabelCount,
      initialFilled: ref.read(labelSheetProvider).filledCount,
    );
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
    // Storage'a da yaz (KARAR v1.12) — hata olsa da önizleme çalışsın.
    try {
      await ref.read(labelsStorageRepositoryProvider).uploadLogo(dataUrl);
    } catch (_) {}
  }

  // Logoyu hem sayfadan hem Storage'dan kaldırır (KARAR v1.12).
  Future<void> _removeLogo() async {
    ref.read(labelSheetProvider.notifier).setLogo(null);
    try {
      await ref.read(labelsStorageRepositoryProvider).removeLogo();
    } catch (_) {}
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

  // Dosya adı soran dialog (varsayılan [defaultName]). Vazgeç → null.
  Future<String?> _askFileName({String prefix = 'raf-etiket'}) {
    final controller =
        TextEditingController(text: '$prefix-${_fileStamp()}');
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

  // ═════════════════════════════════════════════════════════════════════════
  // Geniş Logo sekmesi (KARAR v1.14) — 10 haneli akış (dar sekmenin logosuz,
  // sabit marka tentesi kullanan uyarlaması). Barkod çözme mantığı ortak
  // (_resolveBarcode); yalnız hedef state (labelWideSheetProvider) farklı.
  // ═════════════════════════════════════════════════════════════════════════

  // Marka figürünü yazdırma için bir kez okur (base64 print + PDF ayrı okur).
  Future<Uint8List> _loadFigurBytes() async {
    return _figurBytes ??=
        (await rootBundle.load('genis_logo_figur.png')).buffer.asUint8List();
  }

  int _nextWideEmptyIndex() {
    final slots = ref.read(labelWideSheetProvider).slots;
    for (var i = 0; i < kWideCount; i++) {
      if (slots[i] == null) return i;
    }
    return -1;
  }

  Future<void> _onWideSubmitted(int index, String raw) async {
    final query = raw.trim();
    final notifier = ref.read(labelWideSheetProvider.notifier);
    if (query.isEmpty) {
      notifier.clearSlot(index);
      setState(() => _wideErrors.remove(index));
      return;
    }

    final product = await _resolveBarcode(query);
    if (!mounted) return;
    if (product == null) {
      notifier.clearSlot(index);
      setState(() => _wideErrors.add(index));
      playScanBeep(success: false); // danger uyarı sesi (KARAR v1.14.1)
      return;
    }

    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    notifier.setSlot(
      index,
      LabelSlot(
        barcode: code,
        productName: product.name,
        price: product.price1,
        createdAt: DateTime.now(),
      ),
    );
    _wideControllers[index].text = code;
    HapticFeedback.lightImpact();
    playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
    setState(() => _wideErrors.remove(index));

    if (index + 1 < kWideCount) {
      _wideFocusNodes[index + 1].requestFocus();
      _wideControllers[index + 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _wideControllers[index + 1].text.length,
      );
    }
  }

  Future<LabelScanFeedback> _handleWideCameraScan(String raw) async {
    final query = raw.trim();
    int filled() => ref.read(labelWideSheetProvider).filledCount;
    if (query.isEmpty) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final index = _nextWideEmptyIndex();
    if (index < 0) {
      return LabelScanFeedback(
          status: LabelScanStatus.full, filledCount: filled());
    }
    final product = await _resolveBarcode(query);
    if (!mounted || product == null) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    ref.read(labelWideSheetProvider.notifier).setSlot(
          index,
          LabelSlot(
            barcode: code,
            productName: product.name,
            price: product.price1,
            createdAt: DateTime.now(),
          ),
        );
    _wideControllers[index].text = code;
    setState(() => _wideErrors.remove(index));
    return LabelScanFeedback(
      status: LabelScanStatus.placed,
      productName: product.name,
      price: product.price1,
      filledCount: filled(),
    );
  }

  Future<void> _startWideCameraScan() async {
    if (kIsWeb) return;
    await ref.read(barcodeCacheProvider).ensureLoaded();
    if (!mounted) return;
    await openLabelScanSheet(
      context,
      onScan: _handleWideCameraScan,
      totalCount: kWideCount,
      initialFilled: ref.read(labelWideSheetProvider).filledCount,
    );
  }

  void _clearWideSlot(int index) {
    _wideControllers[index].clear();
    ref.read(labelWideSheetProvider.notifier).clearSlot(index);
    setState(() => _wideErrors.remove(index));
    _wideFocusNodes[index].requestFocus();
  }

  void _clearWideAll() {
    for (final c in _wideControllers) {
      c.clear();
    }
    ref.read(labelWideSheetProvider.notifier).clearAll();
    setState(() => _wideErrors.clear());
  }

  Future<void> _printWide() async {
    final state = ref.read(labelWideSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    final bytes = await _loadFigurBytes();
    if (!mounted) return;
    final figurDataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
    printWideLabelsA4(slots: state.slots, figurDataUrl: figurDataUrl);
  }

  Future<void> _saveWidePdf() async {
    final state = ref.read(labelWideSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    final name = await _askFileName(prefix: 'genis-etiket');
    if (name == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildWideLabelsPdf(slots: state.slots);
      final saved =
          await ref.read(labelsStorageRepositoryProvider).upload(name, bytes);
      ref.invalidate(savedLabelFilesProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
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

  // ═════════════════════════════════════════════════════════════════════════
  // Büyük Etiket sekmesi (KARAR v1.19) — 4 haneli akış (dar-logo 24-hane
  // akışının A5 2×2 uyarlaması). Barkod çözme mantığı ortak (_resolveBarcode);
  // hedef state (labelQuadSheetProvider) + mağaza logosu (dar-logo'nun kalıcı
  // store logosu paylaşılır) farklı.
  // ═════════════════════════════════════════════════════════════════════════

  int _nextQuadEmptyIndex() {
    final slots = ref.read(labelQuadSheetProvider).slots;
    for (var i = 0; i < kQuadCount; i++) {
      if (slots[i] == null) return i;
    }
    return -1;
  }

  Future<void> _onQuadSubmitted(int index, String raw) async {
    final query = raw.trim();
    final notifier = ref.read(labelQuadSheetProvider.notifier);
    if (query.isEmpty) {
      notifier.clearSlot(index);
      setState(() => _quadErrors.remove(index));
      return;
    }

    final product = await _resolveBarcode(query);
    if (!mounted) return;
    if (product == null) {
      notifier.clearSlot(index);
      setState(() => _quadErrors.add(index));
      playScanBeep(success: false); // danger uyarı sesi (KARAR v1.14.1)
      return;
    }

    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    notifier.setSlot(
      index,
      LabelSlot(
        barcode: code,
        productName: product.name,
        price: product.price1,
        createdAt: DateTime.now(),
      ),
    );
    _quadControllers[index].text = code;
    HapticFeedback.lightImpact();
    playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
    setState(() => _quadErrors.remove(index));

    if (index + 1 < kQuadCount) {
      _quadFocusNodes[index + 1].requestFocus();
      _quadControllers[index + 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quadControllers[index + 1].text.length,
      );
    }
  }

  Future<LabelScanFeedback> _handleQuadCameraScan(String raw) async {
    final query = raw.trim();
    int filled() => ref.read(labelQuadSheetProvider).filledCount;
    if (query.isEmpty) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final index = _nextQuadEmptyIndex();
    if (index < 0) {
      return LabelScanFeedback(
          status: LabelScanStatus.full, filledCount: filled());
    }
    final product = await _resolveBarcode(query);
    if (!mounted || product == null) {
      return LabelScanFeedback(
          status: LabelScanStatus.notFound, filledCount: filled());
    }
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : query;
    ref.read(labelQuadSheetProvider.notifier).setSlot(
          index,
          LabelSlot(
            barcode: code,
            productName: product.name,
            price: product.price1,
            createdAt: DateTime.now(),
          ),
        );
    _quadControllers[index].text = code;
    setState(() => _quadErrors.remove(index));
    return LabelScanFeedback(
      status: LabelScanStatus.placed,
      productName: product.name,
      price: product.price1,
      filledCount: filled(),
    );
  }

  Future<void> _startQuadCameraScan() async {
    if (kIsWeb) return;
    await ref.read(barcodeCacheProvider).ensureLoaded();
    if (!mounted) return;
    await openLabelScanSheet(
      context,
      onScan: _handleQuadCameraScan,
      totalCount: kQuadCount,
      initialFilled: ref.read(labelQuadSheetProvider).filledCount,
    );
  }

  void _clearQuadSlot(int index) {
    _quadControllers[index].clear();
    ref.read(labelQuadSheetProvider.notifier).clearSlot(index);
    setState(() => _quadErrors.remove(index));
    _quadFocusNodes[index].requestFocus();
  }

  void _clearQuadAll() {
    for (final c in _quadControllers) {
      c.clear();
    }
    ref.read(labelQuadSheetProvider.notifier).clearAll();
    setState(() => _quadErrors.clear());
  }

  void _printQuad() {
    final state = ref.read(labelQuadSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    // Mağaza logosu dar-logo sekmesinin kalıcı store logosundan paylaşılır.
    printQuadLabelsA4(
      slots: state.slots,
      logoDataUrl: ref.read(labelSheetProvider).logoDataUrl,
    );
  }

  Future<void> _saveQuadPdf() async {
    final state = ref.read(labelQuadSheetProvider);
    if (state.filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir barkod okutun.')),
      );
      return;
    }
    final name = await _askFileName(prefix: 'buyuk-etiket');
    if (name == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildQuadLabelsPdf(
        slots: state.slots,
        logoDataUrl: ref.read(labelSheetProvider).logoDataUrl,
      );
      final saved =
          await ref.read(labelsStorageRepositoryProvider).upload(name, bytes);
      ref.invalidate(savedLabelFilesProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
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

  // ═════════════════════════════════════════════════════════════════════════
  // Ürün Etiketi sekmesi (KARAR v1.21) — adet-tabanlı doldurma. Sol panelde tek
  // giriş satırı: Barkod hanesi (okut/Enter → _resolveBarcode) + Adet hanesi.
  // Onaylanınca kalem (ürün adı · barkod · adet) listeye eklenir; sağ panelde
  // her kalem adet kadar çoğaltılıp 72'lik ızgaraya dizilir (çok-sayfalı taşma).
  // Barkod çözme mantığı ortak (_resolveBarcode); hedef state farklı
  // (labelProductSheetProvider). Fiyat/logo YOK.
  // ═════════════════════════════════════════════════════════════════════════

  // Barkod okut/Enter → çöz. Bulunursa bekleyen kalem olur + odak adet hanesine
  // geçer; bulunamazsa danger uyarı + hata bipi.
  Future<void> _onProdBarcodeSubmitted(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _prodPending = null;
        _prodError = false;
      });
      return;
    }
    final product = await _resolveBarcode(query);
    if (!mounted) return;
    if (product == null) {
      setState(() {
        _prodPending = null;
        _prodError = true;
      });
      playScanBeep(success: false); // danger uyarı sesi (KARAR v1.14.1)
      return;
    }
    setState(() {
      _prodPending = product;
      _prodError = false;
    });
    HapticFeedback.lightImpact();
    playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
    // Adet hanesine geç, mevcut değeri seç (hızlı üzerine yazma).
    _prodQtyFocus.requestFocus();
    _prodQtyController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _prodQtyController.text.length,
    );
  }

  // Bekleyen ürün + adet → listeye kalem ekle; giriş temizlenip odak barkoda
  // döner (sonraki okutma için hazır).
  void _addProdItem() {
    final product = _prodPending;
    if (product == null) {
      // Barkod henüz çözülmedi — barkod hanesine yönlendir.
      _prodBarcodeFocus.requestFocus();
      return;
    }
    final qty = int.tryParse(_prodQtyController.text.trim()) ?? 0;
    if (qty <= 0) return;
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : _prodBarcodeController.text.trim();
    ref.read(labelProductSheetProvider.notifier).addItem(
          ProductLabelItem(
            barcode: code,
            productName: product.name,
            quantity: qty,
          ),
        );
    setState(() {
      _prodPending = null;
      _prodError = false;
    });
    _prodBarcodeController.clear();
    _prodQtyController.text = '1';
    _prodBarcodeFocus.requestFocus();
  }

  void _removeProdItem(int index) {
    ref.read(labelProductSheetProvider.notifier).removeItem(index);
  }

  void _updateProdQty(int index, int qty) {
    ref.read(labelProductSheetProvider.notifier).updateQuantity(index, qty);
  }

  void _clearProdAll() {
    ref.read(labelProductSheetProvider.notifier).clearAll();
    setState(() {
      _prodPending = null;
      _prodError = false;
    });
    _prodBarcodeController.clear();
    _prodQtyController.text = '1';
  }

  void _printProduct() {
    final state = ref.read(labelProductSheetProvider);
    if (state.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir ürün ekleyin.')),
      );
      return;
    }
    printProductLabelsA4(items: state.items);
  }

  Future<void> _saveProductPdf() async {
    final state = ref.read(labelProductSheetProvider);
    if (state.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir ürün ekleyin.')),
      );
      return;
    }
    final name = await _askFileName(prefix: 'urun-etiket');
    if (name == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildProductLabelsPdf(items: state.items);
      final saved =
          await ref.read(labelsStorageRepositoryProvider).upload(name, bytes);
      ref.invalidate(savedLabelFilesProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
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

    // ── Sekme 2: Geniş Logo (KARAR v1.14) ──────────────────────────────────
    if (_tab == _LabelTab.genis) {
      return mobile ? _buildWideMobile(selector) : _buildWideDesktop(selector);
    }

    // ── Sekme 3: Büyük Etiket (KARAR v1.19) ────────────────────────────────
    if (_tab == _LabelTab.buyuk) {
      return mobile ? _buildQuadMobile(selector) : _buildQuadDesktop(selector);
    }

    // ── Sekme 4: Ürün Etiketi (KARAR v1.21) ────────────────────────────────
    if (_tab == _LabelTab.urun) {
      return mobile
          ? _buildProductMobile(selector)
          : _buildProductDesktop(selector);
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
          onRemoveLogo: _removeLogo,
          onClearAll: _clearAll,
          onPrint: _print,
          onSavePdf: _savePdf,
          onCameraScan: kIsWeb ? null : _startCameraScan,
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
            onCameraScan: kIsWeb ? null : _startCameraScan,
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

  // ─── Geniş Logo — masaüstü (sol 10-hane giriş · sağ A4 önizleme) ───────────
  Widget _buildWideDesktop(Widget selector) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        const SizedBox(height: AppSizes.space16),
        _Header(
          filledCount: ref.watch(labelWideSheetProvider).filledCount,
          totalCount: kWideCount,
          showLogoActions: false,
          onClearAll: _clearWideAll,
          onPrint: _printWide,
          onSavePdf: _saveWidePdf,
          onCameraScan: kIsWeb ? null : _startWideCameraScan,
          subtitle:
              'Barkod okutun; her hane marka tentesi + fiyat + ürün adıyla '
              'A4 Geniş Logo etiketine dönüşür.',
        ),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _InputColumn(
                  controllers: _wideControllers,
                  focusNodes: _wideFocusNodes,
                  errors: _wideErrors,
                  activeIndex: _wideActiveIndex,
                  itemCount: kWideCount,
                  wide: true,
                  onSubmitted: _onWideSubmitted,
                  onClear: _clearWideSlot,
                ),
              ),
              const SizedBox(width: AppSizes.space16),
              Expanded(
                flex: 6,
                child: _WidePreviewPane(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Geniş Logo — mobil (tek kolon) ────────────────────────────────────────
  Widget _buildWideMobile(Widget selector) {
    final state = ref.watch(labelWideSheetProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          const SizedBox(height: AppSizes.space16),
          _Header(
            filledCount: state.filledCount,
            totalCount: kWideCount,
            showLogoActions: false,
            onClearAll: _clearWideAll,
            onPrint: _printWide,
            onSavePdf: _saveWidePdf,
            onCameraScan: kIsWeb ? null : _startWideCameraScan,
            subtitle:
                'Barkod okutun; her hane marka tentesi + fiyat + ürün adıyla '
                'A4 Geniş Logo etiketine dönüşür.',
            compact: true,
          ),
          const SizedBox(height: AppSizes.space16),
          ...List.generate(kWideCount, (i) {
            return _SlotInputRow(
              index: i,
              controller: _wideControllers[i],
              focusNode: _wideFocusNodes[i],
              isActive: _wideActiveIndex == i,
              isError: _wideErrors.contains(i),
              wide: true,
              onSubmitted: (v) => _onWideSubmitted(i, v),
              onClear: () => _clearWideSlot(i),
            );
          }),
          const SizedBox(height: AppSizes.space20),
          const _SectionLabel('A4 Önizleme'),
          const SizedBox(height: AppSizes.space8),
          LayoutBuilder(
            builder: (ctx, c) => SizedBox(
              width: c.maxWidth,
              height: c.maxWidth * (_kA4Height / _kA4Width),
              child: _WidePreviewPane(),
            ),
          ),
          const SizedBox(height: AppSizes.space20),
        ],
      ),
    );
  }

  // ─── Büyük Etiket — masaüstü (sol 4-hane giriş · sağ A4 önizleme) ──────────
  Widget _buildQuadDesktop(Widget selector) {
    final logoDataUrl = ref.watch(labelSheetProvider).logoDataUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        const SizedBox(height: AppSizes.space16),
        _Header(
          filledCount: ref.watch(labelQuadSheetProvider).filledCount,
          totalCount: kQuadCount,
          hasLogo: logoDataUrl != null,
          onPickLogo: _pickLogo,
          onRemoveLogo: _removeLogo,
          onClearAll: _clearQuadAll,
          onPrint: _printQuad,
          onSavePdf: _saveQuadPdf,
          onCameraScan: kIsWeb ? null : _startQuadCameraScan,
          subtitle:
              'Barkod okutun; her hane A4 sayfayı çeyreğe bölen büyük (A5) '
              'etikete dönüşür — logo + fiyat + ürün adı + barkod.',
        ),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _InputColumn(
                  controllers: _quadControllers,
                  focusNodes: _quadFocusNodes,
                  errors: _quadErrors,
                  activeIndex: _quadActiveIndex,
                  itemCount: kQuadCount,
                  quad: true,
                  onSubmitted: _onQuadSubmitted,
                  onClear: _clearQuadSlot,
                ),
              ),
              const SizedBox(width: AppSizes.space16),
              Expanded(
                flex: 6,
                child: _QuadPreviewPane(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Büyük Etiket — mobil (tek kolon) ──────────────────────────────────────
  Widget _buildQuadMobile(Widget selector) {
    final state = ref.watch(labelQuadSheetProvider);
    final logoDataUrl = ref.watch(labelSheetProvider).logoDataUrl;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          const SizedBox(height: AppSizes.space16),
          _Header(
            filledCount: state.filledCount,
            totalCount: kQuadCount,
            hasLogo: logoDataUrl != null,
            onPickLogo: _pickLogo,
            onRemoveLogo: _removeLogo,
            onClearAll: _clearQuadAll,
            onPrint: _printQuad,
            onSavePdf: _saveQuadPdf,
            onCameraScan: kIsWeb ? null : _startQuadCameraScan,
            subtitle:
                'Barkod okutun; her hane A4 sayfayı çeyreğe bölen büyük (A5) '
                'etikete dönüşür — logo + fiyat + ürün adı + barkod.',
            compact: true,
          ),
          const SizedBox(height: AppSizes.space16),
          ...List.generate(kQuadCount, (i) {
            return _SlotInputRow(
              index: i,
              controller: _quadControllers[i],
              focusNode: _quadFocusNodes[i],
              isActive: _quadActiveIndex == i,
              isError: _quadErrors.contains(i),
              quad: true,
              onSubmitted: (v) => _onQuadSubmitted(i, v),
              onClear: () => _clearQuadSlot(i),
            );
          }),
          const SizedBox(height: AppSizes.space20),
          const _SectionLabel('A4 Önizleme'),
          const SizedBox(height: AppSizes.space8),
          LayoutBuilder(
            builder: (ctx, c) => SizedBox(
              width: c.maxWidth,
              height: c.maxWidth * (_kA4Height / _kA4Width),
              child: _QuadPreviewPane(),
            ),
          ),
          const SizedBox(height: AppSizes.space20),
        ],
      ),
    );
  }

  // ─── Ürün Etiketi — masaüstü (sol barkod+adet girişi/kalem listesi · sağ
  //     çok-sayfalı A4 önizleme) ────────────────────────────────────────────
  Widget _buildProductDesktop(Widget selector) {
    final state = ref.watch(labelProductSheetProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        const SizedBox(height: AppSizes.space16),
        _Header(
          filledCount: state.totalLabels,
          showLogoActions: false,
          badgeOverride:
              '${state.totalLabels} etiket · ${state.pageCount} sayfa',
          onClearAll: _clearProdAll,
          onPrint: _printProduct,
          onSavePdf: _saveProductPdf,
          subtitle:
              'Barkod okutun + adet girin; her ürün adet kadar çoğaltılıp A4 '
              'sayfada 6×12 = 72 fiyatsız barkod etiketine dizilir.',
        ),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _ProductInputColumn(
                  barcodeController: _prodBarcodeController,
                  qtyController: _prodQtyController,
                  barcodeFocus: _prodBarcodeFocus,
                  qtyFocus: _prodQtyFocus,
                  barcodeActive: _prodBarcodeActive,
                  pending: _prodPending,
                  isError: _prodError,
                  items: state.items,
                  onBarcodeSubmitted: _onProdBarcodeSubmitted,
                  onAdd: _addProdItem,
                  onRemoveItem: _removeProdItem,
                  onUpdateQty: _updateProdQty,
                ),
              ),
              const SizedBox(width: AppSizes.space16),
              Expanded(
                flex: 6,
                child: _ProductPreviewPane(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Ürün Etiketi — mobil (tek kolon) ──────────────────────────────────────
  Widget _buildProductMobile(Widget selector) {
    final state = ref.watch(labelProductSheetProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          selector,
          const SizedBox(height: AppSizes.space16),
          _Header(
            filledCount: state.totalLabels,
            showLogoActions: false,
            badgeOverride:
                '${state.totalLabels} etiket · ${state.pageCount} sayfa',
            onClearAll: _clearProdAll,
            onPrint: _printProduct,
            onSavePdf: _saveProductPdf,
            subtitle:
                'Barkod okutun + adet girin; her ürün adet kadar çoğaltılıp A4 '
                'sayfada 6×12 = 72 fiyatsız barkod etiketine dizilir.',
            compact: true,
          ),
          const SizedBox(height: AppSizes.space16),
          _ProductInputColumn(
            barcodeController: _prodBarcodeController,
            qtyController: _prodQtyController,
            barcodeFocus: _prodBarcodeFocus,
            qtyFocus: _prodQtyFocus,
            barcodeActive: _prodBarcodeActive,
            pending: _prodPending,
            isError: _prodError,
            items: state.items,
            shrinkWrap: true,
            onBarcodeSubmitted: _onProdBarcodeSubmitted,
            onAdd: _addProdItem,
            onRemoveItem: _removeProdItem,
            onUpdateQty: _updateProdQty,
          ),
          const SizedBox(height: AppSizes.space20),
          const _SectionLabel('A4 Önizleme'),
          const SizedBox(height: AppSizes.space8),
          // Çok-sayfalı önizleme dış sayfa scroll'una gömülü (kendi scroll'u yok).
          _ProductPreviewPane(scrollable: false),
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
  final int totalCount;
  final bool showLogoActions; // Geniş Logo sekmesinde false (logo yükleme yok)
  final bool hasLogo;
  final VoidCallback? onPickLogo;
  final VoidCallback? onRemoveLogo;
  final VoidCallback onClearAll;
  final VoidCallback onPrint;
  final VoidCallback onSavePdf;
  final VoidCallback? onCameraScan; // yalnız native → kamera ile sürekli tara
  final String subtitle;
  final bool compact;
  // Sabit "X / Y etiket" yerine gösterilecek özel rozet metni (Ürün Etiketi
  // sekmesi dinamik "X etiket · N sayfa" için, KARAR v1.21).
  final String? badgeOverride;

  const _Header({
    required this.filledCount,
    this.totalCount = kLabelCount,
    this.showLogoActions = true,
    this.hasLogo = false,
    this.onPickLogo,
    this.onRemoveLogo,
    required this.onClearAll,
    required this.onPrint,
    required this.onSavePdf,
    this.onCameraScan,
    this.subtitle =
        'Barkod okutun; her hane ürün adı + fiyatıyla A4 raf etiketine dönüşür.',
    this.compact = false,
    this.badgeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      // Kamera ile sürekli tara (mobil/native) — barkodları sırayla haneye ekler.
      if (onCameraScan != null)
        ElevatedButton.icon(
          onPressed: onCameraScan,
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: const Text('Kamera ile Tara'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
      // Logo yükle (yalnız dar-logo sekmesi; Geniş Logo'da marka tentesi sabit).
      if (showLogoActions)
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
      if (showLogoActions && hasLogo)
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
                badgeOverride ?? '$filledCount / $totalCount etiket',
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
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
  final int itemCount;
  final bool wide; // true → Geniş Logo state'i (labelWideSheetProvider)
  final bool quad; // true → Büyük Etiket state'i (labelQuadSheetProvider)
  final Future<void> Function(int, String) onSubmitted;
  final void Function(int) onClear;

  const _InputColumn({
    required this.controllers,
    required this.focusNodes,
    required this.errors,
    required this.activeIndex,
    required this.onSubmitted,
    required this.onClear,
    this.itemCount = kLabelCount,
    this.wide = false,
    this.quad = false,
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
              itemCount: itemCount,
              itemBuilder: (context, i) {
                return _SlotInputRow(
                  index: i,
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  isActive: activeIndex == i,
                  isError: errors.contains(i),
                  wide: wide,
                  quad: quad,
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
  final bool wide; // true → Geniş Logo state'i (labelWideSheetProvider)
  final bool quad; // true → Büyük Etiket state'i (labelQuadSheetProvider)
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
    this.wide = false,
    this.quad = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = quad
        ? ref.watch(labelQuadSheetProvider.select((s) => s.slots[index]))
        : wide
            ? ref.watch(labelWideSheetProvider.select((s) => s.slots[index]))
            : ref.watch(labelSheetProvider.select((s) => s.slots[index]));

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: s == null
          ? const SizedBox.expand()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Üst bant: logo (sol) + FİYAT hero (baskın, sağ)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 69,
                      height: 49,
                      child: logoBytes != null
                          ? Image.memory(logoBytes!, fit: BoxFit.contain)
                          : const Icon(Icons.storefront,
                              color: AppColors.primary, size: 39),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '${formatNumber(s.price)} TL',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1,
                            color: Colors.black,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Ürün adı (2 satır, taşarsa kısalt) — hücre genişliğine ortalı
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    s.productName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Barkod çizgileri (Code128) — esnek: sabit öğeler (üst bant, ürün
                // adı, alt satır) yerini korur; taşarsa yalnız barkod çizgisi
                // kısalır. Yatayda %80'e ortalı (widthFactor güvenli).
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.8,
                      child: BarcodeWidget(
                        barcode: bc.Barcode.code128(),
                        data: s.barcode,
                        drawText: false,
                        color: Colors.black,
                        errorBuilder: (context, error) =>
                            const SizedBox.shrink(),
                      ),
                    ),
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
                          fontSize: 16,
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
// Büyük Etiket — canlı A4 önizleme (KARAR v1.19): merkez haç ile 2 sütun × 2
// satır = 4 A5 etiket. Hücre 105×148.5mm, dış margin YOK (merkez haç = bitişik
// hücre kenarlıkları), iç güvenli boşluk 6mm. Etiket-içi düzen dar-logo (Yeni
// Etiket) _LabelCell ile aynı öğe seti, A5'e oranlanmış (~1.8× büyük). Önizleme
// = HTML = PDF BİREBİR. Mağaza logosu dar-logo'nun kalıcı store logosundan gelir.
// ═══════════════════════════════════════════════════════════════════════════

// İç güvenli boşluk 6mm @96dpi ≈ 22.7px (kırpılma önleme; dış margin YOK).
const double _kQuadPad = 6 * 3.7795;

// KARAR v1.20.1 — üst bant (kırmızı) SABİT yükseklik: v1.20'de bant "içerik
// kadar esniyordu" (1 satırlık ürün adıyla 2 satırlık arasında toplam bant
// yüksekliği değişiyordu); bu + fiyat kutusunun sabit bütçesi birleşince barkod
// `Expanded` alanı sıfır/negatif yüksekliğe düşüp `barcode` paketinin
// `assert(height > 0)` kontrolüyle GERÇEK bir çökmeye yol açıyordu. Bant artık
// 2 satırlık ürün adı DAHİL en kötü durum baştan hesaplanıp SABİTLENİR — 1
// satırlık kısa adlarda bandın altında boşluk kalması sorun değil, önemli olan
// TOPLAM yüksekliğin ürün adı uzunluğuna göre ASLA değişmemesi (barkod alanının
// payı böylece deterministik kalır). mm cinsinden (PDF/HTML aynı değeri
// paylaşır, üç çıktı BİREBİR); @96dpi px karşılığı türetilir.
const double _kQuadTopBandHeightMm = 23.3;
const double _kQuadTopBandHeight = _kQuadTopBandHeightMm * 3.7795; // ≈88px

// Savunma katmanı (KARAR v1.20.1 madde 3): barkod alanına ayrılan gerçek
// yükseklik bu eşiğin altına düşerse `BarcodeWidget` HİÇ render edilmez (boş
// bırakılır) — `assert`/exception asla fırlatılmaz. Normal koşulda (madde 1
// ile) bu dala hiç girilmemesi beklenir, saf bir güvenlik ağıdır.
const double _kQuadBarcodeMinHeight = 8;

class _QuadPreviewPane extends ConsumerWidget {
  const _QuadPreviewPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(labelQuadSheetProvider).slots;
    final logoDataUrl = ref.watch(labelSheetProvider).logoDataUrl;
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
          child: _QuadA4Canvas(slots: slots, logoDataUrl: logoDataUrl),
        ),
      ),
    );
  }
}

class _QuadA4Canvas extends StatelessWidget {
  final List<LabelSlot?> slots;
  final String? logoDataUrl;

  const _QuadA4Canvas({required this.slots, required this.logoDataUrl});

  @override
  Widget build(BuildContext context) {
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
      // Dış margin YOK — çeyrekler tam yarım sayfa; merkez haç hücre
      // kenarlıklarından oluşur.
      child: Column(
        children: List.generate(kQuadRows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(kQuadCols, (c) {
                final idx = r * kQuadCols + c;
                return Expanded(
                  child: _QuadLabelCell(
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

// Büyük Etiket A4 önizleme tuvalini (2×2) golden/görsel doğrulama için üretir.
@visibleForTesting
Widget buildQuadCanvasForGolden(List<LabelSlot?> slots, {String? logoDataUrl}) =>
    _QuadA4Canvas(slots: slots, logoDataUrl: logoDataUrl);

// Tek Büyük Etiket hücresi (KARAR v1.20 — kırmızı başlık bandı + renkli fiyat
// kutusu, rozetler kaldırıldı): üst bant SOL logo + "ÖZEL FİYAT"/ürün adı
// (kırmızı zemin, `AppColors.danger`) → beyaz+kırmızı-kenarlıklı FİYAT kutusu
// ("SATIŞ FİYATI" / fiyat hero / "KDV DAHİLDİR") → kesikli nötr ayraç → esnek
// Code128 %80 → alt satır [barkod no sol · tarih sağ] (DEĞİŞMEDİ, v1.13 deseni).
class _QuadLabelCell extends StatelessWidget {
  final LabelSlot? slot;
  final Uint8List? logoBytes;

  const _QuadLabelCell({required this.slot, required this.logoBytes});

  @override
  Widget build(BuildContext context) {
    final s = slot;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          // İnce nötr hairline (merkez haç + kesim kılavuzu; altın YOK).
          color: s == null ? const Color(0xFFE0E0E0) : const Color(0xFFB8B8B8),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.all(_kQuadPad),
      child: s == null
          ? const SizedBox.expand()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 1. Üst bant: KIRMIZI zemin, tam genişlik, köşe radius YOK.
                //    SOL logo (renkli; yoksa BEYAZ storefront fallback — bu
                //    banda özel istisna) + "ÖZEL FİYAT" + ürün adı (UPPERCASE).
                Container(
                  key: const Key('quadTopBand'),
                  width: double.infinity,
                  height: _kQuadTopBandHeight,
                  color: AppColors.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 52,
                        child: logoBytes != null
                            ? Image.memory(logoBytes!, fit: BoxFit.contain)
                            : const Icon(Icons.storefront,
                                color: Colors.white, size: 44),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ÖZEL FİYAT',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.productName.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 3. Fiyat kutusu: beyaz zemin + kırmızı ince kenarlık.
                Container(
                  key: const Key('quadPriceBox'),
                  width: double.infinity,
                  // KARAR v1.20.1 madde 2: dikey iç boşluk ~25% daraltıldı
                  // (10 → 7.5) — ek güvenlik payı için; renk/sıra/hiyerarşi
                  // DEĞİŞMEDİ.
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.danger, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SATIŞ FİYATI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '${formatNumber(s.price)} TL',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 92,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1,
                            color: AppColors.danger,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KDV DAHİLDİR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.danger.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 4. Kesikli ayraç — nötr `#B8B8B8` (mevcut kesim-kılavuzu grisi).
                const _QuadDashedDivider(color: Color(0xFFB8B8B8)),
                const SizedBox(height: 8),
                // 5. Barkod çizgileri (Code128) — esnek: sabit öğeler yerini
                // korur; taşarsa yalnız barkod çizgisi kısalır. %80'e ortalı.
                Expanded(
                  key: const Key('quadBarcodeArea'),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Savunma katmanı (KARAR v1.20.1 madde 3): gerçek
                      // yükseklik eşiğin altındaysa barkodu HİÇ render etme
                      // — `barcode` paketinin `assert(height > 0)` çökmesi
                      // asla tetiklenmez. Normal koşulda (madde 1 ile) bu
                      // dala hiç girilmemesi beklenir.
                      if (constraints.maxHeight < _kQuadBarcodeMinHeight) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.8,
                          child: BarcodeWidget(
                            barcode: bc.Barcode.code128(),
                            data: s.barcode,
                            drawText: false,
                            color: Colors.black,
                            errorBuilder: (context, error) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 6. En alt: barkod no (sol) + oluşturma tarihi (sağ) — DEĞİŞMEDİ.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        s.barcode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 0.5,
                          color: Colors.black,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      formatShortDate(s.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
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

// Kesikli ayraç (KARAR v1.20) — pdf paketinde native dashed-border yok, bu
// yüzden PDF tarafında da aynı "eşit alternatif segment" deseni kullanılır
// (önizleme = HTML = PDF birebir aynı görsel dil; HTML tarafı native
// `border-top: dashed` ile aynı sonucu verir).
class _QuadDashedDivider extends StatelessWidget {
  final Color color;
  static const int _segments = 24;

  const _QuadDashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.4,
      child: Row(
        children: List.generate(_segments, (i) {
          return Expanded(
            child: Container(color: i.isEven ? color : Colors.transparent),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Geniş Logo — canlı A4 önizleme (2 sütun × 5 satır = 10 etiket, KARAR v1.14 /
// v1.14.2 / v1.14.4). Hücre 88×55mm; üst/alt kenar 11mm, sol/sağ kenar 17mm.
// Marka figürü (RENKLİ) hücreyi doldurur; fiyat/ad/barkod figür üzerine oranlı
// bindirilir (önizleme = HTML = PDF BİREBİR).
// ═══════════════════════════════════════════════════════════════════════════

// A4 önizleme kenar boşluğu (KARAR v1.14.4 — hücre 94→88mm): üst/alt 11mm,
// sol/sağ 17mm @96dpi → (210−2×88)/2 = 17mm, hücre genişliği tam 88mm.
const double _kWideMargin = 11 * 3.7795; // dikey ≈ 41.6px
const double _kWideMarginH = 17 * 3.7795; // yatay ≈ 64.25px

// Etiket-içi hizalama oranları (hücre = figür; figür crop'undan ölçüldü). Bu
// oranlar HTML/PDF ile birebir paylaşılır. Fiyat = tentenin açık iç dikdörtgeni;
// gövde = yan çizgilerin içi (alt çizginin üstünde).
const double _kWFigPriceLeft = 0.13;
const double _kWFigPriceTop = 0.065;
const double _kWFigPriceW = 0.74;
const double _kWFigPriceH = 0.25;
const double _kWFigBodyLeft = 0.10;
const double _kWFigBodyTop = 0.585;
const double _kWFigBodyW = 0.80;
const double _kWFigBodyH = 0.395;
const double _kWFigBarcodeH = 0.13; // barkod çizgi yüksekliği (yarıya indi)
const double _kWFigBottomH = 0.095; // alt satır (barkod no + tarih)

// Ürün adı (KARAR v1.14.4): ad, gövdenin üst esnek alanında ÜSTE hizalı
// (topCenter). v1.14.3'teki 1.5 harf aşağı-itme, 2 satırlı adlar barkod
// çizgilerine giriyordu → ~5mm yukarı alındı (shift 0). Barkod + alt satır
// YERİNDE KALIR.
const double _kWNameSize = 12;
const double _kWNameShift =
    2.5 * 3.7795; // v1.14.6: ad 2.5mm aşağı (≈9.45px @96dpi), üste hizalı sabit offset

class _WidePreviewPane extends ConsumerWidget {
  const _WidePreviewPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelWideSheetProvider);
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
          child: _WideA4Canvas(slots: state.slots),
        ),
      ),
    );
  }
}

class _WideA4Canvas extends StatelessWidget {
  final List<LabelSlot?> slots;

  const _WideA4Canvas({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kA4Width,
      height: _kA4Height,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        vertical: _kWideMargin,
        horizontal: _kWideMarginH,
      ),
      child: Column(
        children: List.generate(kWideRows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(kWideCols, (c) {
                final idx = r * kWideCols + c;
                return Expanded(child: _WideLabelCell(slot: slots[idx]));
              }),
            ),
          );
        }),
      ),
    );
  }
}

// Geniş Logo A4 önizleme tuvalini (2×5) golden/görsel doğrulama için üretir.
// Yalnız test amaçlı (tasarım-lideri hiza denetimi); üretim akışında kullanılmaz.
@visibleForTesting
Widget buildWideCanvasForGolden(List<LabelSlot?> slots) =>
    _WideA4Canvas(slots: slots);

// Tek Geniş Logo etiket hücresi (figür arka planı + fiyat/ad/barkod overlay,
// KARAR v1.14.2). Figür hücreyi doldurur (RENKLİ); fiyat tentenin açık iç
// dikdörtgeninin merkezine, ürün adı + barkod + alt satır gövdede (yan
// çizgilerin içinde) oranlı bindirilir. Öğeler siyah/beyaz.
class _WideLabelCell extends StatelessWidget {
  final LabelSlot? slot;

  const _WideLabelCell({required this.slot});

  @override
  Widget build(BuildContext context) {
    final s = slot;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              s == null ? const Color(0xFFE0E0E0) : const Color(0xFFB8B8B8),
          width: 0.6,
        ),
      ),
      child: s == null
          ? const SizedBox.expand()
          : LayoutBuilder(
              builder: (ctx, cons) {
                final w = cons.maxWidth;
                final h = cons.maxHeight;
                return Stack(
                  children: [
                    // Figür arka planı — hücreyi doldurur (BoxFit.fill).
                    Positioned.fill(
                      child: Image.asset(
                        'genis_logo_figur.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    // FİYAT — tentenin açık iç dikdörtgeni merkezine ortalı.
                    Positioned(
                      left: w * _kWFigPriceLeft,
                      top: h * _kWFigPriceTop,
                      width: w * _kWFigPriceW,
                      height: h * _kWFigPriceH,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${formatNumber(s.price)} TL',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1,
                              color: Colors.black,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gövde: ürün adı + barkod + alt satır (yan çizgilerin içi).
                    Positioned(
                      left: w * _kWFigBodyLeft,
                      top: h * _kWFigBodyTop,
                      width: w * _kWFigBodyW,
                      height: h * _kWFigBodyH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Ürün adı (ortalı, en çok 2 satır) — üstteki esnek
                          // alan. v1.14.4: ÜSTE hizalı (_kWNameShift=0); 2 satır
                          // artık barkoda girmez. ClipRect taşarsa kırpar.
                          Expanded(
                            child: ClipRect(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: _kWNameShift),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    s.productName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: _kWNameSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Code128 barkod — yarı yükseklik, gövde iç genişliğinde.
                          SizedBox(
                            width: double.infinity,
                            height: h * _kWFigBarcodeH,
                            child: BarcodeWidget(
                              barcode: bc.Barcode.code128(),
                              data: s.barcode,
                              drawText: false,
                              color: Colors.black,
                              errorBuilder: (context, error) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          // Alt satır: barkod no SOLDA · tarih SAĞDA.
                          SizedBox(
                            height: h * _kWFigBottomH,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    s.barcode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                      color: Colors.black,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  formatShortDate(s.createdAt),
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF555555),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ürün Etiketi (KARAR v1.21) — sol bölge: barkod+adet girişi + kalem listesi.
// Adet-tabanlı: barkod okut/Enter → ürün çözülür (bekleyen), adet onaylanınca
// kalem listeye eklenir. Aktif barkod hanesi = ince sol altın şerit + ink
// kenarlık (§5); çözülemeyen = danger uyarı. Fiyat/logo YOK.
// ═══════════════════════════════════════════════════════════════════════════

class _ProductInputColumn extends StatelessWidget {
  final TextEditingController barcodeController;
  final TextEditingController qtyController;
  final FocusNode barcodeFocus;
  final FocusNode qtyFocus;
  final bool barcodeActive;
  final Product? pending; // barkodu çözülmüş, adet bekleyen ürün
  final bool isError;
  final List<ProductLabelItem> items;
  final bool shrinkWrap; // mobil: sayfa scroll'una gömülü (iç scroll yok)
  final Future<void> Function(String) onBarcodeSubmitted;
  final VoidCallback onAdd;
  final void Function(int) onRemoveItem;
  final void Function(int, int) onUpdateQty;

  const _ProductInputColumn({
    required this.barcodeController,
    required this.qtyController,
    required this.barcodeFocus,
    required this.qtyFocus,
    required this.barcodeActive,
    required this.pending,
    required this.isError,
    required this.items,
    required this.onBarcodeSubmitted,
    required this.onAdd,
    required this.onRemoveItem,
    required this.onUpdateQty,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    // Aktif hane = ince sol altın şerit + ink kenarlık (§5). Hata → danger.
    final Color borderColor = isError
        ? AppColors.danger
        : barcodeActive
            ? AppColors.primary
            : AppColors.divider;

    final barcodeField = Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: borderColor, width: barcodeActive ? 1.4 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 44,
              color: barcodeActive ? AppColors.gold : Colors.transparent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: barcodeController,
                  focusNode: barcodeFocus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Barkod okut / gir',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: onBarcodeSubmitted,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final qtyField = SizedBox(
      width: 74,
      child: TextField(
        controller: qtyController,
        focusNode: qtyFocus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Adet',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        onSubmitted: (_) => onAdd(),
      ),
    );

    final itemRows = <Widget>[
      for (var i = 0; i < items.length; i++)
        _ProductItemRow(
          index: i,
          item: items[i],
          onRemove: () => onRemoveItem(i),
          onUpdateQty: (q) => onUpdateQty(i, q),
        ),
    ];

    final itemList = items.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space16),
            child: Text(
              'Henüz ürün eklenmedi. Barkod okutup adet girin.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          )
        : (shrinkWrap
            ? Column(children: itemRows)
            : Expanded(
                child: ListView(children: itemRows),
              ));

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const _SectionLabel('Barkod & Adet'),
          const SizedBox(height: AppSizes.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: barcodeField),
              const SizedBox(width: AppSizes.space8),
              qtyField,
              const SizedBox(width: AppSizes.space8),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnDark,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                child: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space6),
          // Çözüm bilgisi / hata uyarısı.
          if (pending != null)
            Text(
              '${pending!.name}  ·  ürün çözüldü, adet girin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            )
          else if (isError)
            const Text(
              'Ürün bulunamadı.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            )
          else
            const SizedBox(height: 14),
          const SizedBox(height: AppSizes.space12),
          const _SectionLabel('Eklenen Ürünler'),
          const SizedBox(height: AppSizes.space8),
          itemList,
        ],
      ),
    );
  }
}

// Tek kalem satırı: ürün adı + barkod (üst) · adet ± düzenleyici + sil.
class _ProductItemRow extends StatelessWidget {
  final int index;
  final ProductLabelItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onUpdateQty;

  const _ProductItemRow({
    required this.index,
    required this.item,
    required this.onRemove,
    required this.onUpdateQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item.barcode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Adet ± düzenleyici.
          IconButton(
            onPressed: () => onUpdateQty(item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Azalt',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: () => onUpdateQty(item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Artır',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.textMuted,
            tooltip: 'Kalemi sil',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ürün Etiketi — canlı çok-sayfalı A4 önizleme (KARAR v1.21): 6 sütun × 12 satır
// = 72 etiket/sayfa. Kalemler adet kadar çoğaltılıp sırayla dizilir; toplam > 72
// ise 2., 3. sayfa alt alta gösterilir. Sayfa boşluğu üst/alt 10mm, yatay 0.
// Hücre 35×23mm, 3mm iç pay → içerik 29×17mm. Etiket-içi: ürün adı 2 satır sabit
// (ortalı) + Code128 barkod (SABİT 7mm) + barkod no. Fiyat/logo YOK. Canlı
// önizlemede ince nötr baskı-grisi kesim kılavuzu; baskıda (PDF/HTML) çizgi YOK.
// ═══════════════════════════════════════════════════════════════════════════

const double _kProdMmPx = 3.7795; // 1mm @96dpi
const double _kProdMarginV = 10 * _kProdMmPx; // sayfa üst/alt boşluğu ≈37.8px
const double _kProdCellPad = 3 * _kProdMmPx; // hücre iç pay ≈11.34px
const double _kProdNameH = 4.4 * _kProdMmPx; // ürün adı sabit alan ≈16.63px
// Barkod çizgi bandı SABİT 7mm (KARAR v1.21.1) ≈26.46px — üç çıktıda birebir.
const double _kProdBarcodeHeight = 7 * _kProdMmPx;
// Savunma katmanı (KARAR v1.20.1 dersi): barkod alanının gerçek yüksekliği bu
// eşiğin altına düşerse BarcodeWidget HİÇ render edilmez (assert asla fırlatılmaz).
// Sabit 7mm'de tetiklenmez ama savunma katmanı korunur.
const double _kProdBarcodeMinHeight = 8;

class _ProductPreviewPane extends ConsumerWidget {
  // Masaüstü: kendi dikey scroll'u (bounded Expanded içinde). Mobil: false →
  // shrink; dış sayfa scroll'u tüm sayfaları taşır (nested scroll yok).
  final bool scrollable;

  const _ProductPreviewPane({this.scrollable = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(labelProductSheetProvider).items;
    final pages = paginateProductLabels(items);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final pageW = c.maxWidth;
          final pageH = pageW * (_kA4Height / _kA4Width);
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.space6),
                    child: _SectionLabel('Sayfa ${i + 1} / ${pages.length}'),
                  ),
                SizedBox(
                  width: pageW,
                  height: pageH,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _ProductA4Canvas(slots: pages[i]),
                  ),
                ),
                if (i < pages.length - 1)
                  const SizedBox(height: AppSizes.space16),
              ],
            ],
          );
          return scrollable
              ? SingleChildScrollView(child: content)
              : content;
        },
      ),
    );
  }
}

class _ProductA4Canvas extends StatelessWidget {
  final List<ProductLabelItem?> slots;

  const _ProductA4Canvas({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kA4Width,
      height: _kA4Height,
      color: Colors.white,
      // Sayfa boşluğu: üst/alt 10mm, yatay 0 (etiketler tam genişliği doldurur).
      padding: const EdgeInsets.symmetric(vertical: _kProdMarginV),
      child: Column(
        children: List.generate(kProductLabelRows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(kProductLabelCols, (c) {
                final idx = r * kProductLabelCols + c;
                final it = idx < slots.length ? slots[idx] : null;
                return Expanded(child: _ProductLabelCell(item: it));
              }),
            ),
          );
        }),
      ),
    );
  }
}

// Ürün Etiketi A4 önizleme tuvalini (6×12) golden/görsel doğrulama için üretir.
@visibleForTesting
Widget buildProductLabelPageForGolden(List<ProductLabelItem?> slots) =>
    _ProductA4Canvas(slots: slots);

// Tek Ürün Etiketi hücresi (KARAR v1.21). Boş hane → yalnız ince nötr baskı-
// grisi kesim kılavuzu (yalnız canlı önizleme; baskıda çizgi YOK). Etiket-içi:
// ürün adı 2 satır sabit (ortalı, flex:0) + Code128 barkod (SABİT 7mm, savunma
// eşiği altında render edilmez) + barkod no (ortalı, tabular, flex:0).
class _ProductLabelCell extends StatelessWidget {
  final ProductLabelItem? item;

  const _ProductLabelCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          // İnce nötr baskı-grisi kesim kılavuzu (altın DEĞİL); baskıda YOK.
          color: it == null
              ? const Color(0xFFE0E0E0)
              : const Color(0xFFC9CDD6),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(_kProdCellPad),
      child: it == null
          ? const SizedBox.expand()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 1. Ürün adı — 2 satır sabit alan, ORTALI, uzun ad ellipsis.
                //    ClipRect: font taşarsa çizim kırpılır (overflow hatası yok).
                SizedBox(
                  height: _kProdNameH,
                  width: double.infinity,
                  child: ClipRect(
                    child: Center(
                      child: Text(
                        it.productName.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                // 2. Code128 barkod — SABİT 7mm (KARAR v1.21.1); sabit öğeler
                //    (ad, no) yerini korur, artan pay alt satırın altında kalır.
                //    %80'e ortalı. Savunma: yükseklik eşiğin altındaysa HİÇ
                //    render etme (sabit 7mm'de tetiklenmez ama katman korunur).
                SizedBox(
                  key: const Key('prodBarcodeArea'),
                  height: _kProdBarcodeHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxHeight < _kProdBarcodeMinHeight) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.8,
                          child: BarcodeWidget(
                            barcode: bc.Barcode.code128(),
                            data: it.barcode,
                            drawText: false,
                            color: Colors.black,
                            errorBuilder: (context, error) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 3. Barkod no — ORTALI, tabular, siyah (FittedBox taşmayı önler).
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      it.barcode,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 7.5,
                        letterSpacing: 0.3,
                        color: Colors.black,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Üst sekme seçici (KARAR v1.14 / v1.21): Yeni Etiket · Geniş Logo · Büyük Etiket
// · Ürün Etiketi · Kayıtlı Dosyalar. Kasa sekme dili (SegmentedButton, aktif
// sekme token dili). Responsive: mobilde kısa etiketler
// ("Yeni"·"Geniş"·"Büyük"·"Ürün"·"Dosyalar") + ikonsuz, yatay-kaydırılabilir
// (SingleChildScrollView) → 5 segment dar ekranda taşmaz (kasa KARAR v1.9.5 emsali).
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
            label: Text(
              mobile ? 'Yeni' : 'Yeni Etiket',
              maxLines: 1,
              softWrap: false,
            ),
            icon: mobile ? null : const Icon(Icons.add_box_outlined, size: 18),
          ),
          ButtonSegment(
            value: _LabelTab.genis,
            label: Text(
              mobile ? 'Geniş' : 'Geniş Logo',
              maxLines: 1,
              softWrap: false,
            ),
            icon: mobile
                ? null
                : const Icon(Icons.aspect_ratio_outlined, size: 18),
          ),
          ButtonSegment(
            value: _LabelTab.buyuk,
            label: Text(
              mobile ? 'Büyük' : 'Büyük Etiket',
              maxLines: 1,
              softWrap: false,
            ),
            icon: mobile
                ? null
                : const Icon(Icons.crop_square_outlined, size: 18),
          ),
          ButtonSegment(
            value: _LabelTab.urun,
            label: Text(
              mobile ? 'Ürün' : 'Ürün Etiketi',
              maxLines: 1,
              softWrap: false,
            ),
            icon: mobile
                ? null
                : const Icon(Icons.qr_code_2_outlined, size: 18),
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
