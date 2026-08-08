import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/cart_item.dart';
import '../../state/cart_provider.dart';
import '../../widgets/checkout_stepper.dart';
import '../../widgets/store_app_bar.dart';
import '../../widgets/store_empty_state.dart';

/// Sipariş tamamlandıktan hemen sonra, sepet temizlenmeden ÖNCE alınan bir
/// anlık görüntü — sipariş-onay ekranına `go_router` `extra:` ile taşınır.
/// Kalıcı bir veri modeli değil, yalnız bu iki ekran arası geçici taşıma
/// (bkz. `data/models/`'e YENİ MODEL EKLENMEDİ kısıtı).
class OrderSummary {
  final List<CartItem> items;
  final num total;

  const OrderSummary({required this.items, required this.total});
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final orderCode = await ref
          .read(storeRepositoryProvider)
          .createOrder(
            customerName: _nameController.text.trim(),
            customerPhone: _phoneController.text.trim(),
            customerEmail: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            shippingAddress: _addressController.text.trim(),
            customerNote: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            items: items,
          );
      // Sepet temizlenmeden ÖNCE anlık görüntü al — sipariş-onay ekranı
      // sepet sıfırlandıktan sonra da kalemleri gösterebilsin diye.
      final capturedItems = List<CartItem>.from(items);
      final capturedTotal = items.fold<num>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      context.go(
        '/siparis-alindi/$orderCode',
        extra: OrderSummary(items: capturedItems, total: capturedTotal),
      );
    } catch (e) {
      setState(() => _error = 'Sipariş oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final total = items.fold<num>(0, (sum, item) => sum + item.subtotal);

    if (items.isEmpty) {
      return Scaffold(
        appBar: const StoreAppBar(),
        body: StoreEmptyState(
          icon: Icons.shopping_cart_outlined,
          message: 'Sepetiniz boş',
          ctaLabel: 'Alışverişe Başla',
          onCta: () => context.go('/'),
        ),
      );
    }

    return Scaffold(
      appBar: const StoreAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20), // space.xl
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // §9 — Sepet tamamlandı, Teslimat Bilgileri aktif, Sipariş
                // Onayı gelecek adım. "Ödeme" bir adım etiketi DEĞİLDİR.
                const CheckoutStepper(activeIndex: 1),
                const SizedBox(height: 24), // space.xxl
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teslimat Bilgileri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                        ),
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta (opsiyonel)',
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Teslimat Adresi',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Sipariş Notu (opsiyonel)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StoreColors.border),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Toplam',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              formatCurrency(total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: StoreColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12), // space.md
                          decoration: BoxDecoration(
                            color: StoreColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 18,
                                color: StoreColors.danger,
                              ),
                              const SizedBox(width: 8), // space.sm
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: StoreColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16), // space.lg
                      // Nötr bilgilendirme — çevrimiçi ödeme adımı YOK
                      // (iyzico entegrasyonu henüz yapılmadı), izlenim
                      // vermemek için "kapıda/elden ödeme" açıkça belirtilir.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, // space.md
                          vertical: 8, // space.sm
                        ),
                        decoration: BoxDecoration(
                          color: StoreColors.pageBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StoreColors.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: StoreColors.textMuted,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bu siparişte online ödeme alınmaz — ödeme '
                                'kapıda/elden yapılır.',
                                style: TextStyle(
                                  color: StoreColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Siparişi Onayla'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Zorunlu';
    if (!RegExp(r'^[0-9+\s]+$').hasMatch(value)) {
      return 'Yalnızca rakam, boşluk ve + kullanılabilir';
    }
    final digitCount = value.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount < 10) {
      return 'Geçerli bir telefon numarası girin';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null; // opsiyonel
    if (!value.contains('@') || !value.contains('.')) {
      return 'Geçerli bir e-posta adresi girin';
    }
    return null;
  }
}
