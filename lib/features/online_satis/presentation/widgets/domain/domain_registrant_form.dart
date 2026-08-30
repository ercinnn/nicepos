import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/models/domain_models.dart';

// Kayıt sahibi (registrant) bilgi formu — Cloudflare Registrar'a giden
// alanlar + iyzico'nun KYC şeması için identityNumber (T.C. kimlik/vergi no
// ya da yabancı kimlik/pasaport). v1 TLD kapsamı (.com/.net/.org) ek bir
// belge/doğrulama istemiyor.
class DomainRegistrantForm extends StatefulWidget {
  final String domain;
  final ValueChanged<DomainRegistrantContact> onSubmit;

  const DomainRegistrantForm({
    super.key,
    required this.domain,
    required this.onSubmit,
  });

  @override
  State<DomainRegistrantForm> createState() => _DomainRegistrantFormState();
}

class _DomainRegistrantFormState extends State<DomainRegistrantForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _identityNumber = TextEditingController();
  final _country = 'TR'; // v1: yalnız Türkiye'deki kiracılar hedefleniyor

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _address,
      _city,
      _identityNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Zorunlu alan' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      DomainRegistrantContact(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        country: _country,
        identityNumber: _identityNumber.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.domain,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Domain kayıt sahibi bilgileri',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  validator: _required,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-posta'),
            keyboardType: TextInputType.emailAddress,
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Telefon (+90...)'),
            keyboardType: TextInputType.phone,
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _identityNumber,
            decoration: const InputDecoration(
              labelText: 'T.C. Kimlik / Vergi No',
              helperText: 'Ödeme sağlayıcısının (iyzico) kimlik doğrulaması için',
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Adres'),
            maxLines: 2,
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Şehir'),
            validator: _required,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Devam Et'),
            ),
          ),
        ],
      ),
    );
  }
}
