import '../analysis/chair_stand_analyzer.dart';
import '../analysis/fast_walk_analyzer.dart';
import '../analysis/fast_walk_cycle_analyzer.dart';
import '../analysis/knee_angle_features.dart';
import '../analysis/movement_features.dart';
import 'patient_assessment.dart';

class ScreeningSession {
  PatientAssessment patientAssessment;

  ChairStandResult? chairStandResult;
  MovementFeatureVector? chairStandFeatures;
  KneeAngleFeatures? chairStandKneeFeatures;

  FastWalkResult? fastWalkResult;
  FastWalkCycleResult? fastWalkCycleResult;
  KneeAngleFeatures? fastWalkKneeFeatures;

  ScreeningSession({
    required this.patientAssessment,
  });

  bool get hasChairStand =>
      chairStandResult != null &&
      chairStandFeatures != null;

  bool get hasFastWalk =>
      fastWalkResult != null &&
      fastWalkCycleResult != null;

  bool get hasChairStandKneeMotion =>
      chairStandKneeFeatures != null;

  bool get hasFastWalkKneeMotion =>
      fastWalkKneeFeatures != null;

  bool get hasKneeMotion =>
      hasChairStandKneeMotion ||
      hasFastWalkKneeMotion;

  bool get isComplete =>
      hasChairStand &&
      hasFastWalk &&
      hasKneeMotion;

  void updateAssessment(
    PatientAssessment assessment,
  ) {
    patientAssessment = assessment;
  }
}