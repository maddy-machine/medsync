enum ScreeningRiskLevel {
  lower,
  moderate,
  higher,
  unavailable,
}

class ScreeningResult {
  final ScreeningRiskLevel riskLevel;
  final double? probability;
  final double? threshold;

  final bool modelAvailable;
  final String modelVersion;

  final List<String> contributingFactors;
  final String explanation;
  final String recommendation;

  const ScreeningResult({
    required this.riskLevel,
    required this.probability,
    required this.threshold,
    required this.modelAvailable,
    required this.modelVersion,
    required this.contributingFactors,
    required this.explanation,
    required this.recommendation,
  });

  bool get isAvailable =>
      modelAvailable &&
      probability != null;

  String get riskLabel {
    switch (riskLevel) {
      case ScreeningRiskLevel.lower:
        return 'Lower OA-associated risk';

      case ScreeningRiskLevel.moderate:
        return 'Moderate OA-associated risk';

      case ScreeningRiskLevel.higher:
        return 'Higher OA-associated risk';

      case ScreeningRiskLevel.unavailable:
        return 'Screening unavailable';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'risk_level': riskLevel.name,
      'probability': probability,
      'threshold': threshold,
      'model_available': modelAvailable,
      'model_version': modelVersion,
      'contributing_factors':
          contributingFactors,
      'explanation': explanation,
      'recommendation': recommendation,
    };
  }
}