import 'dart:math';

import '../models/imu_data.dart';
import '../models/sensor_sample.dart';

/// Stores the stationary calibration values learned from the IMUs.
///
/// Gyroscope bias can be safely estimated from a stationary sensor because
/// the expected angular velocity while stationary is approximately zero.
///
/// Accelerometer values are intentionally stored as a stationary reference
/// rather than blindly subtracted. A stationary accelerometer measures both
/// sensor bias and gravity, so subtracting its raw mean without knowing the
/// sensor mounting orientation could remove useful gravity information.
class ImuCalibration {
  final ImuData thighReference;
  final ImuData shinReference;

  final double thighGxBias;
  final double thighGyBias;
  final double thighGzBias;

  final double shinGxBias;
  final double shinGyBias;
  final double shinGzBias;

  final int sampleCount;

  const ImuCalibration({
    required this.thighReference,
    required this.shinReference,
    required this.thighGxBias,
    required this.thighGyBias,
    required this.thighGzBias,
    required this.shinGxBias,
    required this.shinGyBias,
    required this.shinGzBias,
    required this.sampleCount,
  });

  ImuData correctThigh(ImuData data) {
    return ImuData(
      ax: data.ax,
      ay: data.ay,
      az: data.az,
      gx: data.gx - thighGxBias,
      gy: data.gy - thighGyBias,
      gz: data.gz - thighGzBias,
    );
  }

  ImuData correctShin(ImuData data) {
    return ImuData(
      ax: data.ax,
      ay: data.ay,
      az: data.az,
      gx: data.gx - shinGxBias,
      gy: data.gy - shinGyBias,
      gz: data.gz - shinGzBias,
    );
  }

  SensorSample correctSample(SensorSample sample) {
    return SensorSample(
      timestamp: sample.timestamp,
      thigh: correctThigh(sample.thigh),
      shin: correctShin(sample.shin),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sample_count': sampleCount,
      'thigh_reference': thighReference.toJson(),
      'shin_reference': shinReference.toJson(),
      'thigh_gyro_bias': {
        'gx': thighGxBias,
        'gy': thighGyBias,
        'gz': thighGzBias,
      },
      'shin_gyro_bias': {
        'gx': shinGxBias,
        'gy': shinGyBias,
        'gz': shinGzBias,
      },
    };
  }
}

/// Performs stationary IMU calibration.
///
/// The calibration stage estimates gyroscope zero-offset errors and stores
/// stationary accelerometer references. The accelerometer references are
/// retained for quality checks and future orientation-aware bias correction.
class ImuSignalCalibrator {
  final double stationaryGyroThreshold;

  const ImuSignalCalibrator({
    this.stationaryGyroThreshold = 0.35,
  });

  ImuCalibration calibrate(
    List<SensorSample> samples,
  ) {
    if (samples.length < 10) {
      throw StateError(
        'IMU calibration requires at least 10 samples.',
      );
    }

    final validSamples = samples.where(_looksStationary).toList();

    if (validSamples.length < 10) {
      throw StateError(
        'Not enough stationary IMU samples were detected '
        'for reliable calibration.',
      );
    }

    final thighAx = <double>[];
    final thighAy = <double>[];
    final thighAz = <double>[];

    final shinAx = <double>[];
    final shinAy = <double>[];
    final shinAz = <double>[];

    final thighGx = <double>[];
    final thighGy = <double>[];
    final thighGz = <double>[];

    final shinGx = <double>[];
    final shinGy = <double>[];
    final shinGz = <double>[];

    for (final sample in validSamples) {
      thighAx.add(sample.thigh.ax);
      thighAy.add(sample.thigh.ay);
      thighAz.add(sample.thigh.az);

      thighGx.add(sample.thigh.gx);
      thighGy.add(sample.thigh.gy);
      thighGz.add(sample.thigh.gz);

      shinAx.add(sample.shin.ax);
      shinAy.add(sample.shin.ay);
      shinAz.add(sample.shin.az);

      shinGx.add(sample.shin.gx);
      shinGy.add(sample.shin.gy);
      shinGz.add(sample.shin.gz);
    }

    return ImuCalibration(
      thighReference: ImuData(
        ax: _mean(thighAx),
        ay: _mean(thighAy),
        az: _mean(thighAz),
        gx: _mean(thighGx),
        gy: _mean(thighGy),
        gz: _mean(thighGz),
      ),
      shinReference: ImuData(
        ax: _mean(shinAx),
        ay: _mean(shinAy),
        az: _mean(shinAz),
        gx: _mean(shinGx),
        gy: _mean(shinGz),
        gz: _mean(shinGz),
      ),
      thighGxBias: _mean(thighGx),
      thighGyBias: _mean(thighGy),
      thighGzBias: _mean(thighGz),
      shinGxBias: _mean(shinGx),
      shinGyBias: _mean(shinGy),
      shinGzBias: _mean(shinGz),
      sampleCount: validSamples.length,
    );
  }

