import '../analysis/movement_features.dart';
import '../models/screening_model.dart';
import '../models/screening_result.dart';

class ScreeningInferenceService {
  static const String expectedModelType =
      'logistic_regression';

  static const String expectedFeatureSchema =
      'koa_vs_healthy_v1';

  static const String unavailableModelVersion =
      'NOT_CONNECTED';

  static const List<String> expectedFeatures = [
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

  final ScreeningModel? model;

  const ScreeningInferenceService({
    this.model,
  });

  bool get isModelAvailable => model != null;

  ScreeningResult evaluate(
    MovementFeatureVector features,
  ) {
    _validateFeatureVector(features);

    final activeModel = model;

    if (activeModel == null) {
      return const ScreeningResult(
        riskLevel: ScreeningRiskLevel.unavailable,
        probability: null,
        threshold: null,
        modelAvailable: false,
        modelVersion: unavailableModelVersion,
        contributingFactors: [],
        explanation:
            'A compatible trained OA screening '
            'model is not connected.',
        recommendation:
            'Complete clinical evaluation is '
            'recommended when AI screening '
            'is unavailable.',
      );
    }

    _validateModel(activeModel);

    final probability =
        activeModel.predictProbability(
      features.values,
    );

    final contributions =
        activeModel.explain(
      features.values,
    );

    final riskLevel =
        probability >= activeModel.screeningThreshold
            ? ScreeningRiskLevel.higher
            : ScreeningRiskLevel.lower;

    final contributingFactors =
        contributions
            .take(5)
            .map(
              (contribution) =>
                  _formatContribution(
                contribution,
              ),
            )
            .toList();

    final riskText =
        riskLevel == ScreeningRiskLevel.higher
            ? 'The movement and patient-context '
                'features produced an OA-associated '
                'risk estimate above the screening '
                'threshold.'
            : 'The movement and patient-context '
                'features produced an OA-associated '
                'risk estimate below the screening '
                'threshold.';

    return ScreeningResult(
      riskLevel: riskLevel,
      probability: probability,
      threshold:
          activeModel.screeningThreshold,
      modelAvailable: true,
      modelVersion:
          activeModel.modelVersion,
      contributingFactors:
          contributingFactors,
      explanation: riskText,
      recommendation:
          'This is an AI-assisted preliminary '
          'screening result, not a diagnosis. '
          'Clinical evaluation is recommended '
          'for interpretation and follow-up.',
    );
  }

  void _validateFeatureVector(
    MovementFeatureVector features,
  ) {
    if (features.length != expectedFeatures.length) {
      throw StateError(
        'AI inference expected '
        '${expectedFeatures.length} features '
        'but received ${features.length}.',
      );
    }

    for (final feature in expectedFeatures) {
      if (!features.values.containsKey(feature)) {
        throw StateError(
          'AI inference missing feature: '
          '$feature',
        );
      }

      final value = features.values[feature]!;

      if (!value.isFinite) {
        throw StateError(
          'AI inference received non-finite '
          'feature: $feature',
        );
      }
    }
  }

  void _validateModel(
    ScreeningModel activeModel,
  ) {
    if (!activeModel.validate()) {
      throw StateError(
        'AI screening model failed validation.',
      );
    }

    if (activeModel.modelType != expectedModelType) {
      throw StateError(
        'AI model type does not match '
        'the expected model type.',
      );
    }

    if (activeModel.featureSchema !=
        expectedFeatureSchema) {
      throw StateError(
        'AI model feature schema does not '
        'match koa_vs_healthy_v1.',
      );
    }

    if (!_sameFeatureOrder(
      activeModel.featureColumns,
      expectedFeatures,
    )) {
      throw StateError(
        'AI model feature order does not '
        'match the koa_vs_healthy_v1 schema.',
      );
    }
  }

  bool _sameFeatureOrder(
    List<String> actual,
    List<String> expected,
  ) {
    if (actual.length != expected.length) {
      return false;
    }

    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        return false;
      }
    }

    return true;
  }

  String _formatContribution(
    ModelFeatureContribution contribution,
  ) {
    final direction =
        contribution.increasesRisk
            ? 'higher-risk contribution'
            : 'lower-risk contribution';

    return '${_humanReadableFeature(
      contribution.featureName,
    )}: $direction';
  }

  String _humanReadableFeature(
    String featureName,
  ) {
    switch (featureName) {
      case 'age':
        return 'Age';

      case 'bmi':
        return 'Body Mass Index (BMI)';

      case 'duration_seconds':
        return 'Movement Duration';

      case 'lf_acc_mean':
        return 'Thigh Acceleration';

      case 'lf_acc_std':
        return 'Thigh Acceleration Variability';

      case 'lf_acc_p95':
        return 'Peak Thigh Acceleration';

      case 'rf_acc_mean':
        return 'Shin Acceleration';

      case 'rf_acc_std':
        return 'Shin Acceleration Variability';

      case 'rf_acc_p95':
        return 'Peak Shin Acceleration';

      case 'lf_gyr_mean':
        return 'Thigh Rotational Movement';

      case 'lf_gyr_std':
        return 'Thigh Movement Variability';

      case 'lf_gyr_p95':
        return 'Peak Thigh Rotation';

      case 'rf_gyr_mean':
        return 'Shin Rotational Movement';

      case 'rf_gyr_std':
        return 'Shin Movement Variability';

      case 'rf_gyr_p95':
        return 'Peak Shin Rotation';

      case 'bilateral_acc_diff_mean':
        return 'Bilateral Acceleration Difference';

      case 'bilateral_acc_diff_std':
        return 'Bilateral Acceleration Variability';

      case 'bilateral_gyr_diff_mean':
        return 'Bilateral Rotation Difference';

      case 'bilateral_gyr_diff_std':
        return 'Bilateral Rotation Variability';

      case 'acc_mean':
        return 'Overall Acceleration';

      case 'acc_std':
        return 'Overall Acceleration Variability';

      case 'acc_cv':
        return 'Acceleration Consistency';

      case 'gyr_mean':
        return 'Overall Rotational Movement';

      case 'gyr_std':
        return 'Overall Movement Variability';

      case 'gyr_cv':
        return 'Rotational Movement Consistency';

      case 'lf_rf_acc_ratio':
        return 'Bilateral Acceleration Symmetry';

      case 'lf_rf_gyr_ratio':
        return 'Bilateral Gyroscope Symmetry';

      default:
        return featureName
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
            )
            .join(' ');
    }
  }
}