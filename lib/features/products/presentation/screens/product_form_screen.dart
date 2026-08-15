import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/network_timeout.dart';
import '../../../../core/utils/responsive.dart';
import '../../../labels/application/labels_provider.dart';
import '../../../labels/data/models/label_pool_item.dart';
import '../../../sales/presentation/widgets/barcode_scanner_modal.dart';
import '../../application/product_sync_service.dart';
import '../../application/products_provider.dart';
import '../../application/sync_status.dart';
import '../../data/local/pending_change_dao.dart';
import '../../data/local/product_local_cache_dao.dart';
import '../../data/models/company.dart';
import '../../data/models/pending_change.dart';
import '../../data/models/product.dart';
import '../widgets/equivalent_barcode_section.dart';

/// [prefix] (ör. "260814") ile başlayan, henüz [existing] kümesinde olmayan
/// ilk "XXX" (001..999) barkodu üretir — mobil "Yeni Ürün" ekranındaki
/// "+ barkod üret" butonu kullanır. Top-level (private değil) tutulur ki
/// test dosyasından ağ/widget kurulumu gerektirmeden doğrudan sınanabilsin.
/// Boşluk bulunmazsa (pratikte imkânsız, günde 999 barkod) son numarayı döner.
String nextBarcodeCandidate(String prefix, Set<String> existing) {
  for (var i = 1; i <= 999; i++) {
    final candidate = '$prefix${i.toString().padLeft(3, '0')}';
    if (!existing.contains(candidate)) return candidate;
  }
  return '${prefix}999';
}

class ProductFormScreen extends ConsumerStatefulWidget {
  /// null ise yeni ürün, aksi halde düzenlenecek ürünün id'si.
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeCtrl;
  late FocusNode _barcodeFocus;
  late TextEditingController _nameCtrl;
  late TextEditingController _price1Ctrl;
  late TextEditingController _price2Ctrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _criticalStockCtrl;
  late TextEditingController _vatRateCtrl;
  late TextEditingController _profitMargin1Ctrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _originCtrl;
  late TextEditingController _stockCodeCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _quickOrderCtrl;

  // "Diğer Detaylar" → Firma / Tarih / Durum.
  // Ürün Detayı (description) alanı bu üç parçayı ' & ' ayracıyla saklar:
  //   "$firma & $ggaayy & $statusLetter"  (ör. "PALA & 01/07/26 & Y")
  late TextEditingController _companyCtrl;
  late FocusNode _companyFocus;
  DateTime _detailDate = DateTime.now();
  String _statusLetter = 'Y'; // 'Y' = Yeni Eklendi, 'G' = Güncellendi

  bool _price1VatIncluded = true;
  bool _price2VatIncluded = true;
  bool _purchaseVatIncluded = true;
  bool _isOnlineActive = false;
  String? _groupId;
  String? _imageUrl;
  Uint8List? _pickedImageBytes;
  String _pickedImageExt = 'jpg';

  String? _currentId;
  bool _loaded = false;
  bool _saving = false;
  bool _deleting = false;

  /// Bu ürünün yerel kaydı sunucuyla henüz senkron olmadı (offline
  /// oluşturuldu/düzenlendi ve kuyrukta bekliyor) — `EquivalentBarcodeSection`
  /// bu bayrak `true` iken devre dışı kalır (bkz. o dosyanın `pendingSync` notu).
  bool _pendingSync = false;

  /// Senkron metotlarında karşılıklı tetiklenmeyi önleyen yeniden-giriş kilidi.
  bool _syncing = false;

  /// Barkod hanesi doldurulduğunda (taranarak/üretilerek/elle) `true` olur —
  /// mobilde ekranın ortasında "Ürünü Getir" belirir, barkod hanesi + kamera
  /// + "barkod üret" ikonu DIŞINDA her şey (sekmeler, Kaydet/Sil barı) devre
  /// dışı kalır. `_fetchByBarcode()` başında (Enter/orta buton/kamera akışı
  /// hepsi oradan geçer) `false`'a döner — kullanıcı bir kez "getir" deyince
  /// kilit kalkar (sonuç bulunsa da bulunmasa da).
  bool _awaitingFetch = false;

  /// "+ barkod üret" butonunun ağ/yerel-önbellek sorgusu sürerken küçük bir
  /// spinner göstermek için.
  bool _generatingBarcode = false;

  /// Ürün Adı mikrofon-ile-giriş (mobil/native, `!kIsWeb`) — `speech_to_text`
  /// yalnız ilk mikrofon dokunuşunda `initialize()` edilir (izin isteğini
  /// ekran açılışına değil, kullanıcı eylemine bağlar).
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  /// `ProductSyncService`'in son prob sonucu zaten "offline" diyorsa `true` —
  /// bu durumda `_loadProduct`/`_fetchByBarcode`/`_save` her seferinde 6sn'lik
  /// ağ timeout'unu tekrar tekrar beklemez, doğrudan yerel yola düşer. Bir
  /// dead-zone oturumunda bu bekleme yalnız BİR KEZ (offline durumu ilk
  /// tespit edilene kadar) ödenir. Bayrak bayat olabilir (bağlantı az önce
  /// geri gelmiş olabilir) — ama her offline kuyruğa düşüşte tetiklenen
  /// `notifyLocalQueueChanged()` arka planda hemen yeniden problar, bu yüzden
  /// bayatlık uzun sürmez.
  bool get _knownOffline =>
      !kIsWeb && ref.read(productSyncServiceProvider).phase == SyncPhase.offline;

  /// Ondalık alanlar için ortak girdi filtresi:
  /// yalnızca rakam ve TEK ondalık ayraç (virgül ya da nokta) kabul edilir.
  /// `2,50` ve `2.50` desteklenir; `1.234,5` (binlik ayraç) kasıtlı engellenir.
  final _decimalInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    TextInputFormatter.withFunction(
      (o, n) => RegExp(r'[.,]').allMatches(n.text).length > 1 ? o : n,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentId = widget.productId;
    _barcodeCtrl = TextEditingController();
    _barcodeFocus = FocusNode();
    _nameCtrl = TextEditingController();
    _price1Ctrl = TextEditingController(text: '0');
    _price2Ctrl = TextEditingController(text: '0');
    _purchasePriceCtrl = TextEditingController(text: '0');
    _stockCtrl = TextEditingController(text: '0');
    _criticalStockCtrl = TextEditingController(text: '0');
    _vatRateCtrl = TextEditingController(text: '20');
    _profitMargin1Ctrl = TextEditingController(text: '0');
    _unitCtrl = TextEditingController(text: 'Adet');
    _originCtrl = TextEditingController();
    _stockCodeCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _quickOrderCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    _companyFocus = FocusNode();

    if (widget.productId != null) {
      _loadProduct(widget.productId!);
    } else {
      _loaded = true;
    }
  }

