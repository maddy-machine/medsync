import 'dart:math' as math;

import '../models/sensor_sample.dart';

class TestQualityResult {
  final int score;
  final bool isGood;
  final String label;
  final List<String> checks;
  final List<String> issues;

  const TestQualityResult({
    required this.score,
    required this.isGood,
    required this.label,
    required this.checks,
    required this.issues,
  });

  bool get isExcellent => score >= 85;

  bool get needsReview => score < 60;
}

class TestQualityService {
  // ESP32 firmware sends at ~50 Hz (20 ms per packet).
  static const double expectedSamplingRate = 50.0;

  const TestQualityService();

  TestQualityResult evaluate({
    required List<SensorSample> samples,
    required double durationSeconds,
  }) {
    if (samples.isEmpty) {
      return const TestQualityResult(
        score: 0,
        isGood: false,
        label: 'Insufficient data',
        checks: [],
        issues: [
          'No sensor samples were captured.',
        ],
      );
    }

    final checks = <String>[];
    final issues = <String>[];

    var score = 100;

    // ------------------------------------------------------------
    // 1. Sample completeness
    // ------------------------------------------------------------

    final expectedSamples =
        math.max(
          1,
          (durationSeconds *
                  expectedSamplingRate)
              .round(),
        );

    final sampleCoverage =
        samples.length /
            expectedSamples;

    if (sampleCoverage >= 0.90) {
      checks.add(
        'Sample coverage is sufficient.',
      );
    } else if (sampleCoverage >= 0.70) {
      score -= 15;

      checks.add(
        'Most expected samples were captured.',
      );

      issues.add(
        'Some sensor samples may be missing.',
      );
    } else {
      score -= 30;

      issues.add(
        'A substantial portion of expected '
        'sensor samples is missing.',
      );
    }

    // ------------------------------------------------------------
    // 2. Duration
    // ------------------------------------------------------------

    if (durationSeconds >= 5.0) {
      checks.add(
        'Recording duration is sufficient '
        'for movement analysis.',
      );
    } else {
      score -= 30;

      issues.add(
        'Recording duration is too short '
        'for reliable movement analysis.',
      );
    }

    // ------------------------------------------------------------
    // 3. Sensor validity
    // ------------------------------------------------------------

    var invalidSamples = 0;

    for (final sample in samples) {
      if (!_isFiniteSample(sample)) {
        invalidSamples++;
      }
    }

    final invalidRatio =
        invalidSamples /
            samples.length;

    if (invalidSamples == 0) {
      checks.add(
        'All captured sensor values are valid.',
      );
    } else if (invalidRatio <= 0.02) {
      score -= 10;

      checks.add(
        'Most sensor values are valid.',
      );

      issues.add(
        'A small number of invalid sensor '
        'samples were detected.',
      );
    } else {
      score -= 25;

      issues.add(
        'Too many invalid sensor samples '
        'were detected.',
      );
    }

    // ------------------------------------------------------------
    // 4. Timestamp consistency
    // ------------------------------------------------------------

    var timestampProblems = 0;

    for (var i = 1;
        i < samples.length;
        i++) {
      if (samples[i].timestamp <=
          samples[i - 1].timestamp) {
        timestampProblems++;
      }
    }

    if (timestampProblems == 0) {
      checks.add(
        'Sensor timestamps are sequential.',
      );
    } else {
      score -= 15;

      issues.add(
        'Some sensor timestamps are not '
        'sequential.',
      );
    }

    // ------------------------------------------------------------
    // 5. Movement presence
    // ------------------------------------------------------------

    final movementStrength =
        _movementStrength(samples);

    if (movementStrength >= 0.05) {
      checks.add(
        'Meaningful movement was detected.',
      );
    } else {
      score -= 20;

      issues.add(
        'Very little movement was detected '
        'in the recording.',
      );
    }

    // ------------------------------------------------------------
    // Final score
    // ------------------------------------------------------------

    score = score.clamp(0, 100);

    final label = _labelForScore(score);

    final isGood = score >= 70;

    if (issues.isEmpty) {
      checks.add(
        'Recording is suitable for the '
        'current movement-analysis pipeline.',
      );
    }

    return TestQualityResult(
      score: score,
      isGood: isGood,
      label: label,
      checks: checks,
      issues: issues,
    );
  }

  bool _isFiniteSample(
    SensorSample sample,
  ) {
    final thigh = sample.thigh;
    final shin = sample.shin;

    return thigh.ax.isFinite &&
        thigh.ay.isFinite &&
        thigh.az.isFinite &&
        thigh.gx.isFinite &&
        thigh.gy.isFinite &&
        thigh.gz.isFinite &&
        shin.ax.isFinite &&
        shin.ay.isFinite &&
        shin.az.isFinite &&
        shin.gx.isFinite &&
        shin.gy.isFinite &&
        shin.gz.isFinite;
  }

  double _movementStrength(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      return 0.0;
    }

    double total = 0.0;
    var count = 0;

    for (final sample in samples) {
      if (!_isFiniteSample(sample)) {
        continue;
      }

      final thighGyro =
          _magnitude(
        sample.thigh.gx,
        sample.thigh.gy,
        sample.thigh.gz,
      );

      final shinGyro =
          _magnitude(
        sample.shin.gx,
        sample.shin.gy,
        sample.shin.gz,
      );

      final movement =
          (thighGyro + shinGyro) /
              2.0;

      if (movement.isFinite) {
        total += movement;
        count++;
      }
    }

    if (count == 0) {
      return 0.0;
    }

    return total / count;
  }

  double _magnitude(
    double x,
    double y,
    double z,
  ) {
    return math.sqrt(
      x * x +
          y * y +
          z * z,
    );
  }

  String _labelForScore(
    int score,
  ) {
    if (score >= 85) {
      return 'Excellent quality';
    }

    if (score >= 70) {
      return 'Good quality';
    }

    if (score >= 60) {
      return 'Fair quality';
    }

    return 'Needs review';
  }
}