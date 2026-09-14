import 'dart:math';

import '../models/patient_assessment.dart';
import '../models/sensor_sample.dart';
import 'movement_features.dart';

/// Builds the 27-feature vector expected by the
/// koa_vs_healthy_v1 screening model.
///
/// IMPORTANT:
/// The current prototype has two sensor channels:
///   - thigh
///   - shin
///
/// The deployed model schema uses the names:
///   - lf = channel 1
///   - rf = channel 2
///
/// For the current software/demo pipeline we map:
///   lf -> thigh channel
///   rf -> shin channel
///
/// This is a prototype feature mapping. It must be
/// revalidated against the final hardware placement
/// and clinical dataset before clinical deployment.
class KoaFeatureExtractor {
  static const List<String> featureNames = [
    'age',
    'bmi',
    'duration_seconds',
    'lf_acc_mean',
    'lf_acc_std',
    'lf_acc_p95',
    'rf_acc_mean',
    'rf_acc_std',
    'rf_acc_p95',
    'lf_gyr_mean',
    'lf_gyr_std',
    'lf_gyr_p95',
    'rf_gyr_mean',
    'rf_gyr_std',
    'rf_gyr_p95',
    'bilateral_acc_diff_mean',
    'bilateral_acc_diff_std',
    'bilateral_gyr_diff_mean',
    'bilateral_gyr_diff_std',
    'acc_mean',
    'acc_std',
    'acc_cv',
    'gyr_mean',
    'gyr_std',
    'gyr_cv',
    'lf_rf_acc_ratio',
    'lf_rf_gyr_ratio',
  ];

