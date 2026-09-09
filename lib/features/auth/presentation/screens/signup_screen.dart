import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

/// Kendi-kendine kayıt: iki mod — yeni işletme kaydı (yeni bir `tenants`
/// satırı açar, kullanıcı 'owner' olur) veya davet koduyla katılma (mevcut
/// bir kiracıya belirtilen rolle üye olur). Her iki mod da tek bir
/// `ensure_tenant_bootstrap` RPC'sinden geçer (bkz. 0041 migration).
///
/// Şirket adı / davet kodu `auth.signUp()`'ın `data:` (user_metadata)
/// parametresiyle saklanır — Supabase projesinde "Confirm email" açıksa
/// `signUp()` hemen bir oturum DÖNMEZ; bu durumda kurulum kullanıcının
/// e-postayı onaylayıp ilk kez giriş yaptığı anda `ensureTenantProvisionedProvider`
/// tarafından (router redirect'i üzerinden) tamamlanır — bkz. auth_provider.dart.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum _SignupMode { newTenant, invite }

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  _SignupMode _mode = _SignupMode.newTenant;
  bool _loading = false;
  String? _error;
  String? _infoMessage;

  @override
  void dispose() {
    _tenantNameController.dispose();
    _inviteCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _infoMessage = null;
    });

    try {
      final metadata = _mode == _SignupMode.newTenant
          ? {'pending_tenant_name': _tenantNameController.text.trim()}
          : {'pending_invite_code': _inviteCodeController.text.trim().toUpperCase()};

      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: metadata,
      );

      if (response.session != null) {
        // Oturum hemen geldi (e-posta onayı kapalı) — kurulumu şimdi tamamla.
        final params = _mode == _SignupMode.newTenant
            ? {'p_tenant_name': _tenantNameController.text.trim()}
            : {'p_invite_code': _inviteCodeController.text.trim().toUpperCase()};
        await Supabase.instance.client.rpc('ensure_tenant_bootstrap', params: params);
        // Router redirect otomatik olarak /home'a yönlendirir (loggedIn=true).
        return;
      }

      // E-posta onayı bekleniyor — kurulum ilk girişte otomatik tamamlanır.
      setState(() {
        _infoMessage =
            'E-postanıza bir onay bağlantısı gönderdik. Onayladıktan sonra giriş yapabilirsiniz.';
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on PostgrestException catch (e) {
      // ensure_tenant_bootstrap hatası (ör. geçersiz davet kodu) — hesap zaten
      // oluşmuş olabilir ama kiracıya bağlanamadı; kullanıcıyı bilgilendirip
      // güvenli tarafta bırakmak için çıkış yaptırılır.
      await Supabase.instance.client.auth.signOut();
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Kayıt tamamlanamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.point_of_sale, size: 48, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Hesap Oluştur',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<_SignupMode>(
                      segments: const [
                        ButtonSegment(
                          value: _SignupMode.newTenant,
                          label: Text('Yeni İşletme'),
                          icon: Icon(Icons.store_outlined),
                        ),
                        ButtonSegment(
                          value: _SignupMode.invite,
                          label: Text('Davet Kodum Var'),
                          icon: Icon(Icons.mail_outline),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 20),
                    if (_mode == _SignupMode.newTenant)
                      TextFormField(
                        controller: _tenantNameController,
                        decoration: const InputDecoration(labelText: 'İşletme / Mağaza Adı'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'İşletme adı giriniz'
                            : null,
                      )
                    else
                      TextFormField(
                        controller: _inviteCodeController,
                        decoration: const InputDecoration(labelText: 'Davet Kodu'),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Davet kodu giriniz' : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.isEmpty) ? 'E-posta giriniz' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Şifre en az 6 karakter olmalı'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmController,
                      decoration: const InputDecoration(labelText: 'Şifre (Tekrar)'),
                      obscureText: true,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v != _passwordController.text)
                          ? 'Şifreler eşleşmiyor'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    if (_infoMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_infoMessage!, style: const TextStyle(color: AppColors.success)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kayıt Ol'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Zaten hesabınız var mı? Giriş Yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
