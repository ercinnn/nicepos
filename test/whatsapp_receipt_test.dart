import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nice_pos/core/utils/whatsapp.dart';
import 'package:nice_pos/features/sales/application/sale_whatsapp_text.dart';
import 'package:nice_pos/features/sales/data/models/cart_item.dart';
import 'package:nice_pos/features/sales/data/models/sale.dart';
import 'package:nice_pos/features/sales/data/models/sale_item.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('normalizeTrPhone', () {
    const expected = '905321234567';
    for (final input in [
      '0532 123 45 67',
      '05321234567',
      '+90 532 123 45 67',
      '0090 532 123 45 67',
      '5321234567',
      '905321234567',
      '(0532) 123-45-67',
    ]) {
      test('"$input" → $expected', () => expect(normalizeTrPhone(input), expected));
    }

    for (final input in [null, '', '123', '0212 123 45 67', '053212345678']) {
      test('"$input" → null', () => expect(normalizeTrPhone(input), isNull));
    }
  });

  test('whatsAppUri numaralı/numarasız ve Türkçe karakterleri encode eder', () {
    final withPhone = whatsAppUri(phone: '905321234567', text: 'Toplam: ₺10 — teşekkür');
    expect(withPhone.host, 'wa.me');
    expect(withPhone.path, '/905321234567');
    expect(withPhone.queryParameters['text'], 'Toplam: ₺10 — teşekkür');

    final noPhone = whatsAppUri(text: 'çğış');
    expect(noPhone.path, '/');
    expect(noPhone.queryParameters['text'], 'çğış');
  });

  group('buildSaleWhatsAppText', () {
    test('iskontosuz: ara toplam/iskonto satırı yok, toplam var', () {
      final text = buildSaleWhatsAppText(
        tenantName: 'Örnek Züccaciye',
        saleCode: 'S-0001',
        saleDate: DateTime(2026, 10, 12, 14, 30),
        customerName: 'Ayşe Yılmaz',
        lines: const [
          ReceiptLine(name: 'Çaydanlık', quantity: 2, unitPrice: 45, lineTotal: 90),
        ],
        subtotal: 90,
        discountAmount: 0,
        netTotal: 90,
      );
      expect(text, contains('*Örnek Züccaciye*'));
      expect(text, contains('Sayın Ayşe Yılmaz,'));
      expect(text, contains('S-0001'));
      expect(text, contains('12/10/2026'));
      expect(text, contains('• Çaydanlık'));
      expect(text, contains('2 × ₺45,00 = ₺90,00'));
      expect(text, isNot(contains('İskonto')));
      expect(text, contains('*Toplam: ₺90,00*'));
    });

    test('genel + satır iskontosu yazılır', () {
      final cart = [
        const CartItem(productName: 'Tava', quantity: 1, unitPrice: 100, discountValue: 10),
        const CartItem(productName: 'Bardak', quantity: 3, unitPrice: 20),
      ];
      final text = buildSaleWhatsAppText(
        saleCode: 'S-0002',
        saleDate: DateTime(2026, 10, 12),
        lines: cart.map(ReceiptLine.fromCartItem).toList(),
        subtotal: 150,
        discountAmount: 15,
        netTotal: 135,
      );
      expect(text, contains('1 × ₺100,00 = ₺90,00 (₺10,00 indirim)'));
      expect(text, contains('3 × ₺20,00 = ₺60,00'));
      expect(text, isNot(contains('₺60,00 (')));
      expect(text, contains('Ara Toplam: ₺150,00'));
      expect(text, contains('İskonto: -₺15,00'));
      expect(text, contains('*Toplam: ₺135,00*'));
      // İşletme/müşteri adı verilmezse başlık satırları yazılmaz.
      expect(text.startsWith('Satış No:'), isTrue);
    });
  });

  test('buildMultiSaleWhatsAppText her satışı ve genel toplamı yazar', () {
    final sales = [
      Sale(id: 'a', saleCode: 'S-1', totalAmount: 50, saleDate: DateTime(2026, 10, 1)),
      Sale(
          id: 'b',
          saleCode: 'S-2',
          totalAmount: 90,
          discountAmount: 10,
          saleDate: DateTime(2026, 10, 2)),
    ];
    final text = buildMultiSaleWhatsAppText(
      tenantName: 'Mağaza',
      customerName: 'Ali',
      sales: sales,
      itemsBySaleId: {
        'a': const [SaleItem(productName: 'Kaşık', quantity: 5, unitPrice: 10, total: 50)],
        'b': const [SaleItem(productName: 'Tencere', quantity: 1, unitPrice: 100, total: 100)],
      },
    );
    expect(text, contains('*S-1*'));
    expect(text, contains('*S-2*'));
    expect(text, contains('İskonto: -₺10,00'));
    expect(text, contains('Toplam: ₺90,00'));
    expect(text, contains('*Genel Toplam (2 satış): ₺140,00*'));
  });
}
