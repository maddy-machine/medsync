import 'madgwick_filter.dart';
import 'quaternion.dart';

class DualImuOrientation {
  final MadgwickFilter thighFilter;
  final MadgwickFilter shinFilter;

  int? _previousTimestamp;

  DualImuOrientation({
    double beta = 0.1,
  })  : thighFilter = MadgwickFilter(
          beta: beta,
        ),
        shinFilter = MadgwickFilter(
          beta: beta,
        );

  Quaternion get thighOrientation =>
      thighFilter.quaternion;

  Quaternion get shinOrientation =>
      shinFilter.quaternion;

  void reset() {
    thighFilter.reset();
    shinFilter.reset();

    _previousTimestamp = null;
  }

  DualOrientationSample? update({
    required int timestamp,
    required double thighAx,
    required double thighAy,
    required double thighAz,
    required double thighGx,
    required double thighGy,
    required double thighGz,
    required double shinAx,
    required double shinAy,
    required double shinAz,
    required double shinGx,
    required double shinGy,
    required double shinGz,
  }) {
    if (_previousTimestamp == null) {
      _previousTimestamp = timestamp;
      return null;
    }

    final deltaTime =
        (timestamp - _previousTimestamp!) /
            1000.0;

    _previousTimestamp = timestamp;

    if (deltaTime <= 0 ||
        deltaTime > 1.0) {
      return null;
    }

    final thighQuaternion =
        thighFilter.update(
      gx: thighGx,
      gy: thighGy,
      gz: thighGz,
      ax: thighAx,
      ay: thighAy,
      az: thighAz,
      deltaTime: deltaTime,
    );

    final shinQuaternion =
        shinFilter.update(
      gx: shinGx,
      gy: shinGy,
      gz: shinGz,
      ax: shinAx,
      ay: shinAy,
      az: shinAz,
      deltaTime: deltaTime,
    );

    final relativeQuaternion =
        thighQuaternion
            .conjugate()
            .multiply(shinQuaternion)
            .normalized();

    return DualOrientationSample(
      timestamp: timestamp,
      deltaTime: deltaTime,
      thigh: thighQuaternion,
      shin: shinQuaternion,
      relative: relativeQuaternion,
    );
  }
}

class DualOrientationSample {
  final int timestamp;
  final double deltaTime;

  final Quaternion thigh;
  final Quaternion shin;
  final Quaternion relative;

  const DualOrientationSample({
    required this.timestamp,
    required this.deltaTime,
    required this.thigh,
    required this.shin,
    required this.relative,
  });
}