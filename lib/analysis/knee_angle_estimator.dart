import 'dart:math';

import 'quaternion.dart';

class KneeAngleEstimator {
  final FlexionAxis flexionAxis;

  /// Relative orientation of the thigh and shin
  /// when the patient is in the neutral/reference
  /// position.
  Quaternion _neutralQuaternion;

  KneeAngleEstimator({
    this.flexionAxis = FlexionAxis.y,
    Quaternion? neutralQuaternion,
  }) : _neutralQuaternion =
            neutralQuaternion ??
            const Quaternion.identity();

  /// Captures the current relative thigh-shin
  /// orientation as the neutral reference.
  void calibrateNeutral(
    Quaternion relativeQuaternion,
  ) {
    _neutralQuaternion =
        relativeQuaternion.normalized();
  }

  /// Returns the current knee flexion/extension
  /// angle relative to the calibrated neutral
  /// position.
  double estimate(
    Quaternion relativeQuaternion,
  ) {
    final current =
        relativeQuaternion.normalized();

    final neutralInverse =
        _neutralQuaternion.conjugate();

    final relativeToNeutral =
        neutralInverse
            .multiply(current)
            .normalized();

    return _axisAngleDegrees(
      relativeToNeutral,
    );
  }

  /// Returns the currently stored neutral
  /// orientation.
  Quaternion get neutralQuaternion =>
      _neutralQuaternion;

  /// Resets the neutral reference.
  void resetNeutral() {
    _neutralQuaternion =
        const Quaternion.identity();
  }

  double _axisAngleDegrees(
    Quaternion quaternion,
  ) {
    final q =
        quaternion.normalized();

    final vectorComponent =
        switch (flexionAxis) {
      FlexionAxis.x => q.x,
      FlexionAxis.y => q.y,
      FlexionAxis.z => q.z,
    };

    final angle =
        2.0 *
        atan2(
          vectorComponent.abs(),
          q.w.abs(),
        );

    final degrees =
        angle * 180.0 / pi;

    return degrees.clamp(
      0.0,
      180.0,
    );
  }
}

enum FlexionAxis {
  x,
  y,
  z,
}