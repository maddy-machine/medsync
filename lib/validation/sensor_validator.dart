import 'package:flutter/foundation.dart';
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
    double expectedSamplingRate = 50,
  }) {
    final issues = <String>[];

    // Check 1: Must have samples
    if (samples.isEmpty) {
      return const ValidationResult(
        isValid: false,
        issues: ['No sensor samples received during recording.'],
      );
    }

    // Check 2: Minimum sample count threshold
    if (samples.length < 5) {
      issues.add('Too few sensor samples recorded (minimum 5 required).');
    }

    // Check 3: Finite double values for thigh & shin IMUs
    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];

      if (!_isValidImu(sample.thigh)) {
        issues.add('Corrupted thigh sensor data at sample $i.');
        break;
      }

      if (!_isValidImu(sample.shin)) {
        issues.add('Corrupted shin sensor data at sample $i.');
        break;
      }
    }

    // Check 4: Non-decreasing timestamps (allow equal timestamps from BLE packet bursts)
    for (int i = 1; i < samples.length; i++) {
      if (samples[i].timestamp < samples[i - 1].timestamp) {
        issues.add('Sensor timestamps are corrupted (time went backward).');
        break;
      }
    }

    // Check 5: Sampling rate validation with wide tolerance (5 Hz to 200 Hz)
    if (samples.length >= 2) {
      final rawDiff = samples.last.timestamp - samples.first.timestamp;

      // Auto-detect unit: if timestamps are in seconds vs milliseconds vs microseconds
      double durationSeconds;
      if (rawDiff > 1000000) {
        durationSeconds = rawDiff / 1000000.0; // microseconds
      } else if (rawDiff > 50) {
        durationSeconds = rawDiff / 1000.0; // milliseconds
      } else {
        durationSeconds = rawDiff.toDouble(); // seconds
      }

      if (durationSeconds <= 0) {
        issues.add('Invalid recording duration (duration <= 0).');
      } else {
        final actualRate = (samples.length - 1) / durationSeconds;

        debugPrint('[MedSync-Validator] Samples: ${samples.length}, Duration: ${durationSeconds.toStringAsFixed(2)}s, Actual Rate: ${actualRate.toStringAsFixed(1)} Hz');

        // Accept any reasonable IMU sampling rate between 5 Hz and 250 Hz
        if (actualRate < 5.0 || actualRate > 250.0) {
          issues.add(
            'Sampling rate (${actualRate.toStringAsFixed(1)} Hz) is outside acceptable bounds (5 - 250 Hz).',
          );
        }
      }
    }

    if (issues.isNotEmpty) {
      debugPrint('[MedSync-Validator] ❌ Validation FAILED with ${issues.length} issue(s):');
      for (final issue in issues) {
        debugPrint('[MedSync-Validator]   - $issue');
      }
    } else {
      debugPrint('[MedSync-Validator] ✅ Validation PASSED (${samples.length} samples).');
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  static bool _isValidImu(dynamic imu) {
    if (imu == null) return false;
    final values = [
      imu.ax,
      imu.ay,
      imu.az,
      imu.gx,
      imu.gy,
      imu.gz,
    ];

    return values.every(
      (value) => value is num && value.toDouble().isFinite,
    );
  }
}