import 'dart:math';

import '../models/sensor_sample.dart';

class ChairStandResult {
  final int repetitions;
  final List<double> cycleDurations;
  final double averageCycleDuration;
  final double movementAmplitude;

  const ChairStandResult({
    required this.repetitions,
    required this.cycleDurations,
    required this.averageCycleDuration,
    required this.movementAmplitude,
  });
}

class ChairStandAnalyzer {
  static ChairStandResult analyze(
    List<SensorSample> samples,
  ) {
    if (samples.length < 20) {
      return const ChairStandResult(
        repetitions: 0,
        cycleDurations: [],
        averageCycleDuration: 0,
        movementAmplitude: 0,
      );
    }

    final signal = samples.map((sample) {
      final double gx = sample.shin.gx;
      final double gy = sample.shin.gy;
      final double gz = sample.shin.gz;

      return sqrt(
        gx * gx +
            gy * gy +
            gz * gz,
      );
    }).toList();

    final smoothed = _movingAverage(
      signal,
      windowSize: 15,
    );

    final amplitude =
        _calculateAmplitude(smoothed);

    if (amplitude <= 0) {
      return const ChairStandResult(
        repetitions: 0,
        cycleDurations: [],
        averageCycleDuration: 0,
        movementAmplitude: 0,
      );
    }

    final threshold = amplitude * 0.35;

    final peaks = _findPeaks(
      smoothed,
      threshold,
    );

    final cycleDurations = <double>[];

    for (int i = 1; i < peaks.length; i++) {
      final previousIndex = peaks[i - 1];
      final currentIndex = peaks[i];

      final duration =
          (samples[currentIndex].timestamp -
                  samples[previousIndex].timestamp) /
              1000.0;

      if (duration >= 0.8 &&
          duration <= 10.0) {
        cycleDurations.add(duration);
      }
    }

    final averageCycleDuration =
    cycleDurations.isEmpty
        ? 0.0
        : cycleDurations.reduce(
              (double a, double b) => a + b,
            ) /
            cycleDurations.length;

return ChairStandResult(
  repetitions: peaks.length,
  cycleDurations:
      cycleDurations,
  averageCycleDuration:
      averageCycleDuration,
  movementAmplitude:
      amplitude,
);

  }

  static List<double> _movingAverage(
    List<double> values, {
    required int windowSize,
  }) {
    if (values.isEmpty) {
      return [];
    }

    final result = <double>[];

    for (int i = 0; i < values.length; i++) {
      final start =
          max(0, i - windowSize + 1);

      double sum = 0.0;

      for (int j = start; j <= i; j++) {
        sum += values[j];
      }

      result.add(
        sum / (i - start + 1),
      );
    }

    return result;
  }

  static double _calculateAmplitude(
    List<double> signal,
  ) {
    if (signal.isEmpty) {
      return 0.0;
    }

    double minimum = signal.first;
    double maximum = signal.first;

    for (final value in signal) {
      if (value < minimum) {
        minimum = value;
      }

      if (value > maximum) {
        maximum = value;
      }
    }

    return maximum - minimum;
  }

  static List<int> _findPeaks(
    List<double> signal,
    double threshold,
  ) {
    final peaks = <int>[];

    if (signal.length < 3) {
      return peaks;
    }

    const int minimumDistance = 80;

    int? lastPeak;

    for (int i = 1; i < signal.length - 1; i++) {
      final isPeak =
          signal[i] > signal[i - 1] &&
          signal[i] >= signal[i + 1] &&
          signal[i] >= threshold;

      if (!isPeak) {
        continue;
      }

      if (lastPeak == null ||
          i - lastPeak >= minimumDistance) {
        peaks.add(i);
        lastPeak = i;
      } else {
        final int lastPeakIndex =
            peaks.length - 1;

        if (signal[i] >
            signal[peaks[lastPeakIndex]]) {
          peaks[lastPeakIndex] = i;
          lastPeak = i;
        }
      }
    }

    return peaks;
  }
}