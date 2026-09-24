import 'dart:math';

import '../models/fused_risk_result.dart';
import '../models/imu_embedding.dart';
import '../models/patient_assessment.dart';
import '../models/pose_estimation_result.dart';
import '../models/screening_result.dart';

/// Cross-modal attention fusion layer.
///
/// Combines the YOLOv8-Pose vision branch output and the PatchTST sensor
/// branch output into a single [FusedRiskResult] using a weighted cross-
/// attention mechanism.
///
/// ## Fusion Algorithm (Phase 1 — Cross-Attention Weighted Average)
///
/// 1. Normalise camera risk score  → c ∈ [0, 1]
/// 2. Normalise sensor risk score  → s ∈ [0, 1]
/// 3. Agreement weight: w = 1 − |c − s|  (1.0 when both agree, 0.0 when opposite)
/// 4. Fused score:
///    - Agreement region:    w × (camera_weight × c + sensor_weight × s)
///    - Disagreement region: (1 − w) × max(c, s)   ← conservative upper bound
/// 5. Final: F = agreement × fused_agree + disagreement × fused_disagree
///
/// When real cross-attention weights are trained (Phase 2), replace
/// [_computeFusedScore] with a learned projection.
class FusionInferenceService {
  /// Base weight assigned to the camera (pose) branch. [0, 1].
  final double cameraWeight;

  /// Base weight assigned to the sensor (IMU) branch. [0, 1].
  final double sensorWeight;

  /// Risk score threshold above which risk is classified as [ScreeningRiskLevel.higher].
  final double higherRiskThreshold;

  /// Risk score threshold above which risk is classified as [ScreeningRiskLevel.moderate].
  final double moderateRiskThreshold;

  /// Algorithm identifier surfaced in [FusedRiskResult.fusionMethod].
  static const String fusionMethodId = 'cross_attention_weighted_v1';

  FusionInferenceService({
    this.cameraWeight = 0.45,
    this.sensorWeight = 0.55,
    this.higherRiskThreshold = 0.60,
    this.moderateRiskThreshold = 0.35,
  }) : assert(
          (cameraWeight + sensorWeight - 1.0).abs() < 1e-9,
          'Camera and sensor weights must sum to 1.0',
        );

