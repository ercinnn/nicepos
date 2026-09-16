import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/products/data/models/ai_group_suggestion.dart';

void main() {
  group('AiGroupSuggestion.fromMap', () {
    test('tüm alanları doğru okur', () {
      final s = AiGroupSuggestion.fromMap({
        'product_id': 'p1',
        'product_name': 'COCA COLA 1.5L',
        'suggested_group_id': 'g1',
        'suggested_group_name': 'Kolalar',
        'suggested_parent_group_name': 'İçecekler',
        'confidence': 0.82,
        'match_count': 3,
        'sample_matches': 'COCA COLA 1L (0.71), COCA COLA 2.5L (0.65)',
      });

      expect(s.productId, 'p1');
      expect(s.productName, 'COCA COLA 1.5L');
      expect(s.suggestedGroupId, 'g1');
      expect(s.suggestedGroupName, 'Kolalar');
      expect(s.suggestedParentGroupName, 'İçecekler');
      expect(s.confidence, 0.82);
      expect(s.matchCount, 3);
      expect(s.sampleMatches, contains('COCA COLA 1L'));
    });

    test('üst grup boşsa null kalır (kök seviye grup)', () {
      final s = AiGroupSuggestion.fromMap({
        'product_id': 'p2',
        'product_name': 'EKMEK',
        'suggested_group_id': 'g2',
        'suggested_group_name': 'Fırın',
        'suggested_parent_group_name': null,
        'confidence': 1.0,
        'match_count': 5,
        'sample_matches': 'EKMEK ÇAVDAR (1.0)',
      });

      expect(s.suggestedParentGroupName, isNull);
      expect(s.confidence, 1.0);
    });

    test('confidence/match_count/sample_matches eksikse güvenli varsayılana düşer', () {
      final s = AiGroupSuggestion.fromMap({
        'product_id': 'p3',
        'product_name': 'XYZ',
        'suggested_group_id': 'g3',
        'suggested_group_name': 'Diğer',
      });

      expect(s.confidence, 0.0);
      expect(s.matchCount, 0);
      expect(s.sampleMatches, '');
    });
  });
}
