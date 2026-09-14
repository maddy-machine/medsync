import 'dart:math';

import '../models/sensor_sample.dart';
import 'chair_stand_analyzer.dart';
import 'movement_features.dart';

class ChairStandFeatureExtractor {
  static MovementFeatureVector extract({
    required List<SensorSample> samples,
    required ChairStandResult analysis,
  }) {
    if (samples.isEmpty) {
      return const MovementFeatureVector(
        values: {
          'chair_repetitions': 0.0,
          'chair_avg_cycle_duration': 0.0,
          'chair_cycle_duration_std': 0.0,
          'chair_cycle_duration_cv': 0.0,
          'chair_movement_amplitude': 0.0,
          'shin_gyro_mean': 0.0,
          'shin_gyro_std': 0.0,
          'thigh_gyro_mean': 0.0,
          'thigh_gyro_std': 0.0,
          'shin_accel_std': 0.0,
          'thigh_accel_std': 0.0,
        },
      );
    }

    final shinGyroMagnitude = <double>[];
    final thighGyroMagnitude = <double>[];

    final shinAccelMagnitude = <double>[];
    final thighAccelMagnitude = <double>[];

    for (final sample in samples) {
      shinGyroMagnitude.add(
        _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        ),
      );

      thighGyroMagnitude.add(
        _magnitude(
          sample.thigh.gx,
          sample.thigh.gy,
          sample.thigh.gz,
        ),
      );

      shinAccelMagnitude.add(
        _magnitude(
          sample.shin.ax,
          sample.shin.ay,
          sample.shin.az,
        ),
      );

      thighAccelMagnitude.add(
        _magnitude(
          sample.thigh.ax,
          sample.thigh.ay,
          sample.thigh.az,
        ),
      );
    }

    final cycleStd =
        _standardDeviation(
          analysis.cycleDurations,
        );

    final cycleCv =
        analysis.averageCycleDuration > 0
            ? cycleStd /
                analysis.averageCycleDuration
            : 0.0;

    return MovementFeatureVector(
      values: {
        'chair_repetitions':
            analysis.repetitions.toDouble(),

        'chair_avg_cycle_duration':
            analysis.averageCycleDuration,

        'chair_cycle_duration_std':
            cycleStd,

        'chair_cycle_duration_cv':
            cycleCv,

        'chair_movement_amplitude':
            analysis.movementAmplitude,

        'shin_gyro_mean':
            _mean(shinGyroMagnitude),

        'shin_gyro_std':
            _standardDeviation(
              shinGyroMagnitude,
            ),

        'thigh_gyro_mean':
            _mean(thighGyroMagnitude),

        'thigh_gyro_std':
            _standardDeviation(
              thighGyroMagnitude,
            ),

        'shin_accel_std':
            _standardDeviation(
              shinAccelMagnitude,
            ),

        'thigh_accel_std':
            _standardDeviation(
              thighAccelMagnitude,
            ),
      },
    );
  }

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

    double sum = 0.0;

    for (final value in values) {
      sum += value;
    }

    return sum / values.length;
  }

  static double _standardDeviation(
    List<double> values,
  ) {
    if (values.length < 2) {
      return 0.0;
    }

    final mean = _mean(values);

    double sum = 0.0;

    for (final value in values) {
      final difference = value - mean;
      sum += difference * difference;
    }

    return sqrt(
      sum / values.length,
    );
  }
}