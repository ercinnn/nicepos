import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/products/presentation/screens/product_form_screen.dart';

void main() {
  group('nextBarcodeCandidate', () {
    test('boş kümede 001 döner', () {
      expect(nextBarcodeCandidate('260814', {}), '260814001');
    });

    test('001 doluysa 002 döner', () {
      expect(nextBarcodeCandidate('260814', {'260814001'}), '260814002');
    });

    test('ardışık dolulukta sırayı takip eder', () {
      expect(
        nextBarcodeCandidate('260814', {'260814001', '260814002', '260814003'}),
        '260814004',
      );
    });

    test('ara boşluğu doldurur (001 boşsa 003 dolu olsa bile 001 döner)', () {
      expect(
        nextBarcodeCandidate('260814', {'260814003'}),
        '260814001',
      );
    });

    test('başka öneke ait barkodları etkilemez', () {
      expect(
        nextBarcodeCandidate('260814', {'260813001', '260815001'}),
        '260814001',
      );
    });
  });
}
