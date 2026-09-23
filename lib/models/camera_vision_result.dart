import 'screening_result.dart';

/// Represents the analyzed kinematics and gait features extracted from
/// the camera vision screening test.
class CameraVisionResult {
  /// Overall posture quality score (0 - 100).
  final double postureScore;

  /// Gait symmetry index (0.0 - 1.0, 1.0 = perfect bilateral symmetry).
  final double gaitSymmetryIndex;

  /// Peak knee flexion angle detected during movement in degrees.
  final double kneeFlexionAngleDeg;

  /// Estimated cadence in steps per minute.
  final double stepCadence;

  /// Antalgic gait score indicating compensatory limp severity (0 - 100).
  final double antalgicGaitScore;

  /// Estimated risk level classification based on vision kinematics.
  final ScreeningRiskLevel riskLevel;

  /// Whether this result was produced by the stubbed model (until real model training finishes).
  final bool isStubResult;

  /// Timestamp when the recording / analysis was performed.
  final DateTime capturedAt;

  /// File path of the recorded video (if persisted).
  final String? videoPath;

  /// Quality of pose tracking confidence (0.0 - 1.0).
  final double trackingConfidence;

  /// Explanatory kinematic findings.
  final List<String> kinematicFindings;

  const CameraVisionResult({
    required this.postureScore,
    required this.gaitSymmetryIndex,
    required this.kneeFlexionAngleDeg,
    required this.stepCadence,
    required this.antalgicGaitScore,
    required this.riskLevel,
    this.isStubResult = true,
    required this.capturedAt,
    this.videoPath,
    this.trackingConfidence = 0.94,
    this.kinematicFindings = const [],
  });

  String get riskLabel {
    switch (riskLevel) {
      case ScreeningRiskLevel.lower:
        return 'Lower Risk Pattern';
      case ScreeningRiskLevel.moderate:
        return 'Moderate Risk Pattern';
      case ScreeningRiskLevel.higher:
        return 'Higher Risk Pattern';
      case ScreeningRiskLevel.unavailable:
        return 'Analysis Inconclusive';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'posture_score': postureScore,
      'gait_symmetry_index': gaitSymmetryIndex,
      'knee_flexion_angle_deg': kneeFlexionAngleDeg,
      'step_cadence': stepCadence,
      'antalgic_gait_score': antalgicGaitScore,
      'risk_level': riskLevel.name,
      'is_stub_result': isStubResult,
      'captured_at': capturedAt.toIso8601String(),
      'video_path': videoPath,
      'tracking_confidence': trackingConfidence,
      'kinematic_findings': kinematicFindings,
    };
  }

  factory CameraVisionResult.fromJson(Map<String, dynamic> json) {
    return CameraVisionResult(
      postureScore: (json['posture_score'] as num).toDouble(),
      gaitSymmetryIndex: (json['gait_symmetry_index'] as num).toDouble(),
      kneeFlexionAngleDeg: (json['knee_flexion_angle_deg'] as num).toDouble(),
      stepCadence: (json['step_cadence'] as num).toDouble(),
      antalgicGaitScore: (json['antalgic_gait_score'] as num).toDouble(),
      riskLevel: ScreeningRiskLevel.values.firstWhere(
        (e) => e.name == json['risk_level'],
        orElse: () => ScreeningRiskLevel.unavailable,
      ),
      isStubResult: json['is_stub_result'] as bool? ?? true,
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          DateTime.now(),
      videoPath: json['video_path'] as String?,
      trackingConfidence:
          (json['tracking_confidence'] as num?)?.toDouble() ?? 0.94,
      kinematicFindings: (json['kinematic_findings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
