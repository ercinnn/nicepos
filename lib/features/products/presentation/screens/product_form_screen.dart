import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../sales/presentation/widgets/barcode_scanner_modal.dart';
import '../../data/models/product.dart';
import '../../application/products_provider.dart';

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
  late TextEditingController _nameCtrl;
  late TextEditingController _price1Ctrl;
  late TextEditingController _price2Ctrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _criticalStockCtrl;
  late TextEditingController _vatRateCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _originCtrl;
  late TextEditingController _stockCodeCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _quickOrderCtrl;

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

  @override
  void initState() {
    super.initState();
    _currentId = widget.productId;
    _barcodeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _price1Ctrl = TextEditingController(text: '0');
    _price2Ctrl = TextEditingController(text: '0');
    _purchasePriceCtrl = TextEditingController(text: '0');
    _stockCtrl = TextEditingController(text: '0');
    _criticalStockCtrl = TextEditingController(text: '0');
    _vatRateCtrl = TextEditingController(text: '20');
    _unitCtrl = TextEditingController(text: 'Adet');
    _originCtrl = TextEditingController();
    _stockCodeCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _quickOrderCtrl = TextEditingController();

    if (widget.productId != null) {
      _loadProduct(widget.productId!);
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadProduct(String id) async {
    final product = await ref.read(productRepositoryProvider).fetchById(id);
    if (!mounted) return;
    if (product != null) _applyProduct(product);
    setState(() => _loaded = true);
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
    _unitCtrl.text = p.unit;
    _originCtrl.text = p.originCountry ?? '';
    _stockCodeCtrl.text = p.stockCode ?? '';
    _weightCtrl.text = p.weight == null ? '' : _fmt(p.weight!);
    _descriptionCtrl.text = p.description ?? '';
    _quickOrderCtrl.text = p.quickListOrder?.toString() ?? '';
    _price1VatIncluded = p.price1VatIncluded;
    _price2VatIncluded = p.price2VatIncluded;
    _purchaseVatIncluded = p.purchasePriceVatIncluded;
    _isOnlineActive = p.isOnlineActive;
    _groupId = p.groupId;
    _imageUrl = p.imageUrl;
  }

  String _fmt(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _price1Ctrl.dispose();
    _price2Ctrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _criticalStockCtrl.dispose();
    _vatRateCtrl.dispose();
    _unitCtrl.dispose();
    _originCtrl.dispose();
    _stockCodeCtrl.dispose();
    _weightCtrl.dispose();
    _descriptionCtrl.dispose();
    _quickOrderCtrl.dispose();
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
    final product = await ref.read(productRepositoryProvider).fetchByBarcode(barcode);
    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu barkoda ait ürün bulunamadı, yeni ürün oluşturabilirsiniz.')),
        );
      }
      return;
    }
    setState(() => _applyProduct(product));
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

    try {
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
        purchasePriceVatIncluded: _purchaseVatIncluded,
        price1: _num(_price1Ctrl),
        price1VatIncluded: _price1VatIncluded,
        price2: _num(_price2Ctrl),
        price2VatIncluded: _price2VatIncluded,
        vatRate: _num(_vatRateCtrl),
        weight: _weightCtrl.text.trim().isEmpty ? null : _num(_weightCtrl),
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        imageUrl: _imageUrl,
        quickListOrder: int.tryParse(_quickOrderCtrl.text.trim()),
        isOnlineActive: _isOnlineActive,
      );

      final repo = ref.read(productRepositoryProvider);
      String id;
      if (_currentId == null || _currentId!.isEmpty) {
        id = await repo.create(product);
      } else {
        id = _currentId!;
        await repo.update(id, product);
      }

      if (_pickedImageBytes != null) {
        final url = await repo.uploadImage(id, _pickedImageBytes!, _pickedImageExt);
        await repo.update(id, product.copyWith(imageUrl: url));
      }

      ref.invalidate(productGroupsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün kaydedildi')));
        context.go('/products');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                    decoration: const InputDecoration(hintText: 'Ürün barkodunu okutunuz...'),
                    onSubmitted: (_) => _fetchByBarcode(),
                  ),
                ),
                // Kamera ile barkod okut — sadece mobil/native
                if (!kIsWeb && context.isMobile) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _scanBarcode,
                      child: const Icon(Icons.camera_alt_outlined, size: 22),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _fetchByBarcode, child: const Text('Ürünü Getir')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                        _buildOtherDetailsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Ürünü kaydet'),
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfoTab(List groups) {
    final isMobile = context.isMobile;

    // Resim bölümü: hem mobil hem masaüstünde paylaşılan widget
    Widget imageSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ürün resmi ekle (.jpg / .jpeg)'),
        const SizedBox(height: 8),
        // Mobilde tam genişlik, masaüstünde sabit 160px
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 160,
            maxHeight: isMobile ? 200 : 160,
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

    // Form alanları bölümü: her iki layout için ortak
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
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
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
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
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
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Kâr Oranı (Fiyat 1)'),
                child: Text('%${_profitMargin1.toStringAsFixed(2)}'),
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
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _criticalStockCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kritik Stok Miktarı'),
                keyboardType: TextInputType.number,
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
      child: isMobile
          // Mobil: resim üstte, form alanları altta (yan yana koymak taşar)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageSection,
                const SizedBox(height: 16),
                formFields,
              ],
            )
          // Masaüstü: sol = form alanları (2/3), sağ = resim (1/3)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: formFields),
                const SizedBox(width: 24),
                Expanded(child: imageSection),
              ],
            ),
    );
  }

  Widget _buildOtherDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price2Ctrl,
                  decoration: const InputDecoration(labelText: 'Fiyat 2 (Satış Fiyatı 2)'),
                  keyboardType: TextInputType.number,
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
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Kâr Oranı 2'),
                  child: Text('%${_profitMargin2.toStringAsFixed(2)}'),
                ),
              ),
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
                  keyboardType: TextInputType.number,
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
          TextFormField(
            controller: _descriptionCtrl,
            decoration: const InputDecoration(labelText: 'Ürün Detayı'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isOnlineActive,
            title: const Text('Online Aç'),
            onChanged: (v) => setState(() => _isOnlineActive = v),
          ),
        ],
      ),
    );
  }
}
