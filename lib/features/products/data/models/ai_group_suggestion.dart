class AiGroupSuggestion {
  final String productId;
  final String productName;
  final String suggestedGroupId;
  final String suggestedGroupName;
  final String? suggestedParentGroupName;
  final double confidence;
  final int matchCount;
  final String sampleMatches;

  const AiGroupSuggestion({
    required this.productId,
    required this.productName,
    required this.suggestedGroupId,
    required this.suggestedGroupName,
    this.suggestedParentGroupName,
    required this.confidence,
    required this.matchCount,
    required this.sampleMatches,
  });

  factory AiGroupSuggestion.fromMap(Map<String, dynamic> map) {
    return AiGroupSuggestion(
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      suggestedGroupId: map['suggested_group_id'] as String,
      suggestedGroupName: map['suggested_group_name'] as String,
      suggestedParentGroupName: map['suggested_parent_group_name'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      matchCount: (map['match_count'] as num?)?.toInt() ?? 0,
      sampleMatches: map['sample_matches'] as String? ?? '',
    );
  }
}
