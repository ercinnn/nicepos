import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scan_sound.dart';

/// Tek bir kamera okutmasının sonucu (etiket haneleri sürekli tarama akışı).
enum LabelScanStatus {
  /// Ürün çözüldü ve ilk boş haneye yerleştirildi.
  placed,

  /// Barkod çözülemedi (bilinmeyen / offline cache miss).
  notFound,

  /// Tüm 24 hane dolu — yerleştirilecek boş hane kalmadı.
  full,
}

/// Sürekli tarama geri bildirimi: durum + (varsa) ürün adı/fiyatı + güncel dolu
/// hane sayısı. Kamera sayfası bu değerlerle üst ilerleme + alt sonuç kartını
/// canlı günceller.
class LabelScanFeedback {
  final LabelScanStatus status;
  final String? productName;
  final num? price;
  final int filledCount;

  const LabelScanFeedback({
    required this.status,
    required this.filledCount,
    this.productName,
    this.price,
  });
}

/// Etiket haneleri için **sürekli** barkod tarama sayfası (yalnız native).
///
/// Sales ekranının tek-atış [openBarcodeScanner]'ından farkı: kamera açık kalır,
/// her okutmada [onScan] çağrılır (barkod → bellek cache'ten anında çözüm →
/// ilk boş haneye yerleştirme) ve imleç bir sonraki haneye ilerler. Böylece 24
/// etiket tek kamera oturumunda, internet olmadan da hızla doldurulur.
///
/// Aynı barkodun ardışık kare tekrarını bastırmak için 1.5 sn'lik bir soğuma
/// penceresi vardır (farklı ürünler anında okunur; aynı ürünü ikinci bir haneye
/// koymak için ~1.5 sn ara yeterli).
class LabelScanSheet extends StatefulWidget {
  final Future<LabelScanFeedback> Function(String barcode) onScan;
  final int totalCount;
  final int initialFilled;

  const LabelScanSheet({
    super.key,
    required this.onScan,
    required this.totalCount,
    required this.initialFilled,
  });

  @override
  State<LabelScanSheet> createState() => _LabelScanSheetState();
}

class _LabelScanSheetState extends State<LabelScanSheet>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoStart: false,
  );

  bool _processing = false; // aynı anda tek okutma işlenir
  String? _lastCode; // son kabul edilen barkod (soğuma için)
  DateTime? _lastAcceptAt; // son kabul zamanı
  late int _filled = widget.initialFilled;
  LabelScanStatus? _lastStatus;
  String? _lastName;
  num? _lastPrice;

  // autoStart:false + elle start(): start() bitmeden stop()/dispose()
  // çağrılırsa native kamera oturumu yarım açılışta takılıp kapanışı
  // tutuklaştırıyordu — kapanış her zaman bu future'ı bekleyip öyle durur.
  Future<void>? _startFuture;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFuture = _controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startFuture = _controller.start();
    } else if (state == AppLifecycleState.inactive) {
      _controller.stop();
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      await _startFuture;
    } catch (_) {}
    await _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    final now = DateTime.now();
    // Aynı barkodun ardışık kare tekrarını bastır (soğuma penceresi).
    if (code == _lastCode &&
        _lastAcceptAt != null &&
        now.difference(_lastAcceptAt!) < const Duration(milliseconds: 1500)) {
      return;
    }

    _processing = true;
    final fb = await widget.onScan(code);
    if (!mounted) return;
    setState(() {
      _lastStatus = fb.status;
      _lastName = fb.productName;
      _lastPrice = fb.price;
      _filled = fb.filledCount;
      if (fb.status == LabelScanStatus.placed) {
        _lastCode = code;
        _lastAcceptAt = now;
      }
    });
    if (fb.status == LabelScanStatus.placed) {
      HapticFeedback.lightImpact();
      playScanBeep(success: true); // başarı bipi (KARAR v1.14.1)
    } else if (fb.status == LabelScanStatus.notFound) {
      HapticFeedback.heavyImpact();
      playScanBeep(success: false); // danger uyarı sesi (KARAR v1.14.1)
    }
    _processing = false;
  }

  @override
  Widget build(BuildContext context) {
    final complete = _filled >= widget.totalCount;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Etiket Tara', style: TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'Fener',
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_outlined),
              tooltip: 'Kamerayı çevir',
              onPressed: () => _controller.switchCamera(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                onPressed: _close,
                child: const Text('Bitir',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            // Üst: ilerleme rozeti (N / 24 hane)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: complete
                        ? AppColors.gold.withValues(alpha: 0.95)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.goldLight, width: 1.5),
                  ),
                  child: Text(
                    complete
                        ? '24 / 24 hane doldu — Bitir'
                        : '$_filled / ${widget.totalCount} hane',
                    style: TextStyle(
                      color: complete ? Colors.black : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            // Orta: kılavuz çerçeve
            Center(
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.goldLight, width: 2.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Alt: son okutma sonucu + ipucu
            Positioned(
              bottom: 36,
              left: 16,
              right: 16,
              child: Center(child: _feedbackCard(complete)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCard(bool complete) {
    // Varsayılan ipucu (henüz okutma yok).
    if (_lastStatus == null) {
      return _pill(
        color: Colors.black.withValues(alpha: 0.6),
        child: const Text(
          'Barkodu çerçeveye getirin — sıradaki haneye eklenir',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    }

    switch (_lastStatus!) {
      case LabelScanStatus.placed:
        final price = _lastPrice != null ? '${formatNumber(_lastPrice!)} TL' : '';
        return _pill(
          color: AppColors.success.withValues(alpha: 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _lastName ?? 'Eklendi',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        );
      case LabelScanStatus.notFound:
        return _pill(
          color: AppColors.danger.withValues(alpha: 0.92),
          child: const Text(
            'Ürün bulunamadı — başka barkod deneyin',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
      case LabelScanStatus.full:
        return _pill(
          color: AppColors.gold.withValues(alpha: 0.95),
          child: const Text(
            'Tüm haneler dolu — Bitir\'e dokunun',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        );
    }
  }

  Widget _pill({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Sürekli etiket tarama sayfasını açar (yalnız native; web'de no-op).
Future<void> openLabelScanSheet(
  BuildContext context, {
  required Future<LabelScanFeedback> Function(String barcode) onScan,
  required int totalCount,
  required int initialFilled,
}) async {
  if (kIsWeb) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LabelScanSheet(
        onScan: onScan,
        totalCount: totalCount,
        initialFilled: initialFilled,
      ),
    ),
  );
}