  static MovementFeatureVector extract({
    required List<SensorSample> samples,
    required PatientAssessment patientAssessment,
  }) {
    if (samples.isEmpty) {
      throw StateError(
        'Cannot build AI features from an empty sample set.',
      );
    }

    final thighAcceleration =
        _signalStatistics(
      samples,
      sensor: _SensorPart.thigh,
      signal: _SignalType.acceleration,
    );

    final shinAcceleration =
        _signalStatistics(
      samples,
      sensor: _SensorPart.shin,
      signal: _SignalType.acceleration,
    );

    final thighGyroscope =
        _signalStatistics(
      samples,
      sensor: _SensorPart.thigh,
      signal: _SignalType.gyroscope,
    );

    final shinGyroscope =
        _signalStatistics(
      samples,
      sensor: _SensorPart.shin,
      signal: _SignalType.gyroscope,
    );

    final bilateralAcceleration =
        _bilateralDifferenceStatistics(
      samples,
      signal: _SignalType.acceleration,
    );

    final bilateralGyroscope =
        _bilateralDifferenceStatistics(
      samples,
      signal: _SignalType.gyroscope,
    );

    final allAcceleration =
        _combinedSignalStatistics(
      thighAcceleration.values,
      shinAcceleration.values,
    );

    final allGyroscope =
        _combinedSignalStatistics(
      thighGyroscope.values,
      shinGyroscope.values,
    );

    // Impute dataset population means when patient age or BMI are unspecified
    // (Age mean = 44.38047, BMI mean = 24.56027) so missing demographics
    // provide a neutral Z-score (0.0) rather than an extreme negative outlier.
    final age = (patientAssessment.age != null && patientAssessment.age! > 0)
        ? patientAssessment.age!.toDouble()
        : 44.38047;

    final rawBmi = patientAssessment.bmi;
    final bmi = (rawBmi != null && rawBmi.isFinite && rawBmi > 0)
        ? rawBmi
        : 24.56027;

    final durationSeconds =
        _durationSeconds(samples);

    final values = <String, double>{
      'age': _finiteOrZero(age),
      'bmi': _finiteOrZero(bmi),

      'duration_seconds':
          _finiteOrZero(durationSeconds),

      'lf_acc_mean':
          _finiteOrZero(thighAcceleration.mean),

      'lf_acc_std':
          _finiteOrZero(
        thighAcceleration.standardDeviation,
      ),

      'lf_acc_p95':
          _finiteOrZero(
        _percentile(
          thighAcceleration.values,
          0.95,
        ),
      ),

      'rf_acc_mean':
          _finiteOrZero(shinAcceleration.mean),

      'rf_acc_std':
          _finiteOrZero(
        shinAcceleration.standardDeviation,
      ),

      'rf_acc_p95':
          _finiteOrZero(
        _percentile(
          shinAcceleration.values,
          0.95,
        ),
      ),

      'lf_gyr_mean':
          _finiteOrZero(thighGyroscope.mean),

      'lf_gyr_std':
          _finiteOrZero(
        thighGyroscope.standardDeviation,
      ),

      'lf_gyr_p95':
          _finiteOrZero(
        _percentile(
          thighGyroscope.values,
          0.95,
        ),
      ),

      'rf_gyr_mean':
          _finiteOrZero(shinGyroscope.mean),

      'rf_gyr_std':
          _finiteOrZero(
        shinGyroscope.standardDeviation,
      ),

      'rf_gyr_p95':
          _finiteOrZero(
        _percentile(
          shinGyroscope.values,
          0.95,
        ),
      ),

      'bilateral_acc_diff_mean':
          _finiteOrZero(
        bilateralAcceleration.mean,
      ),

      'bilateral_acc_diff_std':
          _finiteOrZero(
        bilateralAcceleration.standardDeviation,
      ),

      'bilateral_gyr_diff_mean':
          _finiteOrZero(
        bilateralGyroscope.mean,
      ),

      'bilateral_gyr_diff_std':
          _finiteOrZero(
        bilateralGyroscope.standardDeviation,
      ),

      'acc_mean':
          _finiteOrZero(allAcceleration.mean),

      'acc_std':
          _finiteOrZero(
        allAcceleration.standardDeviation,
      ),

      'acc_cv':
          _coefficientOfVariation(
        allAcceleration.mean,
        allAcceleration.standardDeviation,
      ),

      'gyr_mean':
          _finiteOrZero(allGyroscope.mean),

      'gyr_std':
          _finiteOrZero(
        allGyroscope.standardDeviation,
      ),

      'gyr_cv':
          _coefficientOfVariation(
        allGyroscope.mean,
        allGyroscope.standardDeviation,
      ),

      'lf_rf_acc_ratio':
          _safeRatio(
        thighAcceleration.mean,
        shinAcceleration.mean,
      ),

      'lf_rf_gyr_ratio':
          _safeRatio(
        thighGyroscope.mean,
        shinGyroscope.mean,
      ),
    };

    _validate(values);

    return MovementFeatureVector(
      values: values,
    );
  }

  static _Statistics _signalStatistics(
    List<SensorSample> samples, {
    required _SensorPart sensor,
    required _SignalType signal,
  }) {
    final values = <double>[];

    for (final sample in samples) {
      final double magnitude;

      if (sensor == _SensorPart.thigh &&
          signal == _SignalType.acceleration) {
        magnitude = _magnitude(
          sample.thigh.ax,
          sample.thigh.ay,
          sample.thigh.az,
        );
      } else if (sensor == _SensorPart.shin &&
          signal == _SignalType.acceleration) {
        magnitude = _magnitude(
          sample.shin.ax,
          sample.shin.ay,
          sample.shin.az,
        );
      } else if (sensor == _SensorPart.thigh &&
          signal == _SignalType.gyroscope) {
        magnitude = _magnitude(
          sample.thigh.gx,
          sample.thigh.gy,
          sample.thigh.gz,
        );
      } else {
        magnitude = _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        );
      }

      if (magnitude.isFinite) {
        values.add(magnitude);
      }
    }

