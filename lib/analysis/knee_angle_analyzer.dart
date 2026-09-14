import 'dart:math';

import '../models/sensor_sample.dart';
import 'madgwick_filter.dart';
import 'quaternion.dart';

enum KneeFlexionAxis {
  x,
  y,
  z,
}

class KneeAngleSample {
  final int timestamp;
  final double angleDegrees;

  const KneeAngleSample({
    required this.timestamp,
    required this.angleDegrees,
  });
}

class KneeAngleAnalysis {
  final List<KneeAngleSample> samples;
  final double rangeOfMotionDegrees;
  final double minimumAngleDegrees;
  final double maximumAngleDegrees;
  final double meanAngleDegrees;
  final double angularVelocityMean;
  final double angularVelocityStd;

  const KneeAngleAnalysis({
    required this.samples,
    required this.rangeOfMotionDegrees,
    required this.minimumAngleDegrees,
    required this.maximumAngleDegrees,
    required this.meanAngleDegrees,
    required this.angularVelocityMean,
    required this.angularVelocityStd,
  });
}

class KneeAngleAnalyzer {
  final KneeFlexionAxis flexionAxis;

  final double beta;

  KneeAngleAnalyzer({
    this.flexionAxis = KneeFlexionAxis.y,
    this.beta = 0.08,
  });

  KneeAngleAnalysis analyze(
    List<SensorSample> input,
  ) {
    if (input.length < 2) {
      return const KneeAngleAnalysis(
        samples: [],
        rangeOfMotionDegrees: 0,
        minimumAngleDegrees: 0,
        maximumAngleDegrees: 0,
        meanAngleDegrees: 0,
        angularVelocityMean: 0,
        angularVelocityStd: 0,
      );
    }

    final thighFilter =
        MadgwickFilter(beta: beta);

    final shinFilter =
        MadgwickFilter(beta: beta);

    final angleSamples =
        <KneeAngleSample>[];

    var previousTimestamp =
        input.first.timestamp;

    for (final sample in input) {
      final dtMilliseconds =
          sample.timestamp -
          previousTimestamp;

      final dt =
          dtMilliseconds > 0
              ? dtMilliseconds / 1000.0
              : 0.01;

      previousTimestamp =
          sample.timestamp;

      final thighOrientation =
          thighFilter.update(
        gx: sample.thigh.gx,
        gy: sample.thigh.gy,
        gz: sample.thigh.gz,
        ax: sample.thigh.ax,
        ay: sample.thigh.ay,
        az: sample.thigh.az,
        dt: dt,
      );

      final shinOrientation =
          shinFilter.update(
        gx: sample.shin.gx,
        gy: sample.shin.gy,
        gz: sample.shin.gz,
        ax: sample.shin.ax,
        ay: sample.shin.ay,
        az: sample.shin.az,
        dt: dt,
      );

      final relative =
          thighOrientation.inverse() *
          shinOrientation;

      final angle =
          _extractFlexionAngle(relative);

      angleSamples.add(
        KneeAngleSample(
          timestamp: sample.timestamp,
          angleDegrees:
              angle * 180.0 / pi,
        ),
      );
    }

    final angles =
        angleSamples
            .map((sample) =>
                sample.angleDegrees)
            .toList();

    final minimum =
        angles.reduce(min);

    final maximum =
        angles.reduce(max);

    final mean =
        angles.reduce(
              (a, b) => a + b,
            ) /
            angles.length;

    final angularVelocity =
        <double>[];

    for (int i = 1;
        i < angleSamples.length;
        i++) {
      final current =
          angleSamples[i];

      final previous =
          angleSamples[i - 1];

      final dt =
          (current.timestamp -
                  previous.timestamp) /
              1000.0;

      if (dt > 0) {
        angularVelocity.add(
          (current.angleDegrees -
                  previous.angleDegrees) /
              dt,
        );
      }
    }

    final velocityMean =
        angularVelocity.isEmpty
            ? 0.0
            : angularVelocity.reduce(
                  (a, b) => a + b,
                ) /
                angularVelocity.length;

    final velocityStd =
        _standardDeviation(
      angularVelocity,
    );

    return KneeAngleAnalysis(
      samples: angleSamples,
      rangeOfMotionDegrees:
          maximum - minimum,
      minimumAngleDegrees: minimum,
      maximumAngleDegrees: maximum,
      meanAngleDegrees: mean,
      angularVelocityMean: velocityMean,
      angularVelocityStd: velocityStd,
    );
  }

  double _extractFlexionAngle(
    Quaternion relative,
  ) {
    final q = relative.normalized();

    switch (flexionAxis) {
      case KneeFlexionAxis.x:
        final value =
            2 *
            (q.w * q.x +
                q.y * q.z);

        final cosine =
            1 -
            2 *
                (q.x * q.x +
                    q.y * q.y);

        return atan2(
          value,
          cosine,
        );

      case KneeFlexionAxis.y:
        final value =
            2 *
            (q.w * q.y -
                q.z * q.x);

        final clamped =
            value.clamp(-1.0, 1.0);

        return asin(clamped);

      case KneeFlexionAxis.z:
        final value =
            2 *
            (q.w * q.z +
                q.x * q.y);

        final cosine =
            1 -
            2 *
                (q.y * q.y +
                    q.z * q.z);

        return atan2(
          value,
          cosine,
        );
    }
  }

  double _standardDeviation(
    List<double> values,
  ) {
    if (values.length < 2) {
      return 0.0;
    }

    final mean =
        values.reduce(
              (a, b) => a + b,
            ) /
            values.length;

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
