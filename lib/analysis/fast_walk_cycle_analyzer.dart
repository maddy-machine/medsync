import 'dart:math';

import '../models/sensor_sample.dart';

class FastWalkCycleResult {
  final int detectedCycles;
  final List<double> cycleDurations;
  final double averageCycleDuration;
  final double cycleDurationStd;
  final double cycleDurationCv;

  const FastWalkCycleResult({
    required this.detectedCycles,
    required this.cycleDurations,
    required this.averageCycleDuration,
    required this.cycleDurationStd,
    required this.cycleDurationCv,
  });

  Map<String, double> toMap() {
    return {
      'walk_detected_cycles':
          detectedCycles.toDouble(),
      'walk_avg_cycle_duration':
          averageCycleDuration,
      'walk_cycle_duration_std':
          cycleDurationStd,
      'walk_cycle_duration_cv':
          cycleDurationCv,
    };
  }

  static FastWalkCycleResult analyze(
    List<SensorSample> samples,
  ) {
    if (samples.length < 30) {
      return const FastWalkCycleResult(
        detectedCycles: 0,
        cycleDurations: [],
        averageCycleDuration: 0,
        cycleDurationStd: 0,
        cycleDurationCv: 0,
      );
    }

    final signal = samples.map(
      (sample) {
        return _magnitude(
          sample.shin.gx,
          sample.shin.gy,
          sample.shin.gz,
        );
      },
    ).toList();

    final smoothed = _movingAverage(
      signal,
      11,
    );

    final threshold =
        _calculateThreshold(smoothed);

    final peaks = _findPeaks(
      smoothed,
      threshold,
    );

    final cycleDurations =
        <double>[];

    for (int i = 1;
        i < peaks.length;
        i++) {
      final previous =
          samples[peaks[i - 1]]
              .timestamp;

      final current =
          samples[peaks[i]]
              .timestamp;

      final duration =
          (current - previous) /
              1000.0;

      // Typical walking cycle/step
      // intervals should not be treated
      // as extremely short or extremely long.
      if (duration >= 0.25 &&
          duration <= 3.0) {
        cycleDurations.add(duration);
      }
    }

    final average =
        _mean(cycleDurations);

    final standardDeviation =
        _standardDeviation(
      cycleDurations,
    );

    final coefficientOfVariation =
        average > 0
            ? standardDeviation /
                average
            : 0.0;

    return FastWalkCycleResult(
      detectedCycles: peaks.length,
      cycleDurations:
          cycleDurations,
      averageCycleDuration:
          average,
      cycleDurationStd:
          standardDeviation,
      cycleDurationCv:
          coefficientOfVariation,
    );
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

  static List<double> _movingAverage(
    List<double> values,
    int windowSize,
  ) {
    if (values.isEmpty) {
      return [];
    }

    final result =
        <double>[];

    for (int i = 0;
        i < values.length;
        i++) {
      final start =
          max(
        0,
        i - windowSize + 1,
      );

      double sum = 0;

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

  static double _calculateThreshold(
    List<double> signal,
  ) {
    if (signal.isEmpty) {
      return 0;
    }

    final mean =
        _mean(signal);

    final standardDeviation =
        _standardDeviation(signal);

    return mean +
        standardDeviation * 0.35;
  }

  static List<int> _findPeaks(
    List<double> signal,
    double threshold,
  ) {
    final peaks = <int>[];

    if (signal.length < 3) {
      return peaks;
    }

    // At 100 Hz this corresponds to
    // approximately 0.4 seconds.
    const minimumDistance =
        40;

    int? lastPeak;

    for (int i = 1;
        i < signal.length - 1;
        i++) {
      final isPeak =
          signal[i] >
                  signal[i - 1] &&
              signal[i] >=
                  signal[i + 1] &&
              signal[i] >= threshold;

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

      final lastIndex =
          peaks.length - 1;

      if (signal[i] >
          signal[peaks[lastIndex]]) {
        peaks[lastIndex] = i;
        lastPeak = i;
      }
    }

    return peaks;
  }

  static double _mean(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return 0;
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
      return 0;
    }

    final mean =
        _mean(values);

    double sum = 0;

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