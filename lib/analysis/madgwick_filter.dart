import 'dart:math';

import 'quaternion.dart';

class MadgwickFilter {
  Quaternion _q = const Quaternion.identity();

  final double beta;

  MadgwickFilter({
    this.beta = 0.08,
  });

  // Compatibility with the existing
  // dual_imu_orientation.dart code.
  Quaternion get quaternion => _q;

  Quaternion get orientation => _q;

  void reset() {
    _q = const Quaternion.identity();
  }

  Quaternion update({
    required double gx,
    required double gy,
    required double gz,
    required double ax,
    required double ay,
    required double az,
    double? dt,
    double? deltaTime,
  }) {
    final timeStep =
        dt ?? deltaTime ?? 0.01;

    if (timeStep <= 0) {
      return _q;
    }

    var q = _q;

    final accelerometerMagnitude =
        sqrt(
          ax * ax +
              ay * ay +
              az * az,
        );

    if (accelerometerMagnitude > 0) {
      ax /= accelerometerMagnitude;
      ay /= accelerometerMagnitude;
      az /= accelerometerMagnitude;

      final q1 = q.w;
      final q2 = q.x;
      final q3 = q.y;
      final q4 = q.z;

      final f1 =
          2 *
              (q2 * q4 -
                  q1 * q3) -
          ax;

      final f2 =
          2 *
              (q1 * q2 +
                  q3 * q4) -
          ay;

      final f3 =
          2 *
              (0.5 -
                  q2 * q2 -
                  q3 * q3) -
          az;

      final j11or24 = 2 * q3;
      final j12or23 = 2 * q4;
      final j13or22 = 2 * q1;
      final j14or21 = 2 * q2;

      final gradientX =
          j11or24 * f1 +
          j12or23 * f2 -
          j13or22 * f3;

      final gradientY =
          -j14or21 * f1 +
          j13or22 * f2 -
          j12or23 * f3;

      final gradientZ =
          j11or24 * f1 +
          j14or21 * f2 -
          j11or24 * f3;

      final gradientW =
          -j12or23 * f1 +
          j11or24 * f2;

      final gradientMagnitude =
          sqrt(
            gradientW * gradientW +
                gradientX * gradientX +
                gradientY * gradientY +
                gradientZ * gradientZ,
          );

      if (gradientMagnitude > 0) {
        final scale =
            beta / gradientMagnitude;

        q = Quaternion(
          q.w -
              gradientW *
                  scale *
                  timeStep,
          q.x -
              gradientX *
                  scale *
                  timeStep,
          q.y -
              gradientY *
                  scale *
                  timeStep,
          q.z -
              gradientZ *
                  scale *
                  timeStep,
        ).normalized();
      }
    }

    q = q.integrateGyroscope(
      gx: gx,
      gy: gy,
      gz: gz,
      dt: timeStep,
    );

    _q = q;

    return q;
  }
}