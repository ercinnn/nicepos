import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';

/// Yalnızca mobil platformlarda kullanılır (kIsWeb false ise).
/// Kamerayı açar, barkod okuyunca [onDetected] callback'ini çağırır.
class BarcodeScannerModal extends StatefulWidget {
  final ValueChanged<String> onDetected;

  const BarcodeScannerModal({super.key, required this.onDetected});

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );
  bool _detected = false;

  // autoStart:false + elle start(): start() bitmeden stop()/dispose()
  // çağrılırsa native kamera oturumu yarım açılışta takılıp kapanışı
  // tutuklaştırıyordu — kapanış her zaman bu future'ı bekleyip öyle durur
  // (bkz. label_scan_sheet.dart'taki aynı desen).
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_detected) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _detected = true;
    try {
      await _startFuture;
    } catch (_) {}
    await _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onDetected(value);
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Barkod Tara', style: TextStyle(fontSize: 16)),
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
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            // Kılavuz çerçeve
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
            // Alt ipucu
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Barkodu çerçeve içine getirin',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web'de kamera açılamaz — bu fonksiyon hiç çağrılmaz,
/// ama conditional import stub için tanımlı olması gerekir.
Future<void> openBarcodeScanner(
  BuildContext context,
  ValueChanged<String> onDetected,
) async {
  if (kIsWeb) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BarcodeScannerModal(onDetected: onDetected),
    ),
  );
}
