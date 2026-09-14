import 'movement_test_controller.dart';
import 'report_pdf_service.dart';

class ScreeningReportBuilder {
  const ScreeningReportBuilder();

  ScreeningReportData build(
    MovementTestController controller,
  ) {
    final assessment = controller.patientAssessment;
    final screening = controller.screeningResult;

    final chairMetrics = <ReportMetric>[];

    final chairResult = controller.chairStandResult;

    if (chairResult != null) {
      chairMetrics.add(
        ReportMetric(
          label: 'Repetitions',
          value: chairResult.repetitions.toString(),
        ),
      );

      chairMetrics.add(
        ReportMetric(
          label: 'Average Cycle Duration',
          value:
              '${chairResult.averageCycleDuration.toStringAsFixed(2)} s',
        ),
      );
    }

    final fastWalkMetrics = <ReportMetric>[];

    final walkResult = controller.fastWalkResult;

    if (walkResult != null) {
      fastWalkMetrics.add(
        ReportMetric(
          label: 'Walk Duration',
          value:
              '${walkResult.durationSeconds.toStringAsFixed(2)} s',
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Shin Dynamic Acceleration Mean',
          value:
              walkResult.shinDynamicAccelerationMean
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Shin Dynamic Acceleration Std',
          value:
              walkResult.shinDynamicAccelerationStd
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Thigh Dynamic Acceleration Mean',
          value:
              walkResult.thighDynamicAccelerationMean
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Thigh Dynamic Acceleration Std',
          value:
              walkResult.thighDynamicAccelerationStd
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Shin Gyroscope Mean',
          value:
              walkResult.shinGyroscopeMean
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Shin Gyroscope Std',
          value:
              walkResult.shinGyroscopeStd
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Thigh Gyroscope Mean',
          value:
              walkResult.thighGyroscopeMean
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Thigh Gyroscope Std',
          value:
              walkResult.thighGyroscopeStd
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Movement Variability',
          value:
              walkResult.movementVariability
                  .toStringAsFixed(3),
        ),
      );
    }

    final walkCycleResult =
        controller.fastWalkCycleResult;

    if (walkCycleResult != null) {
      fastWalkMetrics.add(
        ReportMetric(
          label: 'Detected Movement Cycles',
          value:
              walkCycleResult.detectedCycles.toString(),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Average Cycle Duration',
          value:
              '${walkCycleResult.averageCycleDuration.toStringAsFixed(2)} s',
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Cycle Duration Std',
          value:
              walkCycleResult.cycleDurationStd
                  .toStringAsFixed(3),
        ),
      );

      fastWalkMetrics.add(
        ReportMetric(
          label: 'Cycle Duration CV',
          value:
              walkCycleResult.cycleDurationCv
                  .toStringAsFixed(3),
        ),
      );
    }

    final kneeMetrics = <ReportMetric>[];

    final kneeFeatures =
        controller.fastWalkKneeFeatures ??
            controller.chairStandKneeFeatures;

    if (kneeFeatures != null) {
      final map = kneeFeatures.toMap();

      final entries = map.entries.toList()
        ..sort(
          (a, b) => a.key.compareTo(b.key),
        );

      for (final entry in entries) {
        kneeMetrics.add(
          ReportMetric(
            label: _prettyFeatureName(entry.key),
            value: _formatNumber(entry.value),
          ),
        );
      }
    }

    final topFactors = <String>[];

    if (screening != null) {
      for (final factor in screening.contributingFactors) {
        topFactors.add(
          _formatContribution(factor),
        );
      }
    }

    return ScreeningReportData(
      generatedAt: DateTime.now(),
      patientId: controller.session?.patientId,

      age: assessment.age,
      sex: assessment.sex,
      heightCm: assessment.heightCm,
      weightKg: assessment.weightKg,
      bmi: assessment.bmi,
      painScore: assessment.painScore,
      stiffnessScore: assessment.stiffnessScore,
      functionalDifficultyScore:
          assessment.functionalDifficultyScore,
      activityRelatedPain:
          assessment.activityRelatedPain,
      morningStiffness:
          assessment.morningStiffness,

      chairStandMetrics: chairMetrics,
      fastWalkMetrics: fastWalkMetrics,
      kneeMetrics: kneeMetrics,

      chairStandQuality:
          _qualityToReport(
        controller.chairStandQuality,
      ),

      fastWalkQuality:
          _qualityToReport(
        controller.fastWalkQuality,
      ),

      screeningAvailable:
          screening?.modelAvailable ?? false,

      riskLabel:
          screening != null
              ? _riskLabel(screening)
              : null,

      riskProbability:
          screening?.probability,

      modelVersion:
          screening?.modelVersion,

      threshold:
          screening?.threshold,

      topFactors: topFactors,

      recommendation:
          screening?.recommendation,

      modelType: 'Logistic Regression',
      modelSchema: 'koa_vs_healthy_v1',
      modelFeatureCount: 27,
    );
  }

  ReportQualityData? _qualityToReport(
    TestQualityResult? quality,
  ) {
    if (quality == null) {
      return null;
    }

    return ReportQualityData(
      score: quality.score,
      label: quality.label,
      sampleCount: quality.sampleCount,
      durationSeconds: quality.durationSeconds,
      samplingRate: quality.samplingRate,
      sampleCoverage: quality.sampleCoverage,
      timestampRegularity:
          quality.timestampRegularity,
      signalQuality: quality.signalQuality,
      movementPresence: quality.movementPresence,
    );
  }

  String _riskLabel(
    dynamic screening,
  ) {
    final value =
        screening.riskLevel.toString();

    final separatorIndex =
        value.lastIndexOf('.');

    if (separatorIndex >= 0 &&
        separatorIndex < value.length - 1) {
      return value.substring(
        separatorIndex + 1,
      );
    }

    return value;
  }

  String _formatContribution(
    dynamic factor,
  ) {
    try {
      final feature = factor.feature.toString();

      final direction =
          factor.increasesRisk == true
              ? 'increases risk estimate'
              : 'decreases risk estimate';

      return '${_prettyFeatureName(feature)} - $direction';
    } catch (_) {
      return factor.toString();
    }
  }

  String _prettyFeatureName(
    String name,
  ) {
    final words = name
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              word[0].toUpperCase() +
              word.substring(1),
        )
        .toList();

    return words.join(' ');
  }

  String _formatNumber(
    double value,
  ) {
    if (!value.isFinite) {
      return 'Not available';
    }

    return value.toStringAsFixed(3);
  }
}