    return _Statistics(
      values: values,
      mean: _mean(values),
      standardDeviation:
          _standardDeviation(values),
    );
  }

  static _Statistics
      _bilateralDifferenceStatistics(
    List<SensorSample> samples, {
    required _SignalType signal,
  }) {
    final values = <double>[];

    for (final sample in samples) {
      final thighMagnitude =
          signal == _SignalType.acceleration
              ? _magnitude(
                  sample.thigh.ax,
                  sample.thigh.ay,
                  sample.thigh.az,
                )
              : _magnitude(
                  sample.thigh.gx,
                  sample.thigh.gy,
                  sample.thigh.gz,
                );

      final shinMagnitude =
          signal == _SignalType.acceleration
              ? _magnitude(
                  sample.shin.ax,
                  sample.shin.ay,
                  sample.shin.az,
                )
              : _magnitude(
                  sample.shin.gx,
                  sample.shin.gy,
                  sample.shin.gz,
                );

      final difference =
          (thighMagnitude - shinMagnitude).abs();

      if (difference.isFinite) {
        values.add(difference);
      }
    }

    return _Statistics(
      values: values,
      mean: _mean(values),
      standardDeviation:
          _standardDeviation(values),
    );
  }

  static _Statistics _combinedSignalStatistics(
    List<double> first,
    List<double> second,
  ) {
    final values = <double>[
      ...first,
      ...second,
    ];

    return _Statistics(
      values: values,
      mean: _mean(values),
      standardDeviation:
          _standardDeviation(values),
    );
  }

  static double _durationSeconds(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      return 0.0;
    }

    final duration =
        (samples.last.timestamp -
                samples.first.timestamp) /
            1000.0;

    return duration.isFinite && duration >= 0
        ? duration
        : 0.0;
  }

  static double _percentile(
    List<double> values,
    double percentile,
  ) {
    if (values.isEmpty) {
      return 0.0;
    }

    final finiteValues = values
        .where((value) => value.isFinite)
        .toList();

    if (finiteValues.isEmpty) {
      return 0.0;
    }

    finiteValues.sort();

    final position =
        (finiteValues.length - 1) *
            percentile;

    final lower = position.floor();
    final upper = position.ceil();

    if (lower == upper) {
      return finiteValues[lower];
    }

    final fraction =
        position - lower;

    return finiteValues[lower] +
        (finiteValues[upper] -
                finiteValues[lower]) *
            fraction;
  }

  static double _coefficientOfVariation(
    double mean,
    double standardDeviation,
  ) {
    if (!mean.isFinite ||
        !standardDeviation.isFinite ||
        mean.abs() < 1e-9) {
      return 0.0;
    }

    final result =
        standardDeviation / mean.abs();

    return result.isFinite ? result : 0.0;
  }

  static double _safeRatio(
    double numerator,
    double denominator,
  ) {
    if (!numerator.isFinite ||
        !denominator.isFinite ||
        denominator.abs() < 1e-9) {
      return 0.0;
    }

    final ratio =
        numerator / denominator;

    return ratio.isFinite ? ratio : 0.0;
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

    return values.reduce(
          (a, b) => a + b,
        ) /
        values.length;
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
      final difference =
          value - mean;

      sum +=
          difference * difference;
    }

    return sqrt(
      sum / values.length,
    );
  }

  static double _finiteOrZero(
    double value,
  ) {
    return value.isFinite ? value : 0.0;
  }

  static void _validate(
    Map<String, double> values,
  ) {
    if (values.length !=
        featureNames.length) {
      throw StateError(
        'KOA feature vector contains '
        '${values.length} features, but '
        '${featureNames.length} are required.',
      );
    }

    for (final feature in featureNames) {
      final value = values[feature];

      if (value == null ||
          !value.isFinite) {
        throw StateError(
          'Invalid KOA AI feature: $feature',
        );
      }
    }

    for (var i = 0;
        i < featureNames.length;
        i++) {
      if (!values.containsKey(featureNames[i])) {
        throw StateError(
          'Missing KOA AI feature: '
          '${featureNames[i]}',
        );
      }
    }
  }
}

enum _SensorPart {
  thigh,
  shin,
}

enum _SignalType {
  acceleration,
  gyroscope,
}

class _Statistics {
  final List<double> values;
  final double mean;
  final double standardDeviation;

  const _Statistics({
    required this.values,
    required this.mean,
    required this.standardDeviation,
  });
}