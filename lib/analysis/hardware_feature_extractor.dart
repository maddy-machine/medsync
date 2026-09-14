import 'dart:math';

import '../models/patient_assessment.dart';
import '../models/sensor_sample.dart';
import 'chair_stand_analyzer.dart';
import 'fast_walk_analyzer.dart';
import 'fast_walk_cycle_analyzer.dart';
import 'knee_angle_features.dart';
import 'movement_features.dart';

class HardwareFeatureExtractor {
  /// Builds the canonical 31-feature vector for
  /// the actual prototype hardware:
  ///
  ///     Thigh IMU + Shin IMU
  ///
  /// The feature names correspond to:
  ///
  ///     ai/src/features/hardware_feature_schema.py
  ///
  /// These features are intended for an experimental
  /// AI-assisted screening pipeline and are not
  /// themselves clinical diagnostic criteria.
  static MovementFeatureVector extract({
    required List<SensorSample> samples,
    required PatientAssessment patientAssessment,
    ChairStandResult? chairStandResult,
    FastWalkResult? fastWalkResult,
    FastWalkCycleResult? fastWalkCycleResult,
    KneeAngleFeatures? kneeFeatures,
  }) {
    final values = <String, double>{};

    // ==================================================
    // 1. KNEE KINEMATICS
    // ==================================================

    values['knee_rom'] =
        kneeFeatures?.rangeOfMotion ?? 0.0;

    values['knee_mean_angle'] =
        kneeFeatures?.meanAngle ?? 0.0;

    values['knee_angle_std'] =
        kneeFeatures?.angleStandardDeviation ?? 0.0;

    values['knee_min_angle'] =
        kneeFeatures?.minimumAngle ?? 0.0;

    values['knee_max_angle'] =
        kneeFeatures?.maximumAngle ?? 0.0;

    // ==================================================
    // 2. KNEE ANGULAR MOTION
    // ==================================================

    values['knee_angular_velocity_mean'] =
        kneeFeatures?.angularVelocityMean ?? 0.0;

    values['knee_angular_velocity_std'] =
        kneeFeatures
                ?.angularVelocityStandardDeviation ??
            0.0;

    values['knee_angular_acceleration_mean'] =
        kneeFeatures
                ?.angularAccelerationMean ??
            0.0;

    values['knee_angular_acceleration_std'] =
        kneeFeatures
                ?.angularAccelerationStandardDeviation ??
            0.0;

    // ==================================================
    // 3. THIGH IMU
    // ==================================================

    final thighAcceleration =
        _calculateMagnitudeStatistics(
      samples,
      sensor: _SensorPart.thigh,
      signal: _SignalType.acceleration,
    );

    final thighGyroscope =
        _calculateMagnitudeStatistics(
      samples,
      sensor: _SensorPart.thigh,
      signal: _SignalType.gyroscope,
    );

    values['thigh_acceleration_mean'] =
        thighAcceleration.mean;

    values['thigh_acceleration_std'] =
        thighAcceleration.standardDeviation;

    values['thigh_gyro_mean'] =
        thighGyroscope.mean;

    values['thigh_gyro_std'] =
        thighGyroscope.standardDeviation;

    // ==================================================
    // 4. SHIN IMU
    // ==================================================

    final shinAcceleration =
        _calculateMagnitudeStatistics(
      samples,
      sensor: _SensorPart.shin,
      signal: _SignalType.acceleration,
    );

    final shinGyroscope =
        _calculateMagnitudeStatistics(
      samples,
      sensor: _SensorPart.shin,
      signal: _SignalType.gyroscope,
    );

    values['shin_acceleration_mean'] =
        shinAcceleration.mean;

    values['shin_acceleration_std'] =
        shinAcceleration.standardDeviation;

    values['shin_gyro_mean'] =
        shinGyroscope.mean;

    values['shin_gyro_std'] =
        shinGyroscope.standardDeviation;

    // ==================================================
    // 5. MOVEMENT QUALITY
    // ==================================================

    values['knee_angle_cycle_variability'] =
        kneeFeatures?.angleCycleVariability ?? 0.0;

    values['knee_velocity_cycle_variability'] =
        kneeFeatures?.velocityCycleVariability ?? 0.0;

    values['movement_smoothness'] =
        _calculateMovementSmoothness(
      samples,
    );

    values['movement_variability'] =
        _calculateMovementVariability(
      samples,
    );

    // ==================================================
    // 6. TEMPORAL FEATURES
    // ==================================================

    final cycleStatistics =
        _calculateMovementCycleStatistics(
      chairStandResult,
      fastWalkCycleResult,
    );

    values['movement_cycle_duration_mean'] =
        cycleStatistics.mean;

    values['movement_cycle_duration_std'] =
        cycleStatistics.standardDeviation;

    values['movement_cycle_duration_cv'] =
        cycleStatistics.coefficientOfVariation;

    // ==================================================
    // 7. FUNCTIONAL TEST FEATURES
    // ==================================================

    values['chair_stand_repetitions'] =
        chairStandResult
                ?.repetitions
                .toDouble() ??
            0.0;

    values['chair_stand_average_cycle_duration'] =
        chairStandResult
                ?.averageCycleDuration ??
            0.0;

    values['walk_duration_seconds'] =
        fastWalkResult
                ?.durationSeconds ??
            0.0;

    values['walk_cycle_duration_mean'] =
        fastWalkCycleResult
                ?.averageCycleDuration ??
            0.0;

    values['walk_cycle_duration_std'] =
        fastWalkCycleResult
                ?.cycleDurationStd ??
            0.0;

    // ==================================================
    // 8. PATIENT CONTEXT
    // ==================================================

    values['patient_age'] =
        patientAssessment.age
                ?.toDouble() ??
            0.0;

    final patientBmi =
        patientAssessment.bmi;

    values['patient_bmi'] =
        patientBmi != null &&
                patientBmi.isFinite
            ? patientBmi
            : 0.0;

    // ==================================================
    // FINAL SAFETY CHECK
    // ==================================================

    _validateCanonicalFeatureVector(
      values,
    );

    return MovementFeatureVector(
      values: values,
    );
  }