  bool _looksStationary(SensorSample sample) {
    final thighGyroMagnitude = _gyroMagnitude(
      sample.thigh,
    );

    final shinGyroMagnitude = _gyroMagnitude(
      sample.shin,
    );

    return thighGyroMagnitude <=
            stationaryGyroThreshold &&
        shinGyroMagnitude <=
            stationaryGyroThreshold;
  }

  static double _gyroMagnitude(ImuData data) {
    return sqrt(
      data.gx * data.gx +
          data.gy * data.gy +
          data.gz * data.gz,
    );
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }

    return values.reduce(
          (double a, double b) => a + b,
        ) /
        values.length;
  }
}

/// Lightweight exponential moving-average filter.
///
/// EMA is computationally inexpensive and suitable for an ESP32/mobile
/// pipeline. The filter is applied independently to each IMU axis.
class ImuEmaFilter {
  final double alpha;

  bool _initialized = false;

  double _ax = 0.0;
  double _ay = 0.0;
  double _az = 0.0;

  double _gx = 0.0;
  double _gy = 0.0;
  double _gz = 0.0;

  ImuEmaFilter({
    this.alpha = 0.25,
  }) {
    if (alpha <= 0.0 || alpha > 1.0) {
      throw ArgumentError(
        'EMA alpha must be greater than 0 and '
        'less than or equal to 1.',
      );
    }
  }

  ImuData process(ImuData data) {
    if (!_initialized) {
      _ax = data.ax;
      _ay = data.ay;
      _az = data.az;

      _gx = data.gx;
      _gy = data.gy;
      _gz = data.gz;

      _initialized = true;
    } else {
      _ax = _update(_ax, data.ax);
      _ay = _update(_ay, data.ay);
      _az = _update(_az, data.az);

      _gx = _update(_gx, data.gx);
      _gy = _update(_gy, data.gy);
      _gz = _update(_gz, data.gz);
    }

    return ImuData(
      ax: _ax,
      ay: _ay,
      az: _az,
      gx: _gx,
      gy: _gy,
      gz: _gz,
    );
  }

  double _update(
    double previous,
    double current,
  ) {
    return alpha * current +
        (1.0 - alpha) * previous;
  }

  void reset() {
    _initialized = false;

    _ax = 0.0;
    _ay = 0.0;
    _az = 0.0;

    _gx = 0.0;
    _gy = 0.0;
    _gz = 0.0;
  }
}

/// Combines calibration and EMA filtering for both IMUs.
///
/// This class is intentionally stateful because EMA filtering depends on the
/// previous sample.
class ImuSignalConditioner {
  final ImuSignalCalibrator calibrator;

  final ImuEmaFilter thighFilter;
  final ImuEmaFilter shinFilter;

  ImuCalibration? _calibration;

  ImuSignalConditioner({
    double emaAlpha = 0.25,
    double stationaryGyroThreshold = 0.35,
  })  : calibrator = ImuSignalCalibrator(
          stationaryGyroThreshold:
              stationaryGyroThreshold,
        ),
        thighFilter = ImuEmaFilter(
          alpha: emaAlpha,
        ),
        shinFilter = ImuEmaFilter(
          alpha: emaAlpha,
        );

  bool get isCalibrated =>
      _calibration != null;

  ImuCalibration? get calibration =>
      _calibration;

  void calibrate(List<SensorSample> samples) {
    _calibration =
        calibrator.calibrate(samples);

    thighFilter.reset();
    shinFilter.reset();
  }

  SensorSample process(
    SensorSample sample,
  ) {
    final calibration = _calibration;

    if (calibration == null) {
      throw StateError(
        'IMU signal conditioner must be calibrated '
        'before processing samples.',
      );
    }

    final correctedThigh =
        calibration.correctThigh(
      sample.thigh,
    );

    final correctedShin =
        calibration.correctShin(
      sample.shin,
    );

    final filteredThigh =
        thighFilter.process(
      correctedThigh,
    );

    final filteredShin =
        shinFilter.process(
      correctedShin,
    );

    return SensorSample(
      timestamp: sample.timestamp,
      thigh: filteredThigh,
      shin: filteredShin,
    );
  }

  void reset() {
    _calibration = null;

    thighFilter.reset();
    shinFilter.reset();
  }
}