  /// Fuses a pose estimation result and an IMU embedding into a [FusedRiskResult].
  ///
  /// [poseResult] comes from [PoseEstimationService.estimatePose].
  /// [imuEmbedding] comes from [PatchTSTSensorEncoder.encode].
  /// [patientAssessment] is used to compute a clinical prior that modulates
  /// the base weights (age + BMI + symptom burden shift the sensor weight up).
  FusedRiskResult fuse({
    required PoseEstimationResult poseResult,
    required ImuEmbedding imuEmbedding,
    required PatientAssessment patientAssessment,
  }) {
    // -----------------------------------------------------------------------
    // 1. Risk scores from each modality [0, 1]
    // -----------------------------------------------------------------------
    final double cameraScore = _poseToRiskScore(poseResult);
    final double sensorScore = imuEmbedding.sensorRiskScore;

    // -----------------------------------------------------------------------
    // 2. Clinical prior — adjusts modality weights based on patient context.
    //    High BMI / age / symptom burden → trust sensor more (captures
    //    micro-tremor and asymmetry that may not be visible on camera).
    // -----------------------------------------------------------------------
    final adjustedWeights = _adjustWeights(patientAssessment);
    final double cW = adjustedWeights.$1;
    final double sW = adjustedWeights.$2;

    // -----------------------------------------------------------------------
    // 3. Cross-attention weighted fusion
    // -----------------------------------------------------------------------
    final double fusedScore = _computeFusedScore(cameraScore, sensorScore, cW, sW);

    // -----------------------------------------------------------------------
    // 4. Modality agreement & fusion confidence
    // -----------------------------------------------------------------------
    final double agreement = (1.0 - (cameraScore - sensorScore).abs()).clamp(0.0, 1.0);
    final double confidence = _fusionConfidence(
      agreement: agreement,
      posConfidence: poseResult.overallPoseConfidence,
      imuSymmetry: imuEmbedding.bilateralSymmetryScore,
    );

    // -----------------------------------------------------------------------
    // 5. Risk level classification
    // -----------------------------------------------------------------------
    final ScreeningRiskLevel riskLevel;
    if (fusedScore >= higherRiskThreshold) {
      riskLevel = ScreeningRiskLevel.higher;
    } else if (fusedScore >= moderateRiskThreshold) {
      riskLevel = ScreeningRiskLevel.moderate;
    } else {
      riskLevel = ScreeningRiskLevel.lower;
    }

    // -----------------------------------------------------------------------
    // 6. Build pitch-ready clinical insights
    // -----------------------------------------------------------------------
    final insights = _buildInsights(
      cameraScore: cameraScore,
      sensorScore: sensorScore,
      agreement: agreement,
      fusedScore: fusedScore,
      imuEmbedding: imuEmbedding,
      poseResult: poseResult,
    );

    return FusedRiskResult(
      fusedRiskScore: double.parse(fusedScore.toStringAsFixed(4)),
      riskLevel: riskLevel,
      fusionConfidence: double.parse(confidence.toStringAsFixed(4)),
      cameraContribution: double.parse(cW.toStringAsFixed(3)),
      sensorContribution: double.parse(sW.toStringAsFixed(3)),
      modalityAgreement: double.parse(agreement.toStringAsFixed(4)),
      cameraRiskScore: double.parse(cameraScore.toStringAsFixed(4)),
      sensorRiskScore: double.parse(sensorScore.toStringAsFixed(4)),
      fusionMethod: fusionMethodId,
      insights: insights,
      isStubResult: poseResult.isStubResult || imuEmbedding.isStubResult,
      computedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Convert pose kinematics to a continuous risk score in [0, 1].
  // ---------------------------------------------------------------------------
  double _poseToRiskScore(PoseEstimationResult pose) {
    switch (pose.riskLevel) {
      case ScreeningRiskLevel.higher:
        // Map the continuous kinematics within the higher tier.
        final base = 0.65;
        final valgusExtra =
            ((pose.kneeValgusAngle - 8.0) / 12.0).clamp(0.0, 0.25);
        final shiftExtra =
            ((pose.trunkLateralShift - 0.20) / 0.30).clamp(0.0, 0.10);
        return (base + valgusExtra + shiftExtra).clamp(0.0, 1.0);
      case ScreeningRiskLevel.moderate:
        final base = 0.40;
        final valgusExtra =
            ((pose.kneeValgusAngle - 5.0) / 6.0).clamp(0.0, 0.15);
        return (base + valgusExtra).clamp(0.0, 1.0);
      case ScreeningRiskLevel.lower:
        final valgusExtra =
            (pose.kneeValgusAngle / 10.0).clamp(0.0, 0.25);
        return valgusExtra;
      case ScreeningRiskLevel.unavailable:
        return 0.5; // conservative neutral
    }
  }

  // ---------------------------------------------------------------------------
  // Clinical prior weight adjustment.
  // ---------------------------------------------------------------------------
  (double, double) _adjustWeights(PatientAssessment patient) {
    double sensorBoost = 0.0;

    // Older patients — sensor captures micro-tremor better than camera.
    final age = patient.age?.toDouble() ?? 55.0;
    if (age > 65) sensorBoost += 0.05;

    // High BMI — camera pose less reliable due to soft tissue artefact.
    final bmi = patient.bmi ?? 24.5;
    if (bmi > 30) sensorBoost += 0.05;

    // Multiple symptoms — sensor asymmetry signal is more discriminative.
    int symptomCount = 0;
    if (patient.painScore > 3) symptomCount++;
    if (patient.stiffnessScore > 3) symptomCount++;
    if (patient.morningStiffness) symptomCount++;
    if (patient.activityRelatedPain) symptomCount++;
    if (symptomCount >= 2) sensorBoost += 0.05;

    final adjustedSensor = (sensorWeight + sensorBoost).clamp(0.0, 0.80);
    final adjustedCamera = 1.0 - adjustedSensor;
    return (adjustedCamera, adjustedSensor);
  }

  // ---------------------------------------------------------------------------
  // Cross-attention weighted average fusion formula.
  // ---------------------------------------------------------------------------
  double _computeFusedScore(
    double camera,
    double sensor,
    double cW,
    double sW,
  ) {
    // Modality agreement (1 = perfectly aligned, 0 = opposite predictions).
    final w = 1.0 - (camera - sensor).abs();

    // Weighted average for the agreeing component.
    final fusedAgree = cW * camera + sW * sensor;

    // Conservative upper-bound for the disagreeing component.
    final fusedDisagree = max(camera, sensor);

    // Blend: high agreement → rely on weighted avg; low → be conservative.
    return (w * fusedAgree + (1.0 - w) * fusedDisagree).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Fusion confidence formula.
  // ---------------------------------------------------------------------------
  double _fusionConfidence({
    required double agreement,
    required double posConfidence,
    required double imuSymmetry,
  }) {
    // Base: modality agreement (higher = more trustworthy fused score).
    // Modulated by pose tracking quality and IMU bilateral symmetry
    // (symmetric movement → cleaner signal).
    final base = agreement * 0.60 + posConfidence * 0.25 + imuSymmetry * 0.15;
    return base.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Human-readable insights for pitch + clinical report.
  // ---------------------------------------------------------------------------
  List<String> _buildInsights({
    required double cameraScore,
    required double sensorScore,
    required double agreement,
    required double fusedScore,
    required ImuEmbedding imuEmbedding,
    required PoseEstimationResult poseResult,
  }) {
    final insights = <String>[];
    final agreementPct = (agreement * 100).round();

    // Modality agreement narrative.
    if (agreement >= 0.80) {
      insights.add(
        'Camera and sensor modalities showed high agreement ($agreementPct%) — '
        'fusion confidence is elevated.',
      );
    } else if (agreement >= 0.55) {
      insights.add(
        'Camera and sensor modalities showed moderate agreement ($agreementPct%) — '
        'both signals were weighted in the fusion.',
      );
    } else {
      insights.add(
        'Camera and sensor signals diverged ($agreementPct% agreement) — '
        'the conservative upper bound was applied to avoid under-estimation.',
      );
    }

    // Micro-tremor insight.
    if (imuEmbedding.microTremorScore > 0.40) {
      final pct = (imuEmbedding.microTremorScore * 100).round();
      insights.add(
        'Elevated micro-tremor activity detected by PatchTST sensor encoder '
        '($pct/100) — invisible to camera-only screening.',
      );
    }

    // Gait irregularity insight.
    if (imuEmbedding.gaitIrregularityScore > 0.35) {
      insights.add(
        'Sensor encoder identified inter-cycle gait irregularity consistent '
        'with compensatory loading patterns.',
      );
    }

    // Knee valgus insight.
    if (poseResult.kneeValgusAngle > 5.0) {
      insights.add(
        'YOLOv8-Pose detected ${poseResult.kneeValgusAngle.toStringAsFixed(1)}° '
        'knee valgus — a biomechanical marker associated with medial compartment OA.',
      );
    }

    // Trunk shift insight.
    if (poseResult.trunkLateralShift > 0.10) {
      final shiftPct = (poseResult.trunkLateralShift * 100).round();
      insights.add(
        'Lateral trunk shift of $shiftPct% trunk-height detected — '
        'consistent with antalgic gait to unload the affected knee.',
      );
    }

    // Bilateral symmetry.
    if (imuEmbedding.bilateralSymmetryScore < 0.80) {
      final asymPct =
          ((1.0 - imuEmbedding.bilateralSymmetryScore) * 100).round();
      insights.add(
        'Thigh–shin bilateral asymmetry of $asymPct% detected in IMU data — '
        'suggests asymmetric weight-bearing during movement.',
      );
    }

    return insights;
  }
}