  /// Önce ağdan (timeout'lu) dener; başarısız olursa (`!kIsWeb`) yerel
  /// önbelleğe düşer — dead-zone'da askıda kalmak yerine cihazda daha önce
  /// görülmüş ürünü açar. Ağdan başarıyla gelirse fırsatçı olarak önbelleğe
  /// yazılır (bir sonraki offline erişim için).
  Future<void> _loadProduct(String id) async {
    Product? product;
    var fromCache = false;
    if (_knownOffline) {
      product = await ref.read(productLocalCacheDaoProvider).fetchById(id);
      fromCache = product != null;
    } else {
      try {
        product = await withNetworkTimeout(ref.read(productRepositoryProvider).fetchById(id));
      } catch (_) {
        if (!kIsWeb) {
          product = await ref.read(productLocalCacheDaoProvider).fetchById(id);
          fromCache = product != null;
        }
      }
    }
    if (!mounted) return;

    var pendingSync = false;
    if (product != null && !kIsWeb) {
      final cacheDao = ref.read(productLocalCacheDaoProvider);
      if (fromCache) {
        pendingSync = await cacheDao.isPendingSync(id);
      } else {
        unawaited(cacheDao.markSynced(product));
      }
    }
    if (!mounted) return;

    if (product != null) _applyProduct(product);
    setState(() {
      _loaded = true;
      _pendingSync = pendingSync;
      _awaitingFetch = false;
    });
  }

  void _applyProduct(Product p) {
    _currentId = p.id;
    _barcodeCtrl.text = p.barcode ?? '';
    _nameCtrl.text = p.name;
    _price1Ctrl.text = _fmt(p.price1);
    _price2Ctrl.text = _fmt(p.price2);
    _purchasePriceCtrl.text = _fmt(p.purchasePrice);
    _stockCtrl.text = _fmt(p.stockQuantity);
    _criticalStockCtrl.text = _fmt(p.criticalStock);
    _vatRateCtrl.text = _fmt(p.vatRate);
    // Yüklenen üründen mevcut kâr oranını (Fiyat 1) doldur.
    _profitMargin1Ctrl.text = _fmtCalc(_profitMargin1);
    _unitCtrl.text = p.unit;
    _originCtrl.text = p.originCountry ?? '';
    _stockCodeCtrl.text = p.stockCode ?? '';
    _weightCtrl.text = p.weight == null ? '' : _fmt(p.weight!);
    _applyDescription(p.description);
    _quickOrderCtrl.text = p.quickListOrder?.toString() ?? '';
    _price1VatIncluded = p.price1VatIncluded;
    _price2VatIncluded = p.price2VatIncluded;
    _purchaseVatIncluded = p.purchasePriceVatIncluded;
    _isOnlineActive = p.isOnlineActive;
    _groupId = p.groupId;
    _imageUrl = p.imageUrl;
  }

  /// Formu `initState`'teki boş "Yeni Ürün" durumuna döndürür — iki çağıran:
  /// (1) `_fetchByBarcode` barkodun KESİN kayıtlı olmadığını öğrenince (eski
  /// ürünün bilgileri ekranda kalıp kafa karıştırmasın diye, [clearBarcode]
  /// `false` — kullanıcının az önce girdiği barkod korunur); (2) yeni bir
  /// ürün başarıyla kaydedilince, ekrandan çıkmadan sıradaki ürüne geçmek
  /// için ([clearBarcode] `true`). Çağıran taraf `setState` içine almalı.
  void _resetProductFields({required bool clearBarcode}) {
    _currentId = null;
    if (clearBarcode) _barcodeCtrl.clear();
    _nameCtrl.clear();
    _price1Ctrl.text = '0';
    _price2Ctrl.text = '0';
    _purchasePriceCtrl.text = '0';
    _stockCtrl.text = '0';
    _criticalStockCtrl.text = '0';
    _vatRateCtrl.text = '20';
    _profitMargin1Ctrl.text = '0';
    _unitCtrl.text = 'Adet';
    _originCtrl.clear();
    _stockCodeCtrl.clear();
    _weightCtrl.clear();
    _quickOrderCtrl.clear();
    _companyCtrl.clear();
    _detailDate = DateTime.now();
    _statusLetter = 'Y';
    _price1VatIncluded = true;
    _price2VatIncluded = true;
    _purchaseVatIncluded = true;
    _isOnlineActive = false;
    _groupId = null;
    _imageUrl = null;
    _pickedImageBytes = null;
    _pickedImageExt = 'jpg';
    _pendingSync = false;
    _awaitingFetch = false;
  }

