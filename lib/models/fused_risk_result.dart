import 'screening_result.dart';

/// Output of the cross-modal attention fusion layer.
///
/// Produced by [FusionInferenceService] after combining the
/// YOLOv8-Pose vision branch score and the PatchTST sensor
/// branch embedding into a single risk estimate.
class FusedRiskResult {
  /// Combined risk score in [0.0, 1.0]. Higher = greater OA/fall risk.
  final double fusedRiskScore;

  /// Discrete risk classification derived from [fusedRiskScore].
  final ScreeningRiskLevel riskLevel;

  /// Confidence of the fusion result (0.0 – 1.0).
  /// Increases when both modalities agree; decreases on disagreement.
  final double fusionConfidence;

  /// Normalised contribution weight of the camera/pose branch (0.0 – 1.0).
  final double cameraContribution;

  /// Normalised contribution weight of the BLE/IMU sensor branch (0.0 – 1.0).
  final double sensorContribution;

  /// Degree of agreement between camera and sensor risk scores (0.0 – 1.0,
  /// 1.0 = perfect agreement).
  final double modalityAgreement;

  /// Raw camera branch risk score before fusion (0.0 – 1.0).
  final double cameraRiskScore;

  /// Raw sensor branch risk score before fusion (0.0 – 1.0).
  final double sensorRiskScore;

  /// Identifier for the fusion algorithm used.
  final String fusionMethod;

  /// Human-readable insights for pitch and clinical presentation.
  final List<String> insights;

  /// Whether either branch is a stub result (no real weights trained yet).
  final bool isStubResult;

  /// Timestamp of the fusion computation.
  final DateTime computedAt;

  const FusedRiskResult({
    required this.fusedRiskScore,
    required this.riskLevel,
    required this.fusionConfidence,
    required this.cameraContribution,
    required this.sensorContribution,
    required this.modalityAgreement,
    required this.cameraRiskScore,
    required this.sensorRiskScore,
    required this.fusionMethod,
    required this.insights,
    required this.isStubResult,
    required this.computedAt,
  });

  /// Percentage display of fused score (0 – 100).
  int get fusedRiskPercent => (fusedRiskScore * 100).round();

  /// Percentage display of fusion confidence (0 – 100).
  int get fusionConfidencePercent => (fusionConfidence * 100).round();

  /// Percentage display of modality agreement (0 – 100).
  int get modalityAgreementPercent => (modalityAgreement * 100).round();

  Map<String, dynamic> toJson() => {
        'fused_risk_score': fusedRiskScore,
        'risk_level': riskLevel.name,
        'fusion_confidence': fusionConfidence,
        'camera_contribution': cameraContribution,
        'sensor_contribution': sensorContribution,
        'modality_agreement': modalityAgreement,
        'camera_risk_score': cameraRiskScore,
        'sensor_risk_score': sensorRiskScore,
        'fusion_method': fusionMethod,
        'insights': insights,
        'is_stub_result': isStubResult,
        'computed_at': computedAt.toIso8601String(),
      };

  factory FusedRiskResult.fromJson(Map<String, dynamic> json) => FusedRiskResult(
        fusedRiskScore: (json['fused_risk_score'] as num).toDouble(),
        riskLevel: ScreeningRiskLevel.values.firstWhere(
          (e) => e.name == json['risk_level'],
          orElse: () => ScreeningRiskLevel.unavailable,
        ),
        fusionConfidence: (json['fusion_confidence'] as num).toDouble(),
        cameraContribution: (json['camera_contribution'] as num).toDouble(),
        sensorContribution: (json['sensor_contribution'] as num).toDouble(),
        modalityAgreement: (json['modality_agreement'] as num).toDouble(),
        cameraRiskScore: (json['camera_risk_score'] as num).toDouble(),
        sensorRiskScore: (json['sensor_risk_score'] as num).toDouble(),
        fusionMethod: json['fusion_method'] as String,
        insights: (json['insights'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        isStubResult: json['is_stub_result'] as bool? ?? true,
        computedAt:
            DateTime.tryParse(json['computed_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
