import 'dart:math';

class KneeAngleFeatures {
  final double minimumAngle;
  final double maximumAngle;
  final double rangeOfMotion;
  final double meanAngle;
  final double angleStandardDeviation;

  final double angularVelocityMean;
  final double angularVelocityStandardDeviation;

  final double angularAccelerationMean;
  final double angularAccelerationStandardDeviation;

  final double angleCycleVariability;
  final double velocityCycleVariability;

  const KneeAngleFeatures({
    required this.minimumAngle,
    required this.maximumAngle,
    required this.rangeOfMotion,
    required this.meanAngle,
    required this.angleStandardDeviation,
    required this.angularVelocityMean,
    required this.angularVelocityStandardDeviation,
    required this.angularAccelerationMean,
    required this.angularAccelerationStandardDeviation,
    required this.angleCycleVariability,
    required this.velocityCycleVariability,
  });

  Map<String, double> toMap() {
    return {
      'knee_min_angle': minimumAngle,
      'knee_max_angle': maximumAngle,
      'knee_range_of_motion': rangeOfMotion,
      'knee_mean_angle': meanAngle,
      'knee_angle_std': angleStandardDeviation,
      'knee_angular_velocity_mean':
          angularVelocityMean,
      'knee_angular_velocity_std':
          angularVelocityStandardDeviation,
      'knee_angular_acceleration_mean':
          angularAccelerationMean,
      'knee_angular_acceleration_std':
          angularAccelerationStandardDeviation,
      'knee_angle_cycle_variability':
          angleCycleVariability,
      'knee_velocity_cycle_variability':
          velocityCycleVariability,
    };
  }

  static KneeAngleFeatures calculate({
    required List<double> angles,
    required List<double> timestamps,
    List<double>? angularVelocities,
    List<double>? angularAccelerations,
    List<double>? cycleAngleRanges,
    List<double>? cycleVelocityMeans,
  }) {
    if (angles.isEmpty ||
        angles.length != timestamps.length) {
      return const KneeAngleFeatures(
        minimumAngle: 0.0,
        maximumAngle: 0.0,
        rangeOfMotion: 0.0,
        meanAngle: 0.0,
        angleStandardDeviation: 0.0,
        angularVelocityMean: 0.0,
        angularVelocityStandardDeviation: 0.0,
        angularAccelerationMean: 0.0,
        angularAccelerationStandardDeviation: 0.0,
        angleCycleVariability: 0.0,
        velocityCycleVariability: 0.0,
      );
    }

    final minimum = angles.reduce(min);
    final maximum = angles.reduce(max);

    final mean =
        _mean(angles);

    final angleStandardDeviation =
        _standardDeviation(angles);

    final velocities =
        angularVelocities ??
        _calculateAngularVelocity(
          angles,
          timestamps,
        );

    final accelerations =
        angularAccelerations ??
        _calculateAngularAcceleration(
          velocities,
          timestamps,
        );

    final velocityMean =
        _mean(velocities);

    final velocityStandardDeviation =
        _standardDeviation(
      velocities,
    );

    final accelerationMean =
        _mean(accelerations);

    final accelerationStandardDeviation =
        _standardDeviation(
      accelerations,
    );

    final angleCycleVariability =
        _standardDeviation(
      cycleAngleRanges ?? const [],
    );

    final velocityCycleVariability =
        _standardDeviation(
      cycleVelocityMeans ?? const [],
    );

    return KneeAngleFeatures(
      minimumAngle: minimum,
      maximumAngle: maximum,
      rangeOfMotion:
          maximum - minimum,
      meanAngle: mean,
      angleStandardDeviation:
          angleStandardDeviation,
      angularVelocityMean:
          velocityMean,
      angularVelocityStandardDeviation:
          velocityStandardDeviation,
      angularAccelerationMean:
          accelerationMean,
      angularAccelerationStandardDeviation:
          accelerationStandardDeviation,
      angleCycleVariability:
          angleCycleVariability,
      velocityCycleVariability:
          velocityCycleVariability,
    );
  }

  static List<double> _calculateAngularVelocity(
    List<double> angles,
    List<double> timestamps,
  ) {
    final velocities = <double>[];

    if (angles.length < 2 ||
        timestamps.length != angles.length) {
      return velocities;
    }

    for (int i = 1; i < angles.length; i++) {
      final deltaTime =
          timestamps[i] -
          timestamps[i - 1];

      if (deltaTime <= 0) {
        continue;
      }

      final velocity =
          (angles[i] -
                  angles[i - 1]) /
              deltaTime;

      if (velocity.isFinite) {
        velocities.add(
          velocity,
        );
      }
    }

    return velocities;
  }

  static List<double> _calculateAngularAcceleration(
    List<double> velocities,
    List<double> timestamps,
  ) {
    final accelerations = <double>[];

    if (velocities.length < 2) {
      return accelerations;
    }

    for (int i = 1;
        i < velocities.length;
        i++) {
      final timestampIndex =
          i + 1;

      if (timestampIndex >=
          timestamps.length) {
        break;
      }

      final deltaTime =
          timestamps[timestampIndex] -
          timestamps[timestampIndex - 1];

      if (deltaTime <= 0) {
        continue;
      }

      final acceleration =
          (velocities[i] -
                  velocities[i - 1]) /
              deltaTime;

      if (acceleration.isFinite) {
        accelerations.add(
          acceleration,
        );
      }
    }

    return accelerations;
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