  String _fmt(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Ürün Detayı (description) alanını üç parçaya ayrıştırır:
  /// firma & GG/AA/YY & durum. Tam 3 parça VE son parça {'Y','G'} ise
  /// parçalar alanlara dağıtılır; aksi halde eski serbest metin firma olarak
  /// alınır, tarih=bugün, durum='Y' (geriye dönük uyumluluk).
  void _applyDescription(String? description) {
    final raw = description ?? '';
    final parts = raw.split(' & ');
    if (parts.length == 3 &&
        (parts[2] == 'Y' || parts[2] == 'G')) {
      _companyCtrl.text = parts[0];
      _detailDate = _parseDate(parts[1]) ?? DateTime.now();
      _statusLetter = parts[2];
    } else {
      _companyCtrl.text = raw;
      _detailDate = DateTime.now();
      _statusLetter = 'Y';
    }
  }

  /// GG/AA/YY dizesini DateTime'a çevirir; hatalıysa null döner.
  DateTime? _parseDate(String s) {
    try {
      return DateFormat('dd/MM/yy', 'tr_TR').parseStrict(s.trim());
    } catch (_) {
      return null;
    }
  }

  /// Kayıt için description'ı kurar: "$firma & $ggaayy & $statusLetter".
  /// Üç parça HER ZAMAN yazılır (firma boş olsa bile ' & ' ayracı korunur).
  String _composeDescription() {
    final firma = _companyCtrl.text.trim();
    final ggaayy = DateFormat('dd/MM/yy', 'tr_TR').format(_detailDate);
    return '$firma & $ggaayy & $_statusLetter';
  }

  @override
  void dispose() {
    if (_isListening) _speech.stop();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _nameCtrl.dispose();
    _price1Ctrl.dispose();
    _price2Ctrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _criticalStockCtrl.dispose();
    _vatRateCtrl.dispose();
    _profitMargin1Ctrl.dispose();
    _unitCtrl.dispose();
    _originCtrl.dispose();
    _stockCodeCtrl.dispose();
    _weightCtrl.dispose();
    _quickOrderCtrl.dispose();
    _companyCtrl.dispose();
    _companyFocus.dispose();
    super.dispose();
  }

  num _num(TextEditingController c) => num.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  double get _profitMargin1 {
    final purchase = _num(_purchasePriceCtrl);
    final price1 = _num(_price1Ctrl);
    if (purchase == 0) return 0;
    return ((price1 - purchase) / purchase) * 100;
  }

  double get _profitMargin2 {
    final purchase = _num(_purchasePriceCtrl);
    final price2 = _num(_price2Ctrl);
    if (purchase == 0) return 0;
    return ((price2 - purchase) / purchase) * 100;
  }

  /// Hesap sonucunu alana yazmak için: en çok 2 ondalık, gereksiz sondaki
  /// sıfırları kırpar, binlik ayraç KULLANMAZ (alanlar `_num` ile parse
  /// edildiğinden nokta-binlik ayracı parse'ı bozardı).
  String _fmtCalc(double value) {
    if (!value.isFinite) return '0';
    var s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.isEmpty ? '0' : s;
  }

  /// Alış fiyatı veya kâr oranı değişince Fiyat 1'i hesaplar.
  /// Satış = alış × (1 + kâr / 100). Alış ≤ 0 ise hesap atlanır (0'a bölme yok).
  void _recalcPrice1FromMargin() {
    if (_syncing) return;
    final purchase = _num(_purchasePriceCtrl).toDouble();
    if (purchase <= 0) return;
    final margin = _num(_profitMargin1Ctrl).toDouble();
    final price1 = purchase * (1 + margin / 100);
    _syncing = true;
    // Yalnızca KARŞI alana yaz → imleç zıplaması olmaz.
    _price1Ctrl.text = _fmtCalc(price1);
    _syncing = false;
  }

  /// Fiyat 1 (satış) VEYA Alış fiyatı elle değişince kâr oranını hesaplar
  /// (satışı EZMEZ; satış her iki durumda da sabit kalır).
  /// Kâr% = (satış / alış − 1) × 100. Alış ≤ 0 ise hesap atlanır
  /// (0'a bölme yok; kâr alanı eski değerinde kalır, exception atılmaz).
  void _recalcMarginFromPrice1() {
    if (_syncing) return;
    final purchase = _num(_purchasePriceCtrl).toDouble();
    if (purchase <= 0) return;
    final price1 = _num(_price1Ctrl).toDouble();
    final margin = ((price1 / purchase) - 1) * 100;
    _syncing = true;
    _profitMargin1Ctrl.text = _fmtCalc(margin);
    _syncing = false;
  }

  /// "Diğer Detaylar" tarih alanı için tarih seçici (Türkçe yerel).
  Future<void> _pickDetailDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr'),
      initialDate: _detailDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _detailDate = picked);
  }

  /// Firma / Tarih / Durum / Kâr Oranı 2 / Ürün Grubu — hem masaüstü "Diğer
  /// Detaylar" hem mobil "Ürün Bilgisi" (Firma/Tarih/Durum mobilde buraya
  /// taşındı) sekmelerinden paylaşılan alt-widget'lar.
  Widget _buildFirmaField() {
    return _CompanyAutocompleteField(controller: _companyCtrl, focusNode: _companyFocus);
  }

  Widget _buildTarihField() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      onTap: _pickDetailDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tarih',
          suffixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          DateFormat('dd/MM/yy', 'tr_TR').format(_detailDate),
        ),
      ),
    );
  }

  Widget _buildDurumField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Durum',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Y', label: Text('Yeni Eklendi')),
            ButtonSegment(value: 'G', label: Text('Güncellendi')),
          ],
          selected: {_statusLetter},
          onSelectionChanged: (s) => setState(() => _statusLetter = s.first),
        ),
      ],
    );
  }

  /// "Etiket" — Durum kontrolünün yanında; Etiket Havuzu'na (Supabase
  /// `label_pool_items`, bkz. 0032_label_pool.sql) bu ürünün etiketini
  /// kuyruğa eklemek için `_LabelPoolDialog`'u açar. Barkod hanesi boşken
  /// devre dışı — Havuz kalemleri barkod olmadan anlamsız (Code128 gerekir).
  Widget _buildEtiketButton() {
    final barcode = _barcodeCtrl.text.trim();
    return OutlinedButton.icon(
      onPressed: barcode.isEmpty ? null : _openLabelPoolDialog,
      icon: const Icon(Icons.local_offer_outlined, size: 18),
      label: const Text('Etiket'),
    );
  }

  Future<void> _openLabelPoolDialog() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _LabelPoolDialog(
        barcode: barcode,
        productName: _nameCtrl.text.trim(),
        price: _num(_price1Ctrl),
      ),
    );
  }

  Widget _buildKarOrani2Field() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Kâr Oranı 2'),
      child: Text('%${_profitMargin2.toStringAsFixed(2)}'),
    );
  }

  Widget _buildUrunGrubuField(List groups) {
    return groups.isEmpty
        ? const SizedBox()
        : DropdownButtonFormField<String?>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: 'Ürün Grubu'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('GRUPSUZ ÜRÜN'),
              ),
              ...groups.map(
                (g) => DropdownMenuItem<String?>(
                  value: g.id,
                  child: Text(
                    g.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          );
  }

  /// Kamerayı açar; okunan barkodu alana yazar ve varsa mevcut ürünü getirir
  /// (yeni ürün ekliyorsanız barkod alanda kalır). Sadece mobil/native.
  Future<void> _scanBarcode() async {
    await openBarcodeScanner(context, (value) {
      _barcodeCtrl.text = value.trim();
      _fetchByBarcode();
    });
  }

  Future<void> _fetchByBarcode() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    // Orta ekrandaki "Ürünü Getir" / Enter / kamera akışının hepsi buradan
    // geçer — kilit sonuç ne olursa olsun (bulundu/bulunamadı/hata) hemen
    // kalkar, kullanıcı BİR KEZ "getir" dedikten sonra formu düzenleyebilir.
    if (mounted) setState(() => _awaitingFetch = false);

    Product? product;
    var fromCache = false;
    var networkFailed = false;
    if (_knownOffline) {
      networkFailed = true;
      product = await ref.read(productLocalCacheDaoProvider).fetchByBarcode(barcode);
      fromCache = product != null;
    } else {
      try {
        product = await withNetworkTimeout(ref.read(productRepositoryProvider).fetchByBarcode(barcode));
      } catch (_) {
        networkFailed = true;
        if (!kIsWeb) {
          product = await ref.read(productLocalCacheDaoProvider).fetchByBarcode(barcode);
          fromCache = product != null;
        }
      }
    }
    if (!mounted) return;

    if (product == null) {
      final String message;
      if (!networkFailed) {
        message = 'Bu barkoda ait ürün bulunamadı, yeni ürün oluşturabilirsiniz.';
        // Sunucu KESİN "yok" dedi (ağ sorunu değil) — önceki barkodun (varsa)
        // hâlâ ekranda duran bilgileri kafa karıştırmasın diye formu boşaltır
        // (barkod hanesi KORUNUR — kullanıcı o barkotla yeni ürün oluşturur).
        // networkFailed=true dallarında (bağlantı yok/timeout) BOŞALTMAYIZ —
        // ürün gerçekte var olabilir, yalnız şu an sorgulanamadı; kullanıcının
        // henüz kaydetmediği elle girdiği değerleri silmek yanlış olur.
        setState(() => _resetProductFields(clearBarcode: false));
      } else if (kIsWeb) {
        message = 'Bağlantı hatası — barkod sorgulanamadı, tekrar deneyin.';
      } else {
        // Cache'te de yoksa bu KESİN "sunucuda yok" anlamına gelmez — başka
        // bir cihazdan eklenmiş olabilir (v1'de kabul edilen sınır).
        message =
            'Bu barkod cihazda bulunamadı (çevrimdışı). Bağlantı gelince tekrar kontrol edin, veya yeni ürün olarak devam edin.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    var pendingSync = false;
    if (!kIsWeb) {
      final cacheDao = ref.read(productLocalCacheDaoProvider);
      if (fromCache) {
        pendingSync = await cacheDao.isPendingSync(product.id);
      } else {
        unawaited(cacheDao.markSynced(product));
      }
    }
    if (!mounted) return;

    setState(() {
      _applyProduct(product!);
      _pendingSync = pendingSync;
      _awaitingFetch = false;
    });

    if (fromCache && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Çevrimdışı kayıttan yüklendi — veriler son senkronizasyondan bu yana değişmiş olabilir.')),
      );
    }
  }

  /// "+ barkod üret" ikonu — bugünün YYMMDD önekiyle başlayan, henüz
  /// kullanılmamış ilk XXX'i bulup hanaye yazar (ör. 260814001, doluysa
  /// 260814002, ...). `_loadProduct`/`_fetchByBarcode` ile aynı "önce ağ
  /// (timeout'lu), olmazsa (`!kIsWeb`) yerel önbellek" desenini kullanır.
  Future<void> _generateBarcode() async {
    if (_generatingBarcode) return;
    setState(() => _generatingBarcode = true);
    try {
      final now = DateTime.now();
      final prefix = '${(now.year % 100).toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';

      Set<String> existing;
      if (_knownOffline) {
        existing = !kIsWeb
            ? await ref.read(productLocalCacheDaoProvider).fetchBarcodesWithPrefix(prefix)
            : const <String>{};
      } else {
        try {
          existing = await withNetworkTimeout(
              ref.read(productRepositoryProvider).fetchBarcodesWithPrefix(prefix));
        } catch (_) {
          existing = !kIsWeb
              ? await ref.read(productLocalCacheDaoProvider).fetchBarcodesWithPrefix(prefix)
              : const <String>{};
        }
      }
      if (!mounted) return;

      final candidate = nextBarcodeCandidate(prefix, existing);
      setState(() {
        _barcodeCtrl.text = candidate;
        _awaitingFetch = true;
      });
    } finally {
      if (mounted) setState(() => _generatingBarcode = false);
    }
  }

  /// Ürün Adı mikrofon butonu — dinlerken tekrar basılırsa durdurur.
  /// `result.recognizedWords` her callback'te O ANA KADAR tanınan TÜM
  /// tümceyi taşır (delta değil) — bu yüzden hane her seferinde DEĞİŞTİRİLİR
  /// (append edilmez), tek bir dikte oturumu = tek bir ürün adı.
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'notListening' || status == 'done') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ses tanıma kullanılamıyor (mikrofon izni gerekebilir).')));
      }
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'tr_TR'),
      onResult: (result) {
        _nameCtrl.text = result.recognizedWords;
        _nameCtrl.selection = TextSelection.collapsed(offset: _nameCtrl.text.length);
        if (result.finalResult && mounted) setState(() => _isListening = false);
      },
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() {
      _pickedImageBytes = file.bytes;
      _pickedImageExt = (file.extension ?? 'jpg').toLowerCase();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final product = Product(
      id: _currentId ?? '',
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      stockCode: _stockCodeCtrl.text.trim().isEmpty ? null : _stockCodeCtrl.text.trim(),
      groupId: _groupId,
      unit: _unitCtrl.text.trim().isEmpty ? 'Adet' : _unitCtrl.text.trim(),
      originCountry: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
      stockQuantity: _num(_stockCtrl),
      criticalStock: _num(_criticalStockCtrl),
      purchasePrice: _num(_purchasePriceCtrl),
      // Mobilde KDV Dahil onay kutuları kaldırıldı — mobil her zaman KDV
      // dahil kabul eder (davranış sabit); masaüstünde kullanıcı seçimi geçerli.
      purchasePriceVatIncluded: context.isMobile ? true : _purchaseVatIncluded,
      price1: _num(_price1Ctrl),
      price1VatIncluded: context.isMobile ? true : _price1VatIncluded,
      price2: _num(_price2Ctrl),
      price2VatIncluded: _price2VatIncluded,
      vatRate: _num(_vatRateCtrl),
      weight: _weightCtrl.text.trim().isEmpty ? null : _num(_weightCtrl),
      description: _composeDescription(),
      imageUrl: _imageUrl,
      quickListOrder: int.tryParse(_quickOrderCtrl.text.trim()),
      isOnlineActive: _isOnlineActive,
    );
    final isNew = _currentId == null || _currentId!.isEmpty;

    try {
      // Zaten "offline" olduğu biliniyorsa (son senkron probu başarısız
      // oldu), her kayıtta 6sn'lik ağ timeout'unu tekrar tekrar beklemek
      // yerine doğrudan kuyruğa düş — bekleme yalnız BİR KEZ (dead-zone'a
      // girildiğinde) ödenir, aynı oturumdaki sonraki kayıtlar anında olur.
      if (_knownOffline) {
        await _completeOfflineSave(product, isNew: isNew);
        return;
      }

      final repo = ref.read(productRepositoryProvider);
      String id;
      if (isNew) {
        id = await withNetworkTimeout(repo.create(product));
      } else {
        id = _currentId!;
        await withNetworkTimeout(repo.update(id, product));
      }

      if (_pickedImageBytes != null) {
        try {
          final url = await withNetworkTimeout(repo.uploadImage(id, _pickedImageBytes!, _pickedImageExt));
          await withNetworkTimeout(repo.update(id, product.copyWith(imageUrl: url)));
        } on PostgrestException {
          rethrow;
        } catch (_) {
          // Çekirdek kayıt sunucuya gitti; yalnız görsel adımı ağ hatasıyla
          // başarısız oldu — yalnız görsel için offline kuyruğa düş (core
          // kısım zaten senkron, `update` idempotent olduğundan yeniden
          // gönderilmesi zararsız).
          if (!kIsWeb) {
            await _queueOffline(product.copyWith(id: id), operation: PendingChangeOperation.update);
          }
          if (mounted) {
            ref.invalidate(productGroupsProvider);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Ürün kaydedildi, ancak resim yüklenemedi — bağlantı gelince otomatik yüklenecek.')));
            _afterSaveOrStay(isNew: isNew);
          }
          return;
        }
      }

      ref.invalidate(productGroupsProvider);
      if (!kIsWeb) {
        unawaited(ref.read(productLocalCacheDaoProvider).markSynced(product.copyWith(id: id)));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün kaydedildi')));
        _afterSaveOrStay(isNew: isNew);
      }
    } on PostgrestException catch (e) {
      // Sunucu YANIT VERDİ — gerçek red (ör. barkod çakışması ONLINE iken).
      // Bağlantı sorunu değil; formda kal, kuyruğa ALMA.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text(_friendlyPostgrestError(e))));
      }
    } catch (_) {
      // Sunucu hiç yanıt vermedi (timeout/soket) — dead-zone senaryosu.
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('Bağlantı hatası — ürün kaydedilemedi, tekrar deneyin.')));
        }
        return;
      }
      await _completeOfflineSave(product, isNew: isNew);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Kayıt başarıyla bittikten sonra (tam başarı/yalnız-görsel-hata/offline-
  /// kuyruk — üçü de bunu çağırır): ARTIK HİÇBİR DURUMDA `/products`'a
  /// GİTMEZ. YENİ ürün kaydıysa formu boşaltıp (barkod dahil) barkod
  /// hanesine odaklanır, kullanıcı ekrandan çıkmadan sıradaki ürünü
  /// kaydedebilsin diye. Mevcut bir ürün düzenlemesiyse form olduğu gibi
  /// (kaydedilen değerlerle) ekranda kalır — kullanıcı listeye dönmeden
  /// düzenlemeye devam edebilir, geri dönmek isterse geri okunu kullanır.
  void _afterSaveOrStay({required bool isNew}) {
    if (isNew) {
      setState(() => _resetProductFields(clearBarcode: true));
      _barcodeFocus.requestFocus();
    }
  }

  /// Ürünü senkron kuyruğuna yazar ve kullanıcıyı bilgilendirip ekrandan
  /// çıkar — hem "zaten offline olduğu biliniyordu" kısayolundan hem de
  /// "ağ denemesi timeout'la başarısız oldu" dalından çağrılır.
  Future<void> _completeOfflineSave(Product product, {required bool isNew}) async {
    final id = _currentId ?? const Uuid().v4();
    final operation = isNew ? PendingChangeOperation.create : PendingChangeOperation.update;
    await _queueOffline(product.copyWith(id: id), operation: operation);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bağlantı yok — ürün çevrimdışı kaydedildi, bağlantı gelince otomatik gönderilecek.')));
      _afterSaveOrStay(isNew: isNew);
    }
  }

  String _friendlyPostgrestError(PostgrestException e) {
    if (e.code == '23505') return 'Bu barkod başka bir üründe kayıtlı.';
    return 'Ürün kaydedilemedi: ${e.message}';
  }

  /// Ürünü senkron kuyruğuna yazar (offline oluşturma/düzenleme VEYA çekirdek
  /// kayıt gitmiş ama görseli kalmış durum — ikisi de aynı yoldan gider,
  /// `update` idempotent olduğundan tekrarı zararsızdır). Yalnız native.
  Future<void> _queueOffline(Product product, {required PendingChangeOperation operation}) async {
    String? imagePath;
    if (_pickedImageBytes != null) {
      final dir = await getApplicationSupportDirectory();
      imagePath = '${dir.path}/pending_${product.id}.$_pickedImageExt';
      await File(imagePath).writeAsBytes(_pickedImageBytes!);
    }

    final now = DateTime.now();
    final payload = jsonEncode({'id': product.id, ...product.toInsertMap()});
    await ref.read(pendingChangeDaoProvider).upsert(PendingChange(
          productId: product.id,
          operation: operation,
          payloadJson: payload,
          pendingImagePath: imagePath,
          createdAt: now,
          updatedAt: now,
        ));
    await ref.read(productLocalCacheDaoProvider).upsert(
          product,
          syncState: operation == PendingChangeOperation.create ? 'pending_create' : 'pending_update',
        );
    await ref.read(productSyncServiceProvider.notifier).notifyLocalQueueChanged();
  }

  /// Mevcut ürünü siler (yalnız düzenleme modunda, `_currentId` doluyken
  /// çağrılır — bkz. `build()`'teki `canDelete` koşulu).
  Future<void> _deleteProduct() async {
    final id = _currentId;
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text(
          '"${_nameCtrl.text.trim()}" ürününü silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(productRepositoryProvider).delete(id);
      ref.invalidate(productGroupsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ürün silindi')));
      context.go('/products');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('foreign key') ||
              e.toString().contains('violates')
          ? 'Ürün silinemedi: Bu ürüne ait satış kaydı bulunuyor.'
          : 'Ürün silinemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text(msg)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final groupsAsync = ref.watch(productGroupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/products'), icon: const Icon(Icons.arrow_back)),
            Text(
              _currentId == null ? 'Yeni Ürün' : 'Ürün Detayı',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocus,
                    decoration: const InputDecoration(hintText: 'Ürün barkodunu okutunuz...'),
                    onSubmitted: (_) => _fetchByBarcode(),
                    // Elle ilk karakter girilince kilit açılır (orta "Ürünü
                    // Getir" belirir); hane boşalınca kilit kalkar.
                    onChanged: (v) => setState(() => _awaitingFetch = v.trim().isNotEmpty),
                  ),
                ),
                // Kamera + "barkod üret" — sadece mobil/native. "Ürünü Getir"
                // masaüstünde satırda kalır; mobilde yerini orta-ekran
                // overlay'e bırakır (bkz. aşağıdaki kilit Stack'i).
                if (!kIsWeb && context.isMobile) ...[
                  const SizedBox(width: 8),
                  _buildSquareIconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 22),
                    color: AppColors.primary,
                    onPressed: _scanBarcode,
                  ),
                  const SizedBox(width: 8),
                  _buildSquareIconButton(
                    icon: const Badge(
                      label: Icon(Icons.add, size: 10, color: Colors.white),
                      backgroundColor: AppColors.success,
                      child: Icon(Icons.qr_code_2, size: 22),
                    ),
                    color: AppColors.success,
                    onPressed: _generatingBarcode ? null : _generateBarcode,
                    loading: _generatingBarcode,
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _fetchByBarcode, child: const Text('Ürünü Getir')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFormArea(groupsAsync),
      ],
    );
  }

  /// Barkod kartındaki kamera/üret ikonları için ortak 48×48 kare buton
  /// iskeleti (DRY — ikisi de aynı görünüm, yalnız ikon/renk/eylem değişir).
  Widget _buildSquareIconButton({
    required Widget icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      height: 48,
      width: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : icon,
      ),
    );
  }

  /// Sekmeler + Kaydet/Sil barı. Mobilde barkod hanesi doldurulup henüz
  /// "Ürünü Getir" ile onaylanmadıysa (`_awaitingFetch`) bu bölge dim +
  /// dokunmaz hale gelir, ortasında büyük "Ürünü Getir" belirir — kullanıcı
  /// önce barkodu netleştirsin diye (üst başlık/geri oku ve barkod kartı bu
  /// kilidin DIŞINDadır, her zaman erişilebilir kalır).
  Widget _buildFormArea(AsyncValue<List<dynamic>> groupsAsync) {
    final formArea = Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Ürün Bilgisi'),
                      Tab(text: 'Diğer Detaylar'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildProductInfoTab(groupsAsync.value ?? []),
                        _buildOtherDetailsTab(groupsAsync.value ?? []),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBottomBar(),
      ],
    );

    final locked = !kIsWeb && context.isMobile && _awaitingFetch;
    if (!locked) return Expanded(child: formArea);

    return Expanded(
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: Opacity(opacity: 0.25, child: formArea),
            ),
          ),
          Center(child: _CenterFetchButton(onTap: _fetchByBarcode)),
        ],
      ),
    );
  }

  /// Mobilde ve mevcut (yeni değil) bir ürün düzenlenirken sol altta kırmızı
  /// "Ürün Sil" butonu, sağda kaydet butonu; aksi halde yalnız kaydet (sağa
  /// hizalı, önceki davranışla aynı).
  Widget _buildBottomBar() {
    final saveButton = ElevatedButton.icon(
      onPressed: (_saving || _deleting) ? null : _save,
      icon: _saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.save_outlined),
      label: const Text('Ürünü kaydet'),
    );

    final canDelete = _currentId != null && _currentId!.isNotEmpty;
    if (!context.isMobile || !canDelete) {
      return Align(alignment: Alignment.centerRight, child: saveButton);
    }

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: (_saving || _deleting) ? null : _deleteProduct,
          icon: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.delete_outline),
          label: const Text('Ürün Sil'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
        ),
        const Spacer(),
        saveButton,
      ],
    );
  }

  Widget _buildProductInfoTab(List groups) {
    // Mobil "Ürün Bilgisi" masaüstünden tamamen farklı bir alan seti/sırası
    // kullanır (KARAR: bkz. design/plan notu — kompakt fiyat/kâr/stok ızgarası
    // + Firma/Tarih/Durum bu sekmeye taşındı, Ürün Grubu/Birim/Kritik Stok/
    // Menşe Ülke "Diğer Detaylar"a taşındı). Masaüstü aşağıdaki eski davranışla
    // BİREBİR aynı kalır.
    if (context.isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _buildMobileProductInfoFields(),
      );
    }

    // Resim bölümü: yalnız masaüstünde gösterilir
    Widget imageSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ürün resmi ekle (.jpg / .jpeg)'),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 160,
            maxHeight: 160,
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pickedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_pickedImageBytes!, fit: BoxFit.cover),
                    )
                  : (_imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(_imageUrl!, fit: BoxFit.cover),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        )),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Dosya Seç'),
        ),
      ],
    );

    // Form alanları bölümü: masaüstü (değişmedi)
    Widget formFields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Ürün Adı *'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ürün adı giriniz' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _price1Ctrl,
                decoration:
                    const InputDecoration(labelText: 'Fiyat 1 (Satış Fiyatı)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  // Elle satış girişi kâr oranını günceller, satışı ezmez.
                  _recalcMarginFromPrice1();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Text('KDV Dahil', style: TextStyle(fontSize: 11)),
                Checkbox(
                  value: _price1VatIncluded,
                  onChanged: (v) =>
                      setState(() => _price1VatIncluded = v ?? true),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _purchasePriceCtrl,
                decoration: const InputDecoration(labelText: 'Alış Fiyatı'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  // Alış değişince SATIŞ sabit kalır; kâr oranı yeniden hesaplanır.
                  // Kâr% = (satış / alış − 1) × 100. Alış ≤ 0 ise hesap atlanır.
                  _recalcMarginFromPrice1();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Text('KDV Dahil', style: TextStyle(fontSize: 11)),
                Checkbox(
                  value: _purchaseVatIncluded,
                  onChanged: (v) =>
                      setState(() => _purchaseVatIncluded = v ?? true),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vatRateCtrl,
                decoration: const InputDecoration(labelText: 'KDV %'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _profitMargin1Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Kâr Oranı (Fiyat 1)',
                  suffixText: '%',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  // Kâr oranı değişince Fiyat 1'i yeniden hesapla.
                  _recalcPrice1FromMargin();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: groups.isEmpty
                  ? const SizedBox()
                  : DropdownButtonFormField<String?>(
                      initialValue: _groupId,
                      decoration:
                          const InputDecoration(labelText: 'Ürün Grubu'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('GRUPSUZ ÜRÜN'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _unitCtrl,
                decoration:
                    const InputDecoration(labelText: 'Ürün Birimi'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _stockCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kalan Stok'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _criticalStockCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kritik Stok Miktarı'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _originCtrl,
          decoration: const InputDecoration(labelText: 'Menşe Ülke'),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      // Masaüstü: sol = form alanları (2/3), sağ = resim (1/3)
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: formFields),
          const SizedBox(width: 24),
          Expanded(child: imageSection),
        ],
      ),
    );
  }

  /// Alış/Satış alanları için renkli çerçeve+başlık üreten ortak yardımcı
  /// (KARAR: Alış=kırmızı, Satış=yeşil — semantik renk, tema altın kenarlığının
  /// bilinçli istisnası, yalnız bu iki mobil alanda).
  InputDecoration _colorCodedDecoration(String label, Color color) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      enabledBorder: border,
      border: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    );
  }

  /// Mobil "Ürün Bilgisi" sekmesi — kompakt sıra: Ürün Adı → Alış|Kar% →
  /// Satış|Stok → Firma|Tarih → Durum. KDV % "Diğer Detaylar"a taşındı.
  /// KDV Dahil onay kutuları burada YOK — mobil her zaman KDV dahil kabul
  /// eder (bkz. `_save()`).
  Widget _buildMobileProductInfoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Ürün Adı *',
            // Ses ile ürün adı girişi — yalnız mobil/native (kamera/barkod
            // üret ikonlarıyla aynı koşul).
            suffixIcon: (!kIsWeb && context.isMobile)
                ? IconButton(
                    tooltip: 'Ses ile gir',
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? AppColors.danger : null,
                    ),
                    onPressed: _toggleListening,
                  )
                : null,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ürün adı giriniz' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _purchasePriceCtrl,
                decoration: _colorCodedDecoration('Alış', AppColors.danger),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  _recalcMarginFromPrice1();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _profitMargin1Ctrl,
                decoration:
                    const InputDecoration(labelText: 'Kar %', suffixText: '%'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  _recalcPrice1FromMargin();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _price1Ctrl,
                decoration: _colorCodedDecoration('Satış', AppColors.success),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) {
                  _recalcMarginFromPrice1();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stockCtrl,
                decoration: const InputDecoration(labelText: 'Stok'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildFirmaField()),
            const SizedBox(width: 12),
            Expanded(child: _buildTarihField()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildDurumField()),
            const SizedBox(width: 12),
            _buildEtiketButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildOtherDetailsTab(List groups) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: context.isMobile
          ? _buildMobileOtherDetailsFields(groups)
          : _buildDesktopOtherDetailsFields(),
    );
  }

  /// Masaüstü "Diğer Detaylar" — değişmedi.
  Widget _buildDesktopOtherDetailsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eşlenik Barkod — `_currentId` değişince (kaydedilmiş üründen
        // yüklenince / barkodla getirilince) `key` widget'ı yeniden kurar,
        // güncel ürünün grubunu yeniden yükler (bkz. `_applyProduct`).
        EquivalentBarcodeSection(
            key: ValueKey(_currentId), productId: _currentId, pendingSync: _pendingSync),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _price2Ctrl,
                decoration: const InputDecoration(labelText: 'Fiyat 2 (Satış Fiyatı 2)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                const Text('KDV Dahil', style: TextStyle(fontSize: 11)),
                Checkbox(
                  value: _price2VatIncluded,
                  onChanged: (v) => setState(() => _price2VatIncluded = v ?? true),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildKarOrani2Field()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _stockCodeCtrl,
                decoration: const InputDecoration(labelText: 'Stok Kodu'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: 'Ürün Ağırlığı'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _quickOrderCtrl,
                decoration: const InputDecoration(labelText: 'Hızlı Ürün Sırası'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // FIRMA (otomatik tamamlama) — satış ekranındaki canlı arama diliyle aynı overlay.
        _buildFirmaField(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildTarihField()),
            const SizedBox(width: 12),
            Expanded(child: _buildDurumField()),
            const SizedBox(width: 12),
            _buildEtiketButton(),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isOnlineActive,
          title: const Text('Online Aç'),
          onChanged: (v) => setState(() => _isOnlineActive = v),
        ),
      ],
    );
  }

  /// Mobil "Diğer Detaylar" — Eşlenik Barkod üstte kalır; Firma/Tarih/Durum
  /// "Ürün Bilgisi"ne taşındığı için burada YOK; Fiyat 2 girişi kaldırıldı
  /// (Kâr Oranı 2 salt-okunur göstergesi kalır); Ürün Grubu/Birim/Kritik
  /// Stok/Menşe Ülke "Ürün Bilgisi"nden buraya taşındı.
  Widget _buildMobileOtherDetailsFields(List groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EquivalentBarcodeSection(
            key: ValueKey(_currentId), productId: _currentId, pendingSync: _pendingSync),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vatRateCtrl,
                decoration: const InputDecoration(labelText: 'KDV %'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildKarOrani2Field()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _stockCodeCtrl,
                decoration: const InputDecoration(labelText: 'Stok Kodu'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: 'Ürün Ağırlığı'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _quickOrderCtrl,
                decoration: const InputDecoration(labelText: 'Hızlı Ürün Sırası'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildUrunGrubuField(groups)),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _unitCtrl,
                decoration: const InputDecoration(labelText: 'Ürün Birimi'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _criticalStockCtrl,
                decoration: const InputDecoration(labelText: 'Kritik Stok Miktarı'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInputFormatters,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _originCtrl,
                decoration: const InputDecoration(labelText: 'Menşe Ülke'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isOnlineActive,
          title: const Text('Online Aç'),
          onChanged: (v) => setState(() => _isOnlineActive = v),
        ),
      ],
    );
  }
}

/// Barkod hanesi kilitliyken (`_awaitingFetch`) ekranın ortasında beliren
/// büyük "Ürünü Getir" düğmesi — mobil barkod-kilit overlay'inin tek aktif
/// eylemi (bkz. `_ProductFormScreenState._buildFormArea`).
class _CenterFetchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterFetchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_outlined, color: Colors.white, size: 36),
              SizedBox(height: 6),
              Text(
                'Ürünü\nGetir',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Etiket" butonuyla açılan diyalog — Raf/Tel/Geniş/Ürün alt alta, her
/// birinin yanında onay kutusu + (işaretliyken açılan, varsayılan '1') adet
/// hanesi. "Ekle" işaretli her tür için Etiket Havuzu'na (Supabase
/// `label_pool_items`, bkz. 0032_label_pool.sql) bu ürünün [quantity] kadar
/// kopyasını ekler — kullanıcılar/cihazlar arası PAYLAŞILAN kalıcı kuyruk
/// (bkz. `labels_provider.dart` `labelPoolRepositoryProvider`). Offline kuyruk
/// YOK (bilinçli basitleştirme) — bağlantı hatasında snackbar gösterir.
class _LabelPoolDialog extends ConsumerStatefulWidget {
  final String barcode;
  final String productName;
  final num price;

  const _LabelPoolDialog({
    required this.barcode,
    required this.productName,
    required this.price,
  });

  @override
  ConsumerState<_LabelPoolDialog> createState() => _LabelPoolDialogState();
}

class _LabelPoolDialogState extends ConsumerState<_LabelPoolDialog> {
  static const _labels = {
    kLabelPoolTypeRaf: 'Raf',
    kLabelPoolTypeTel: 'Tel',
    kLabelPoolTypeGenis: 'Geniş',
    kLabelPoolTypeUrun: 'Ürün',
  };

  final Map<String, bool> _checked = {
    for (final key in _labels.keys) key: false,
  };
  final Map<String, TextEditingController> _qtyCtrls = {
    for (final key in _labels.keys) key: TextEditingController(text: '1'),
  };

  bool _saving = false;

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    final selected = _labels.keys.where((k) => _checked[k] == true).toList();
    if (selected.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(labelPoolRepositoryProvider);
      for (final type in selected) {
        final qty = int.tryParse(_qtyCtrls[type]!.text.trim()) ?? 0;
        if (qty <= 0) continue;
        await repo.add(
          labelType: type,
          barcode: widget.barcode,
          productName: widget.productName,
          price: type == kLabelPoolTypeUrun ? null : widget.price,
          quantity: qty,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etiket Havuza eklendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Havuza eklenemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Etiket Havuzuna Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _labels.keys.map((key) {
          final isChecked = _checked[key] == true;
          return Row(
            children: [
              Checkbox(
                value: isChecked,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _checked[key] = v ?? false),
              ),
              Expanded(child: Text(_labels[key]!)),
              if (isChecked)
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _qtyCtrls[key],
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _confirm,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ekle'),
        ),
      ],
    );
  }
}

/// Firma otomatik tamamlama alanı.
/// KURAL: girilen önek (starts with, Türkçe-duyarlı) TAM 1 firmayla eşleşirse
/// overlay o tek öğeyi gösterir; 0 ya da ≥2 eşleşmede overlay HİÇ açılmaz.
/// Örn. firmalar = {PALA, PERDECİ}: "P"→2 eşleşme→kapalı, "PA"→1→PALA,
/// "PE"→1→PERDECİ. Seçim/Enter → alan tam firma adıyla dolar.
/// Overlay görünümü satış ekranındaki _LiveProductSearchField ile aynı
/// (cardBg yüzey, AppColors.divider hairline, AppSizes.radiusMd).
class _CompanyAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _CompanyAutocompleteField({
    required this.controller,
    required this.focusNode,
  });

  @override
  ConsumerState<_CompanyAutocompleteField> createState() =>
      _CompanyAutocompleteFieldState();
}

class _CompanyAutocompleteFieldState
    extends ConsumerState<_CompanyAutocompleteField> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  double _fieldWidth = 320;
  Company? _match; // önekle eşleşen TEK firma (varsa)

  // Türkçe küçük harf: önce I→ı, İ→i eşle, sonra toLowerCase().
  // (product_repository.dart'taki katlama mantığının aynısı.)
  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) _portal.hide();
  }

  void _onChanged(String value) {
    final prefix = value.trim();
    if (prefix.isEmpty) {
      _match = null;
      _portal.hide();
      return;
    }
    final companies = ref.read(companiesProvider).value ?? const <Company>[];
    final needle = _trLower(prefix);
    // "starts with" önek filtresi (Türkçe-duyarlı).
    final matches =
        companies.where((c) => _trLower(c.name).startsWith(needle)).toList();
    // Overlay yalnızca TAM 1 eşleşmede açılır.
    if (matches.length == 1) {
      setState(() => _match = matches.first);
      if (widget.focusNode.hasFocus) _portal.show();
    } else {
      _match = null;
      _portal.hide();
    }
  }

  void _select(Company company) {
    widget.controller.text = company.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: company.name.length,
    );
    _match = null;
    _portal.hide();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Firma listesini yükle/aboneliği canlı tut (onChanged ref.read ile okur).
    ref.watch(companiesProvider);
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final match = _match;
        if (match == null) return const SizedBox.shrink();
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: TextFieldTapRegion(
              child: SizedBox(
                width: _fieldWidth,
                child: _buildDropdown(match),
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) {
              _fieldWidth = constraints.maxWidth;
            }
            return TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              decoration: const InputDecoration(labelText: 'Firma'),
              onChanged: _onChanged,
              onSubmitted: (_) {
                final match = _match;
                if (match != null) _select(match);
                _portal.hide();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(Company match) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _select(match),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space8,
            ),
            child: Text(
              match.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
