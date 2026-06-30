import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/customers_provider.dart';
import '../../data/models/customer.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _paymentTermCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _creditLimitCtrl;
  late TextEditingController _taxOfficeCtrl;
  late TextEditingController _taxNumberCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _paymentTermCtrl = TextEditingController(text: c?.paymentTermDays?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _noteCtrl = TextEditingController(text: c?.note ?? '');
    _creditLimitCtrl = TextEditingController(text: c == null ? '0' : c.creditLimit.toString());
    _taxOfficeCtrl = TextEditingController(text: c?.taxOffice ?? '');
    _taxNumberCtrl = TextEditingController(text: c?.taxNumber ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _paymentTermCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _creditLimitCtrl.dispose();
    _taxOfficeCtrl.dispose();
    _taxNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final customer = Customer(
      id: widget.customer?.id ?? '',
      name: _nameCtrl.text.trim(),
      paymentTermDays: int.tryParse(_paymentTermCtrl.text.trim()),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      creditLimit: num.tryParse(_creditLimitCtrl.text.replaceAll(',', '.')) ?? 0,
      taxOffice: _taxOfficeCtrl.text.trim().isEmpty ? null : _taxOfficeCtrl.text.trim(),
      taxNumber: _taxNumberCtrl.text.trim().isEmpty ? null : _taxNumberCtrl.text.trim(),
    );

    final repo = ref.read(customerRepositoryProvider);
    if (widget.customer == null) {
      await repo.create(customer);
    } else {
      await repo.update(widget.customer!.id, customer);
    }

    if (mounted) Navigator.pop(context, true);
  }

  /// Form içi grup başlığı — type.utility, sakin textMuted (alanları gruplar).
  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'Yeni Müşteri Oluştur' : 'Müşteriyi Düzenle'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Kimlik & İletişim ──────────────────────────────────────
                _sectionLabel('Kimlik & İletişim'),
                const SizedBox(height: AppSizes.space8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Müşteri Tanımı *',
                    hintText: 'Ad soyad veya firma adı',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Müşteri adı giriniz' : null,
                ),
                const SizedBox(height: AppSizes.space12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSizes.space12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Adres'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.space20),
                // ── Hesap & Vade ───────────────────────────────────────────
                _sectionLabel('Hesap & Vade'),
                const SizedBox(height: AppSizes.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _creditLimitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Açık Hesap Limiti',
                          prefixText: '₺ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: TextFormField(
                        controller: _paymentTermCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vade Süresi',
                          suffixText: 'gün',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space20),
                // ── Vergi & Diğer ──────────────────────────────────────────
                _sectionLabel('Vergi & Diğer'),
                const SizedBox(height: AppSizes.space8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taxOfficeCtrl,
                        decoration: const InputDecoration(labelText: 'Vergi Dairesi'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxNumberCtrl,
                        decoration: const InputDecoration(labelText: 'Vergi No'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space12),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Müşteri Notu'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Kaydet')),
      ],
    );
  }
}
