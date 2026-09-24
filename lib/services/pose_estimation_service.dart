import 'dart:math';

import '../models/patient_assessment.dart';
import '../models/pose_estimation_result.dart';
import '../models/screening_result.dart';

/// Abstract contract for the YOLOv8-Pose vision branch.
///
/// When TFLite weights become available, implement this interface
/// with a real [tflite_flutter] interpreter and swap it in.
abstract class PoseEstimationService {
  /// 17 COCO keypoint labels in standard order.
  static const List<String> cocoKeypoints = [
    'nose',          // 0
    'left_eye',      // 1
    'right_eye',     // 2
    'left_ear',      // 3
    'right_ear',     // 4
    'left_shoulder', // 5
    'right_shoulder',// 6
    'left_elbow',    // 7
    'right_elbow',   // 8
    'left_wrist',    // 9
    'right_wrist',   // 10
    'left_hip',      // 11
    'right_hip',     // 12
    'left_knee',     // 13
    'right_knee',    // 14
    'left_ankle',    // 15
    'right_ankle',   // 16
  ];

  /// Analyses a recorded movement video and returns full-body pose kinematics.
  Future<PoseEstimationResult> estimatePose({
    required String videoPath,
    required PatientAssessment patientAssessment,
  });
}

/// Stub implementation of [PoseEstimationService] that mimics the output of
/// YOLOv8-Pose running on-device via TFLite.
///
/// Produces clinically plausible 17-keypoint skeletons derived deterministically
/// from patient context. All scalars (valgus angle, trunk shift, flexion) use the
/// same clinical formulas as [StubCameraVisionInferenceService] for consistency.
class StubYoloV8PoseService implements PoseEstimationService {
  const StubYoloV8PoseService();

  @override
  Future<PoseEstimationResult> estimatePose({
    required String videoPath,
    required PatientAssessment patientAssessment,
  }) async {
    // Simulate YOLOv8 inference latency on a mid-range mobile SoC.
    await Future.delayed(const Duration(milliseconds: 1400));

    final age = patientAssessment.age?.toDouble() ?? 55.0;
    final bmi = patientAssessment.bmi ?? 24.5;
    final isSymptomatic = patientAssessment.painScore > 0 ||
        patientAssessment.morningStiffness ||
        patientAssessment.activityRelatedPain ||
        patientAssessment.stiffnessScore > 0;

    // Deterministic seed from patient profile + video path.
    final seed =
        (age.toInt() * 43 + bmi.toInt() * 17 + videoPath.hashCode) & 0x7FFFFFFF;
    final rand = Random(seed);

    // -----------------------------------------------------------------------
    // Derive clinical scalars
    // -----------------------------------------------------------------------

    // Knee valgus angle: OA patients show increased valgus (positive)
    // or compensatory varus patterns.
    final double baseValgus = isSymptomatic
        ? 6.5 + (bmi > 27 ? (bmi - 27) * 0.4 : 0.0)
        : 2.0;
    final kneeValgusAngle =
        baseValgus + (rand.nextDouble() * 4.0 - 2.0);

    // Trunk lateral shift: antalgic unloading of painful knee.
    final double baseShift = isSymptomatic ? 0.12 : 0.04;
    final trunkLateralShift =
        (baseShift + (rand.nextDouble() * 0.06 - 0.03)).clamp(0.0, 0.5);

    // Hip-knee flexion during stance phase.
    final double baseFlexion =
        118.0 - (age > 50 ? (age - 50) * 0.35 : 0.0) - (isSymptomatic ? 9.0 : 0.0);
    final hipKneeFlexionAngle =
        (baseFlexion + (rand.nextDouble() * 8.0 - 4.0)).clamp(60.0, 140.0);

    // -----------------------------------------------------------------------
    // Build 17-keypoint skeleton
    // -----------------------------------------------------------------------
    final keypoints = _buildSkeleton(
      rand: rand,
      isSymptomatic: isSymptomatic,
      trunkShift: trunkLateralShift,
      kneeValgus: kneeValgusAngle,
    );

    final meanConfidence = keypoints.fold<double>(
          0.0,
          (sum, k) => sum + k.confidence,
        ) /
        keypoints.length;

    // -----------------------------------------------------------------------
    // Risk level from pose kinematics
    // -----------------------------------------------------------------------
    final ScreeningRiskLevel riskLevel;
    if (kneeValgusAngle > 8.0 || trunkLateralShift > 0.20) {
      riskLevel = ScreeningRiskLevel.higher;
    } else if (kneeValgusAngle > 5.0 || trunkLateralShift > 0.12) {
      riskLevel = ScreeningRiskLevel.moderate;
    } else {
      riskLevel = ScreeningRiskLevel.lower;
    }

    return PoseEstimationResult(
      keypoints: keypoints,
      kneeValgusAngle: double.parse(kneeValgusAngle.toStringAsFixed(2)),
      trunkLateralShift: double.parse(trunkLateralShift.toStringAsFixed(3)),
      hipKneeFlexionAngle: double.parse(hipKneeFlexionAngle.toStringAsFixed(1)),
      overallPoseConfidence: double.parse(meanConfidence.toStringAsFixed(3)),
      riskLevel: riskLevel,
      isStubResult: true,
      capturedAt: DateTime.now(),
    );
  }

