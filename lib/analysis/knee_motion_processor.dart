import 'dart:math';

import '../models/sensor_sample.dart';
import 'dual_imu_orientation.dart';
import 'knee_angle_estimator.dart';
import 'knee_angle_features.dart';

class KneeMotionProcessor {
  final DualImuOrientation orientationProcessor;
  final KneeAngleEstimator angleEstimator;

  final List<double> angles = [];
  final List<double> timestamps = [];

  final List<double> angularVelocities = [];
  final List<double> angularAccelerations = [];

  final List<double> cycleAngleRanges = [];
  final List<double> cycleVelocityMeans = [];

  bool _isCalibrated = false;

  double? _previousAngle;
  double? _previousAngularVelocity;

  KneeMotionProcessor({
    double beta = 0.1,
    FlexionAxis flexionAxis = FlexionAxis.y,
  })  : orientationProcessor =
            DualImuOrientation(
          beta: beta,
        ),
        angleEstimator =
            KneeAngleEstimator(
          flexionAxis: flexionAxis,
        );

  bool get isCalibrated =>
      _isCalibrated;

  void reset() {
    orientationProcessor.reset();

    angles.clear();
    timestamps.clear();

    angularVelocities.clear();
    angularAccelerations.clear();

    cycleAngleRanges.clear();
    cycleVelocityMeans.clear();

    angleEstimator.resetNeutral();

    _previousAngle = null;
    _previousAngularVelocity = null;

    _isCalibrated = false;
  }

  double? processSample(
    SensorSample sample,
  ) {
    final orientation =
        orientationProcessor.update(
      timestamp: sample.timestamp,

      thighAx: sample.thigh.ax,
      thighAy: sample.thigh.ay,
      thighAz: sample.thigh.az,

      thighGx: sample.thigh.gx,
      thighGy: sample.thigh.gy,
      thighGz: sample.thigh.gz,

      shinAx: sample.shin.ax,
      shinAy: sample.shin.ay,
      shinAz: sample.shin.az,

      shinGx: sample.shin.gx,
      shinGy: sample.shin.gy,
      shinGz: sample.shin.gz,
    );

    if (orientation == null) {
      return null;
    }

    if (!_isCalibrated) {
      angleEstimator.calibrateNeutral(
        orientation.relative,
      );

      _isCalibrated = true;

      _previousAngle = null;
      _previousAngularVelocity = null;

      return 0.0;
    }

    final kneeAngle =
        angleEstimator.estimate(
      orientation.relative,
    );

    final timestampSeconds =
        sample.timestamp / 1000.0;

    angles.add(kneeAngle);
    timestamps.add(timestampSeconds);

    _updateAngularMotion(
      kneeAngle,
      timestampSeconds,
    );

    return kneeAngle;
  }

  void _updateAngularMotion(
    double currentAngle,
    double currentTimestamp,
  ) {
    if (_previousAngle == null) {
      _previousAngle = currentAngle;
      return;
    }

    final previousTimestamp =
        timestamps.length >= 2
            ? timestamps[
                timestamps.length - 2
              ]
            : null;

    if (previousTimestamp == null) {
      _previousAngle = currentAngle;
      return;
    }

    final deltaTime =
        currentTimestamp -
        previousTimestamp;

    if (deltaTime <= 0) {
      return;
    }

    final angularVelocity =
        (currentAngle -
                _previousAngle!) /
            deltaTime;

    if (!angularVelocity.isFinite) {
      return;
    }

    angularVelocities.add(
      angularVelocity,
    );

    if (_previousAngularVelocity != null) {
      final acceleration =
          (angularVelocity -
                  _previousAngularVelocity!) /
              deltaTime;

      if (acceleration.isFinite) {
        angularAccelerations.add(
          acceleration,
        );
      }
    }

    _previousAngle = currentAngle;
    _previousAngularVelocity =
        angularVelocity;
  }

  void calibrateNeutral() {
    final relative =
        orientationProcessor
            .thighOrientation
            .conjugate()
            .multiply(
              orientationProcessor
                  .shinOrientation,
            )
            .normalized();

    angleEstimator.calibrateNeutral(
      relative,
    );

    _isCalibrated = true;

    _previousAngle = null;
    _previousAngularVelocity = null;
  }

  KneeAngleFeatures calculateFeatures() {
    _calculateCycleFeatures();

    return KneeAngleFeatures.calculate(
      angles: angles,
      timestamps: timestamps,
      angularVelocities:
          angularVelocities,
      angularAccelerations:
          angularAccelerations,
      cycleAngleRanges:
          cycleAngleRanges,
      cycleVelocityMeans:
          cycleVelocityMeans,
    );
  }

  void _calculateCycleFeatures() {
    cycleAngleRanges.clear();
    cycleVelocityMeans.clear();

    if (angles.length < 5 ||
        timestamps.length != angles.length) {
      return;
    }

    final peaks =
        _findMovementPeaks();

    if (peaks.length < 2) {
      return;
    }

    for (int i = 1;
        i < peaks.length;
        i++) {
      final start =
          peaks[i - 1];

      final end =
          peaks[i];

      if (end <= start ||
          end >= angles.length) {
        continue;
      }

      final cycleAngles =
          angles.sublist(
        start,
        end + 1,
      );

      if (cycleAngles.length < 2) {
        continue;
      }

      final minimum =
          cycleAngles.reduce(min);

      final maximum =
          cycleAngles.reduce(max);

      cycleAngleRanges.add(
        maximum - minimum,
      );

      final velocityStart =
          max(
        0,
        start - 1,
      );

      final velocityEnd =
          min(
        angularVelocities.length,
        end,
      );

      if (velocityEnd >
          velocityStart) {
        final cycleVelocities =
            angularVelocities.sublist(
          velocityStart,
          velocityEnd,
        );

        if (cycleVelocities.isNotEmpty) {
          cycleVelocityMeans.add(
            _mean(
              cycleVelocities
                  .map(
                    (value) =>
                        value.abs(),
                  )
                  .toList(),
            ),
          );
        }
      }
    }
  }

  List<int> _findMovementPeaks() {
    if (angles.length < 3) {
      return [];
    }

    final smoothed =
        _movingAverage(
      angles,
      9,
    );

    final mean =
        _mean(smoothed);

    final standardDeviation =
        _standardDeviation(
      smoothed,
    );

    final threshold =
        mean +
        standardDeviation * 0.20;

    final peaks = <int>[];

    const minimumDistance = 30;

    int? lastPeak;

    for (int i = 1;
        i < smoothed.length - 1;
        i++) {
      final isPeak =
          smoothed[i] >
                  smoothed[i - 1] &&
              smoothed[i] >=
                  smoothed[i + 1] &&
              smoothed[i] >=
                  threshold;

      if (!isPeak) {
        continue;
      }

      if (lastPeak == null ||
          i - lastPeak >=
              minimumDistance) {
        peaks.add(i);
        lastPeak = i;
        continue;
      }

      final previousPeak =
          peaks.last;

      if (smoothed[i] >
          smoothed[previousPeak]) {
        peaks[
          peaks.length - 1
        ] = i;

        lastPeak = i;
      }
    }

    return peaks;
  }

  static List<double> _movingAverage(
    List<double> values,
    int windowSize,
  ) {
    if (values.isEmpty) {
      return [];
    }

    final result = <double>[];

    for (int i = 0;
        i < values.length;
        i++) {
      final start =
          max(
        0,
        i - windowSize + 1,
      );

      double sum = 0.0;

      for (int j = start;
          j <= i;
          j++) {
        sum += values[j];
      }

      result.add(
        sum /
        (i - start + 1),
      );
    }

    return result;
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