import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/cart_provider.dart';
import '../../widgets/store_app_bar.dart';

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
      final orderCode = await ref.read(storeRepositoryProvider).createOrder(
            customerName: _nameController.text.trim(),
            customerPhone: _phoneController.text.trim(),
            customerEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            shippingAddress: _addressController.text.trim(),
            customerNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            items: items,
          );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      context.go('/siparis-alindi/$orderCode');
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sepetiniz boş', style: TextStyle(color: StoreColors.textMuted)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('Alışverişe Başla')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const StoreAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teslimat Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-posta (opsiyonel)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Teslimat Adresi'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Sipariş Notu (opsiyonel)'),
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
                        const Text('Toplam', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(formatCurrency(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: StoreColors.navy)),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: StoreColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Siparişi Onayla'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
