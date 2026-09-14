import 'chair_stand_analyzer.dart';
import 'fast_walk_analyzer.dart';
import 'fast_walk_cycle_analyzer.dart';
import 'knee_angle_features.dart';
import 'movement_features.dart';
import 'patient_assessment_features.dart';
import '../models/patient_assessment.dart';

class FullMovementFeatureVector {
  final MovementFeatureVector features;

  const FullMovementFeatureVector({
    required this.features,
  });

  factory FullMovementFeatureVector.fromAnalysis({
    ChairStandResult? chairStandResult,
    MovementFeatureVector? chairStandFeatures,

    FastWalkResult? fastWalkResult,
    FastWalkCycleResult? fastWalkCycleResult,

    KneeAngleFeatures? chairStandKneeFeatures,
    KneeAngleFeatures? fastWalkKneeFeatures,

    PatientAssessment? patientAssessment,
  }) {
    final combined = <String, double>{};

    // --------------------------------------------------
    // Chair Stand features
    // --------------------------------------------------

    if (chairStandFeatures != null) {
      for (final entry
          in chairStandFeatures.values.entries) {
        combined[
          _prefixFeature(
            'chair',
            entry.key,
          )
        ] = entry.value;
      }
    }

    // --------------------------------------------------
    // Fast Walk features
    // --------------------------------------------------

    if (fastWalkResult != null) {
      for (final entry
          in fastWalkResult.toMap().entries) {
        combined[
          _prefixFeature(
            'walk',
            entry.key,
          )
        ] = entry.value;
      }
    }

    // --------------------------------------------------
    // Fast Walk cycle features
    // --------------------------------------------------

    if (fastWalkCycleResult != null) {
      for (final entry
          in fastWalkCycleResult.toMap().entries) {
        combined[
          _prefixFeature(
            'walk',
            entry.key,
          )
        ] = entry.value;
      }
    }

    // --------------------------------------------------
    // Chair Stand knee-motion features
    // --------------------------------------------------

    if (chairStandKneeFeatures != null) {
      for (final entry
          in chairStandKneeFeatures.toMap().entries) {
        combined[
          _prefixFeature(
            'chair_knee',
            entry.key,
          )
        ] = entry.value;
      }
    }

    // --------------------------------------------------
    // Fast Walk knee-motion features
    // --------------------------------------------------

    if (fastWalkKneeFeatures != null) {
      for (final entry
          in fastWalkKneeFeatures.toMap().entries) {
        combined[
          _prefixFeature(
            'walk_knee',
            entry.key,
          )
        ] = entry.value;
      }
    }

    // --------------------------------------------------
    // Patient assessment features
    // --------------------------------------------------

    if (patientAssessment != null) {
      final assessmentFeatures =
          PatientAssessmentFeatures
              .fromAssessment(
        patientAssessment,
      );

      for (final entry
          in assessmentFeatures.values.entries) {
        combined[
          _prefixFeature(
            'patient',
            entry.key,
          )
        ] = entry.value;
      }
    }

    return FullMovementFeatureVector(
      features: MovementFeatureVector(
        values: combined,
      ),
    );
  }

  Map<String, double> get values =>
      features.values;

  List<String> get names =>
      features.names;

  int get length =>
      features.length;

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(
      features.values,
    );
  }

  static String _prefixFeature(
    String prefix,
    String featureName,
  ) {
    final cleanedName =
        featureName
            .replaceFirst(
              RegExp(r'^chair_'),
              '',
            )
            .replaceFirst(
              RegExp(r'^walk_'),
              '',
            )
            .replaceFirst(
              RegExp(r'^patient_'),
              '',
            )
            .replaceFirst(
              RegExp(r'^knee_'),
              '',
            );

    return '${prefix}_$cleanedName';
  }
}