  // ====================================================
  // SENSOR STATISTICS
  // ====================================================

  static _Statistics
      _calculateMagnitudeStatistics(
    List<SensorSample> samples, {
    required _SensorPart sensor,
    required _SignalType signal,
  }) {
    if (samples.isEmpty) {
      return const _Statistics(
        mean: 0.0,
        standardDeviation: 0.0,
      );
    }

    final values = <double>[];

    for (final sample in samples) {
      final double value;

      if (sensor == _SensorPart.thigh &&
          signal == _SignalType.acceleration) {
        value = _magnitude(
          sample.thigh.ax,
          sample.thigh.ay,
          sample.thigh.az,
        );
      } else if (
          sensor == _SensorPart.thigh &&
          signal == _SignalType.gyroscope) {
        value = _magnitude(
          sample.thigh.gx,
          sample.thigh.gy,
          sample.thigh.gz,
        );
      } else if (
          sensor == _SensorPart.shin &&
          signal == _SignalType.acceleration) {
        value = _magnitude(
          sample.shin.ax,
          sample.shin.ay,
          sample.shin.az,
        );
      } else {
        value = _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        );
      }

      if (value.isFinite) {
        values.add(value);
      }
    }

    return _Statistics(
      mean: _mean(values),
      standardDeviation:
          _standardDeviation(values),
    );
  }

  // ====================================================
  // MOVEMENT SMOOTHNESS
  // ====================================================

  static double _calculateMovementSmoothness(
    List<SensorSample> samples,
  ) {
    if (samples.length < 3) {
      return 0.0;
    }

    final values = <double>[];

    for (final sample in samples) {
      values.add(
        _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        ),
      );
    }

    final secondDifferences = <double>[];

    for (int i = 2;
        i < values.length;
        i++) {
      final secondDifference =
          values[i] -
          2 * values[i - 1] +
          values[i - 2];

      if (secondDifference.isFinite) {
        secondDifferences.add(
          secondDifference.abs(),
        );
      }
    }

    return _mean(
      secondDifferences,
    );
  }

  // ====================================================
  // MOVEMENT VARIABILITY
  // ====================================================

  static double _calculateMovementVariability(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      return 0.0;
    }

    final magnitudes = <double>[];

    for (final sample in samples) {
      magnitudes.add(
        _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        ),
      );
    }

    final differences = <double>[];

    for (int i = 1;
        i < magnitudes.length;
        i++) {
      final difference =
          (magnitudes[i] -
                  magnitudes[i - 1])
              .abs();

      if (difference.isFinite) {
        differences.add(
          difference,
        );
      }
    }

    return _standardDeviation(
      differences,
    );
  }

  // ====================================================
  // MOVEMENT CYCLE STATISTICS
  // ====================================================

  static _CycleStatistics
      _calculateMovementCycleStatistics(
    ChairStandResult? chairStandResult,
    FastWalkCycleResult? fastWalkCycleResult,
  ) {
    List<double> durations = [];

    if (chairStandResult != null &&
        chairStandResult
            .cycleDurations
            .isNotEmpty) {
      durations = List<double>.from(
        chairStandResult.cycleDurations,
      );
    } else if (
        fastWalkCycleResult != null &&
        fastWalkCycleResult
            .cycleDurations
            .isNotEmpty
    ) {
      durations = List<double>.from(
        fastWalkCycleResult
            .cycleDurations,
      );
    }

    if (durations.isEmpty) {
      return const _CycleStatistics(
        mean: 0.0,
        standardDeviation: 0.0,
        coefficientOfVariation: 0.0,
      );
    }

    final mean =
        _mean(durations);

    final standardDeviation =
        _standardDeviation(
      durations,
    );

    final coefficientOfVariation =
        mean > 0
            ? standardDeviation / mean
            : 0.0;

    return _CycleStatistics(
      mean: mean,
      standardDeviation:
          standardDeviation,
      coefficientOfVariation:
          coefficientOfVariation,
    );
  }

  // ====================================================
  // FEATURE VECTOR VALIDATION
  // ====================================================

  static void _validateCanonicalFeatureVector(
    Map<String, double> values,
  ) {
    const expectedFeatures = [
      'knee_rom',
      'knee_mean_angle',
      'knee_angle_std',
      'knee_min_angle',
      'knee_max_angle',
      'knee_angular_velocity_mean',
      'knee_angular_velocity_std',
      'knee_angular_acceleration_mean',
      'knee_angular_acceleration_std',
      'thigh_acceleration_mean',
      'thigh_acceleration_std',
      'thigh_gyro_mean',
      'thigh_gyro_std',
      'shin_acceleration_mean',
      'shin_acceleration_std',
      'shin_gyro_mean',
      'shin_gyro_std',
      'knee_angle_cycle_variability',
      'knee_velocity_cycle_variability',
      'movement_smoothness',
      'movement_variability',
      'movement_cycle_duration_mean',
      'movement_cycle_duration_std',
      'movement_cycle_duration_cv',
      'chair_stand_repetitions',
      'chair_stand_average_cycle_duration',
      'walk_duration_seconds',
      'walk_cycle_duration_mean',
      'walk_cycle_duration_std',
      'patient_age',
      'patient_bmi',
    ];

    if (values.length !=
        expectedFeatures.length) {
      throw StateError(
        'Hardware feature vector contains '
        '${values.length} features, but '
        '${expectedFeatures.length} '
        'were expected.',
      );
    }

    for (final feature
        in expectedFeatures) {
      if (!values.containsKey(feature)) {
        throw StateError(
          'Missing canonical feature: '
          '$feature',
        );
      }

      if (!values[feature]!.isFinite) {
        throw StateError(
          'Non-finite canonical feature: '
          '$feature',
        );
      }
    }
  }

  // ====================================================
  // MATH HELPERS
  // ====================================================

  static double _magnitude(
    double x,
    double y,
    double z,
  ) {
    return sqrt(
      x * x +
      y * y +
      z * z,
    );
  }

  static double _mean(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return 0.0;
    }

    return values.reduce(
          (double a, double b) =>
              a + b,
        ) /
        values.length;
  }

  static double _standardDeviation(
    List<double> values,
  ) {
    if (values.length < 2) {
      return 0.0;
    }

    final mean =
        _mean(values);

    double sum = 0.0;

    for (final value in values) {
      final difference =
          value - mean;

      sum +=
          difference * difference;
    }

    return sqrt(
      sum / values.length,
    );
  }
}

// ======================================================
// INTERNAL TYPES
// ======================================================

enum _SensorPart {
  thigh,
  shin,
}

enum _SignalType {
  acceleration,
  gyroscope,
}

class _Statistics {
  final double mean;
  final double standardDeviation;

  const _Statistics({
    required this.mean,
    required this.standardDeviation,
  });
}

class _CycleStatistics {
  final double mean;
  final double standardDeviation;
  final double coefficientOfVariation;

  const _CycleStatistics({
    required this.mean,
    required this.standardDeviation,
    required this.coefficientOfVariation,
  });
}