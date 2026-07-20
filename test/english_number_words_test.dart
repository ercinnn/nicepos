import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/core/utils/english_number_words.dart';

void main() {
  group('intToEnglishWords', () {
    test('1234 -> one thousand two hundred thirty-four', () {
      expect(intToEnglishWords(1234), 'one thousand two hundred thirty-four');
    });

    test('0 -> zero', () {
      expect(intToEnglishWords(0), 'zero');
    });
  });

  group('amountToEnglishWords', () {
    test('20 -> twenty turkish lira', () {
      expect(amountToEnglishWords(20), 'twenty turkish lira');
    });

    test('20.50 -> twenty turkish lira and fifty kuruş', () {
      expect(amountToEnglishWords(20.50), 'twenty turkish lira and fifty kuruş');
    });

    test('0 -> zero turkish lira', () {
      expect(amountToEnglishWords(0), 'zero turkish lira');
    });

    test('105 -> one hundred five turkish lira', () {
      final words = amountToEnglishWords(105);
      expect(words, 'one hundred five turkish lira');
      expect(words, contains('hundred'));
      expect(words, contains('five'));
    });
  });
}
