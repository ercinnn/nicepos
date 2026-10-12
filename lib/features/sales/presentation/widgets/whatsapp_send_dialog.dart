import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../customers/application/customers_provider.dart';

/// wa.me bağlantısı bu uzunluğu aşınca WhatsApp/tarayıcı metni kırpabilir —
/// gönderim engellenmez, yalnız uyarı gösterilir (toplu gönderimde olur).
const _kLongMessageChars = 4000;

typedef _SendResult = ({String? phone, String text, bool savePhone, String rawPhone});

/// Satış detayını WhatsApp'ta açmadan önce numara + mesaj önizlemesi
/// (düzenlenebilir) gösterir. Müşteri varsa numarası önceden doldurulur;
/// numarası boşsa/farklıysa "müşteri kaydına kaydet" seçeneği çıkar.
/// Numara boş bırakılırsa WhatsApp alıcıyı kendisi seçtirir.
///
/// `WidgetRef` yerine `context`'ten `ProviderScope` container'ı okunur: satış
/// ekranındaki snackbar aksiyonu, ödeme paneli (mobil sheet kapatılınca)
/// çoktan dispose olmuşken tetiklenebilir — çağıran o durumda kalıcı bir
/// context (root navigator) geçer.
Future<void> showWhatsAppSendDialog(
  BuildContext context, {
  String? customerId,
  required String text,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  String? savedPhone;
  if (customerId != null) {
    try {
      savedPhone = (await container.read(customerByIdProvider(customerId).future))?.phone;
    } catch (_) {
      // Müşteri okunamadı (ör. çevrimdışı) — numara elle girilir.
    }
  }
  if (!context.mounted) return;

  final result = await showDialog<_SendResult>(
    context: context,
    builder: (dialogContext) => _WhatsAppSendDialog(
      initialPhone: savedPhone ?? '',
      canSaveToCustomer: customerId != null,
      text: text,
    ),
  );
  if (result == null) return;

  // WhatsApp ÖNCE açılır, numara kaydı SONRA: web'de (özellikle telefon
  // tarayıcısında) `window.open` kullanıcı dokunuşuna yakın çağrılmazsa
  // açılır-pencere engeline takılır — araya ağ isteği (updatePhone) girmemeli.
  final opened = await openWhatsApp(whatsAppUri(phone: result.phone, text: result.text));
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppColors.danger, content: Text('WhatsApp açılamadı.')));
  }

  if (result.savePhone && customerId != null) {
    try {
      await container.read(customerRepositoryProvider).updatePhone(customerId, result.rawPhone);
      container.invalidate(customerByIdProvider(customerId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Numara müşteri kaydına yazılamadı.')));
      }
    }
  }
}

class _WhatsAppSendDialog extends StatefulWidget {
  final String initialPhone;
  final bool canSaveToCustomer;
  final String text;

  const _WhatsAppSendDialog({
    required this.initialPhone,
    required this.canSaveToCustomer,
    required this.text,
  });

  @override
  State<_WhatsAppSendDialog> createState() => _WhatsAppSendDialogState();
}

class _WhatsAppSendDialogState extends State<_WhatsAppSendDialog> {
  late final _phoneController = TextEditingController(text: widget.initialPhone);
  late final _textController = TextEditingController(text: widget.text);
  String? _phoneError;
  bool _savePhone = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Girilen numara kayıtlı numaradan farklıysa (ve geçerliyse) kaydetme
  /// seçeneği gösterilir.
  bool get _phoneChanged {
    final entered = normalizeTrPhone(_phoneController.text);
    return entered != null && entered != normalizeTrPhone(widget.initialPhone);
  }

  void _submit() {
    final raw = _phoneController.text.trim();
    final phone = raw.isEmpty ? null : normalizeTrPhone(raw);
    if (raw.isNotEmpty && phone == null) {
      setState(() => _phoneError = 'Geçerli bir cep numarası girin (ör. 0532 123 45 67)');
      return;
    }
    Navigator.of(context).pop<_SendResult>((
      phone: phone,
      text: _textController.text,
      savePhone: widget.canSaveToCustomer && _savePhone && _phoneChanged,
      rawPhone: raw,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tooLong = _textController.text.length > _kLongMessageChars;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.chat_outlined, color: AppColors.success),
          SizedBox(width: 8),
          Text("WhatsApp'la Gönder"),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  hintText: '0532 123 45 67',
                  helperText: 'Boş bırakırsanız kişiyi WhatsApp\'ta seçersiniz.',
                  errorText: _phoneError,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                onChanged: (_) => setState(() => _phoneError = null),
              ),
              if (widget.canSaveToCustomer && _phoneChanged)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _savePhone,
                  onChanged: (v) => setState(() => _savePhone = v ?? false),
                  title: const Text('Numarayı müşteri kaydına kaydet'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (tooLong) ...[
                const SizedBox(height: 8),
                const Text(
                  'Mesaj çok uzun — WhatsApp kırpabilir. Daha az satış seçmeyi deneyin.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send, size: 18),
          label: const Text("WhatsApp'ta Aç"),
          onPressed: _submit,
        ),
      ],
    );
  }
}
