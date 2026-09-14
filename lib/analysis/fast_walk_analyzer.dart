import 'dart:math';

import '../models/sensor_sample.dart';

class FastWalkResult {
  final double durationSeconds;

  final double shinDynamicAccelerationMean;
  final double shinDynamicAccelerationStd;

  final double thighDynamicAccelerationMean;
  final double thighDynamicAccelerationStd;

  final double shinGyroscopeMean;
  final double shinGyroscopeStd;

  final double thighGyroscopeMean;
  final double thighGyroscopeStd;

  final double movementVariability;

  const FastWalkResult({
    required this.durationSeconds,
    required this.shinDynamicAccelerationMean,
    required this.shinDynamicAccelerationStd,
    required this.thighDynamicAccelerationMean,
    required this.thighDynamicAccelerationStd,
    required this.shinGyroscopeMean,
    required this.shinGyroscopeStd,
    required this.thighGyroscopeMean,
    required this.thighGyroscopeStd,
    required this.movementVariability,
  });

  // Backward-compatible getters.
  //
  // These allow the existing UI to continue using
  // the previous property names while the actual
  // stored features now represent dynamic
  // acceleration.

  double get shinAccelerationMean =>
      shinDynamicAccelerationMean;

  double get shinAccelerationStd =>
      shinDynamicAccelerationStd;

  double get thighAccelerationMean =>
      thighDynamicAccelerationMean;

  double get thighAccelerationStd =>
      thighDynamicAccelerationStd;

  Map<String, double> toMap() {
    return {
      'walk_duration_seconds':
          durationSeconds,

      'walk_shin_dynamic_accel_mean':
          shinDynamicAccelerationMean,

      'walk_shin_dynamic_accel_std':
          shinDynamicAccelerationStd,

      'walk_thigh_dynamic_accel_mean':
          thighDynamicAccelerationMean,

      'walk_thigh_dynamic_accel_std':
          thighDynamicAccelerationStd,

      'walk_shin_gyro_mean':
          shinGyroscopeMean,

      'walk_shin_gyro_std':
          shinGyroscopeStd,

      'walk_thigh_gyro_mean':
          thighGyroscopeMean,

      'walk_thigh_gyro_std':
          thighGyroscopeStd,

      'walk_movement_variability':
          movementVariability,
    };
  }

  static FastWalkResult analyze(
    List<SensorSample> samples,
  ) {
    if (samples.length < 20) {
      return const FastWalkResult(
        durationSeconds: 0,
        shinDynamicAccelerationMean: 0,
        shinDynamicAccelerationStd: 0,
        thighDynamicAccelerationMean: 0,
        thighDynamicAccelerationStd: 0,
        shinGyroscopeMean: 0,
        shinGyroscopeStd: 0,
        thighGyroscopeMean: 0,
        thighGyroscopeStd: 0,
        movementVariability: 0,
      );
    }

    final shinDynamicAcceleration =
        <double>[];

    final thighDynamicAcceleration =
        <double>[];

    final shinGyroscope =
        <double>[];

    final thighGyroscope =
        <double>[];

    for (final sample in samples) {
      final shinAccelMagnitude =
          _magnitude(
        sample.shin.ax,
        sample.shin.ay,
        sample.shin.az,
      );

      final thighAccelMagnitude =
          _magnitude(
        sample.thigh.ax,
        sample.thigh.ay,
        sample.thigh.az,
      );

      // Approximate removal of gravitational
      // acceleration.
      //
      // This is a prototype approach.
      // Later, when the actual IMU hardware and
      // mounting orientation are confirmed, gravity
      // removal can use sensor orientation directly.

      final shinDynamic =
          (shinAccelMagnitude - 9.81).abs();

      final thighDynamic =
          (thighAccelMagnitude - 9.81).abs();

      shinDynamicAcceleration.add(
        shinDynamic,
      );

      thighDynamicAcceleration.add(
        thighDynamic,
      );

      shinGyroscope.add(
        _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        ),
      );

      thighGyroscope.add(
        _magnitude(
          sample.thigh.gx,
          sample.thigh.gy,
          sample.thigh.gz,
        ),
      );
    }

    final durationSeconds =
        (samples.last.timestamp -
                samples.first.timestamp) /
            1000.0;

    final shinAccelMean =
        _mean(
      shinDynamicAcceleration,
    );

    final shinAccelStd =
        _standardDeviation(
      shinDynamicAcceleration,
    );

    final thighAccelMean =
        _mean(
      thighDynamicAcceleration,
    );

    final thighAccelStd =
        _standardDeviation(
      thighDynamicAcceleration,
    );

    final shinGyroMean =
        _mean(shinGyroscope);

    final shinGyroStd =
        _standardDeviation(
      shinGyroscope,
    );

    final thighGyroMean =
        _mean(thighGyroscope);

    final thighGyroStd =
        _standardDeviation(
      thighGyroscope,
    );

    final movementVariability =
        _calculateMovementVariability(
      shinDynamicAcceleration,
    );

    return FastWalkResult(
      durationSeconds:
          durationSeconds,

      shinDynamicAccelerationMean:
          shinAccelMean,

      shinDynamicAccelerationStd:
          shinAccelStd,

      thighDynamicAccelerationMean:
          thighAccelMean,

      thighDynamicAccelerationStd:
          thighAccelStd,

      shinGyroscopeMean:
          shinGyroMean,

      shinGyroscopeStd:
          shinGyroStd,

      thighGyroscopeMean:
          thighGyroMean,

      thighGyroscopeStd:
          thighGyroStd,

      movementVariability:
          movementVariability,
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
      return 0;
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
      return 0;
    }

    final mean =
        _mean(values);

    double sum = 0;

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

  static double _calculateMovementVariability(
    List<double> values,
  ) {
    if (values.length < 3) {
      return 0;
    }

    final differences =
        <double>[];

    for (int i = 1;
        i < values.length;
        i++) {
      differences.add(
        (values[i] - values[i - 1])
            .abs(),
      );
    }

    return _standardDeviation(
      differences,
    );
  }
}