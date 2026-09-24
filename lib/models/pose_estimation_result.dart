import 'screening_result.dart';

/// A single COCO body keypoint detected by YOLOv8-Pose.
class Keypoint {
  /// COCO keypoint name (e.g. 'left_knee', 'right_hip').
  final String name;

  /// Normalised x coordinate (0.0 = left edge, 1.0 = right edge).
  final double x;

  /// Normalised y coordinate (0.0 = top edge, 1.0 = bottom edge).
  final double y;

  /// Model confidence score for this keypoint (0.0 – 1.0).
  final double confidence;

  const Keypoint({
    required this.name,
    required this.x,
    required this.y,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'x': x,
        'y': y,
        'confidence': confidence,
      };

  factory Keypoint.fromJson(Map<String, dynamic> json) => Keypoint(
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
      );
}

/// Full-body pose result from the YOLOv8-Pose vision branch.
///
/// The 17 COCO keypoints are ordered as:
///   0  nose            1  left_eye        2  right_eye
///   3  left_ear        4  right_ear       5  left_shoulder
///   6  right_shoulder  7  left_elbow      8  right_elbow
///   9  left_wrist     10  right_wrist    11  left_hip
///  12  right_hip      13  left_knee      14  right_knee
///  15  left_ankle     16  right_ankle
class PoseEstimationResult {
  /// Ordered list of 17 COCO keypoints.
  final List<Keypoint> keypoints;

  /// Knee valgus/varus angle derived from hip–knee–ankle geometry (degrees).
  /// Positive = valgus (knock-knee); negative = varus (bow-leg).
  final double kneeValgusAngle;

  /// Lateral trunk shift: horizontal distance between shoulder midpoint
  /// and hip midpoint, normalised to torso height (0.0 = none, 1.0 = full).
  final double trunkLateralShift;

  /// Hip–knee flexion angle during the captured frame (degrees).
  final double hipKneeFlexionAngle;

  /// Mean confidence across all 17 keypoints.
  final double overallPoseConfidence;

  /// Estimated risk classification based purely on pose kinematics.
  final ScreeningRiskLevel riskLevel;

  /// Whether this result was produced by the stub (pre-trained-weights).
  final bool isStubResult;

  /// Timestamp of analysis.
  final DateTime capturedAt;

  const PoseEstimationResult({
    required this.keypoints,
    required this.kneeValgusAngle,
    required this.trunkLateralShift,
    required this.hipKneeFlexionAngle,
    required this.overallPoseConfidence,
    required this.riskLevel,
    this.isStubResult = true,
    required this.capturedAt,
  });

  /// Retrieves a keypoint by its COCO name.
  Keypoint? keypoint(String name) {
    try {
      return keypoints.firstWhere((k) => k.name == name);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'keypoints': keypoints.map((k) => k.toJson()).toList(),
        'knee_valgus_angle': kneeValgusAngle,
        'trunk_lateral_shift': trunkLateralShift,
        'hip_knee_flexion_angle': hipKneeFlexionAngle,
        'overall_pose_confidence': overallPoseConfidence,
        'risk_level': riskLevel.name,
        'is_stub_result': isStubResult,
        'captured_at': capturedAt.toIso8601String(),
      };

  factory PoseEstimationResult.fromJson(Map<String, dynamic> json) =>
      PoseEstimationResult(
        keypoints: (json['keypoints'] as List<dynamic>)
            .map((e) => Keypoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        kneeValgusAngle: (json['knee_valgus_angle'] as num).toDouble(),
        trunkLateralShift: (json['trunk_lateral_shift'] as num).toDouble(),
        hipKneeFlexionAngle: (json['hip_knee_flexion_angle'] as num).toDouble(),
        overallPoseConfidence:
            (json['overall_pose_confidence'] as num).toDouble(),
        riskLevel: ScreeningRiskLevel.values.firstWhere(
          (e) => e.name == json['risk_level'],
          orElse: () => ScreeningRiskLevel.unavailable,
        ),
        isStubResult: json['is_stub_result'] as bool? ?? true,
        capturedAt:
            DateTime.tryParse(json['captured_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
