import '../models/sensor_sample.dart';

class ValidationResult {
  final bool isValid;
  final List<String> issues;

  const ValidationResult({
    required this.isValid,
    required this.issues,
  });
}

class SensorValidator {
  static ValidationResult validate(
    List<SensorSample> samples, {
    // ESP32 firmware sends at ~50 Hz (20 ms per packet).
    // Adjust this if the firmware rate changes.
    double expectedSamplingRate = 50,
  }) {
    final issues = <String>[];

    if (samples.isEmpty) {
      return const ValidationResult(
        isValid: false,
        issues: ['No sensor samples received.'],
      );
    }

    if (samples.length < 10) {
      issues.add('Too few samples received.');
    }

    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];

      if (!_isValidImu(sample.thigh)) {
        issues.add(
          'Invalid thigh sensor data at sample $i.',
        );
        break;
      }

      if (!_isValidImu(sample.shin)) {
        issues.add(
          'Invalid shin sensor data at sample $i.',
        );
        break;
      }
    }

    for (int i = 1; i < samples.length; i++) {
      if (samples[i].timestamp <=
          samples[i - 1].timestamp) {
        issues.add(
          'Sensor timestamps are not strictly increasing.',
        );
        break;
      }
    }

    if (samples.length >= 2) {
      final duration =
          (samples.last.timestamp -
                  samples.first.timestamp) /
              1000.0;

      if (duration <= 0) {
        issues.add(
          'Invalid recording duration.',
        );
      } else {
        final actualRate =
            (samples.length - 1) / duration;

        final difference =
            (actualRate - expectedSamplingRate).abs();

        // Allow ±35% tolerance to handle ESP32 timer jitter
        // and BLE transmission delays.
        if (difference > expectedSamplingRate * 0.35) {
          issues.add(
            'Sampling rate is outside the expected range.',
          );
        }
      }
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  static bool _isValidImu(dynamic imu) {
    final values = [
      imu.ax,
      imu.ay,
      imu.az,
      imu.gx,
      imu.gy,
      imu.gz,
    ];

    return values.every(
      (value) =>
          value is double &&
          value.isFinite,
    );
  }
}