  /// Constructs a plausible 17-keypoint skeleton in normalised image space.
  ///
  /// The skeleton is centred at (0.5, 0.5) and scaled to fill a typical
  /// standing-person bounding box. Knee/ankle positions are displaced to
  /// reflect [kneeValgus] and trunk lean reflects [trunkShift].
  List<Keypoint> _buildSkeleton({
    required Random rand,
    required bool isSymptomatic,
    required double trunkShift,
    required double kneeValgus,
  }) {
    // Vertical positions (top → bottom in normalised coords).
    const double nose       = 0.08;
    const double eyes       = 0.10;
    const double ears       = 0.12;
    const double shoulders  = 0.22;
    const double elbows     = 0.38;
    const double wrists     = 0.54;
    const double hips       = 0.52;
    const double knees      = 0.72;
    const double ankles     = 0.92;

    // Horizontal centre offset due to trunk lateral shift.
    final cx = 0.5 + trunkShift * 0.2;

    // Valgus nudges knees medially.
    final valgusOffset = (kneeValgus / 20.0) * 0.03;

    double conf(double base) =>
        (base - (isSymptomatic ? 0.04 : 0.0) + (rand.nextDouble() * 0.04 - 0.02))
            .clamp(0.60, 0.99);

    final List<Map<String, dynamic>> skeleton = [
      {'name': 'nose',           'x': cx,               'y': nose,      'c': 0.97},
      {'name': 'left_eye',       'x': cx - 0.025,       'y': eyes,      'c': 0.96},
      {'name': 'right_eye',      'x': cx + 0.025,       'y': eyes,      'c': 0.96},
      {'name': 'left_ear',       'x': cx - 0.04,        'y': ears,      'c': 0.94},
      {'name': 'right_ear',      'x': cx + 0.04,        'y': ears,      'c': 0.94},
      {'name': 'left_shoulder',  'x': cx - 0.10,        'y': shoulders, 'c': 0.95},
      {'name': 'right_shoulder', 'x': cx + 0.10,        'y': shoulders, 'c': 0.95},
      {'name': 'left_elbow',     'x': cx - 0.12,        'y': elbows,    'c': 0.91},
      {'name': 'right_elbow',    'x': cx + 0.12,        'y': elbows,    'c': 0.91},
      {'name': 'left_wrist',     'x': cx - 0.13,        'y': wrists,    'c': 0.87},
      {'name': 'right_wrist',    'x': cx + 0.13,        'y': wrists,    'c': 0.87},
      {'name': 'left_hip',       'x': cx - 0.07,        'y': hips,      'c': 0.93},
      {'name': 'right_hip',      'x': cx + 0.07,        'y': hips,      'c': 0.93},
      // Valgus: left knee drifts right, right knee drifts left.
      {'name': 'left_knee',      'x': cx - 0.07 + valgusOffset,  'y': knees,  'c': 0.92},
      {'name': 'right_knee',     'x': cx + 0.07 - valgusOffset,  'y': knees,  'c': 0.92},
      {'name': 'left_ankle',     'x': cx - 0.07,        'y': ankles,    'c': 0.90},
      {'name': 'right_ankle',    'x': cx + 0.07,        'y': ankles,    'c': 0.90},
    ];

    return skeleton.map((s) {
      return Keypoint(
        name: s['name'] as String,
        x: ((s['x'] as double) + (rand.nextDouble() * 0.006 - 0.003))
            .clamp(0.0, 1.0),
        y: ((s['y'] as double) + (rand.nextDouble() * 0.006 - 0.003))
            .clamp(0.0, 1.0),
        confidence: conf(s['c'] as double),
      );
    }).toList();
  }
}
