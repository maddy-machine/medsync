import 'dart:math' as math;

class ScreeningModel {
  final String schema;
  final String modelType;
  final List<String> features;
  final List<double> means;
  final List<double> scales;
  final List<double> weights;
  final double bias;
  final double threshold;

  const ScreeningModel({
    required this.schema,
    required this.modelType,
    required this.features,
    required this.means,
    required this.scales,
    required this.weights,
    required this.bias,
    required this.threshold,
  });

  factory ScreeningModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final modelType =
        json['model_type']?.toString() ??
        'logistic_regression';

    if (modelType != 'logistic_regression') {
      throw FormatException(
        'Unsupported screening model type: $modelType',
      );
    }

    final schema =
        json['schema']?.toString() ??
        'koa_vs_healthy_v1';

    final rawFeatures = json['features'];
    final rawMeans = json['means'];
    final rawScales = json['scales'];
    final rawWeights = json['weights'];

    if (rawFeatures is! List ||
        rawMeans is! Map ||
        rawScales is! Map ||
        rawWeights is! List) {
      throw const FormatException(
        'Invalid screening model structure.',
      );
    }

    final features = rawFeatures
        .map((value) => value.toString())
        .toList();

    final expectedFeatures = <String>[
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

    if (!_sameList(features, expectedFeatures)) {
      throw const FormatException(
        'Screening model feature order does not match '
        'koa_vs_healthy_v1.',
      );
    }

    if (features.length != 27) {
      throw FormatException(
        'Expected 27 features, got ${features.length}.',
      );
    }

    final means = features.map((feature) {
      final value = rawMeans[feature];

      if (value is! num) {
        throw FormatException(
          'Missing mean for feature: $feature',
        );
      }

      final result = value.toDouble();

      if (!result.isFinite) {
        throw FormatException(
          'Non-finite mean for feature: $feature',
        );
      }

      return result;
    }).toList();

    final scales = features.map((feature) {
      final value = rawScales[feature];

      if (value is! num) {
        throw FormatException(
          'Missing scale for feature: $feature',
        );
      }

      final result = value.toDouble();

      if (!result.isFinite || result <= 0) {
        throw FormatException(
          'Invalid scale for feature: $feature',
        );
      }

      return result;
    }).toList();

    final weights = rawWeights.map((value) {
      if (value is! num) {
        throw const FormatException(
          'Invalid model weight.',
        );
      }

      final result = value.toDouble();

      if (!result.isFinite) {
        throw const FormatException(
          'Non-finite model weight.',
        );
      }

      return result;
    }).toList();

    if (weights.length != features.length) {
      throw const FormatException(
        'Weight count does not match feature count.',
      );
    }

    final rawBias = json['bias'];

    if (rawBias is! num ||
        !rawBias.toDouble().isFinite) {
      throw const FormatException(
        'Invalid model bias.',
      );
    }

    final rawThreshold = json['threshold'];

    if (rawThreshold is! num) {
      throw const FormatException(
        'Invalid model threshold.',
      );
    }

    final threshold = rawThreshold.toDouble();

    if (!threshold.isFinite ||
        threshold <= 0 ||
        threshold >= 1) {
      throw const FormatException(
        'Model threshold must be between 0 and 1.',
      );
    }

    return ScreeningModel(
      schema: schema,
      modelType: modelType,
      features: features,
      means: means,
      scales: scales,
      weights: weights,
      bias: rawBias.toDouble(),
      threshold: threshold,
    );
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible API used by ScreeningInferenceService.
  // ---------------------------------------------------------------------------

  String get modelVersion => schema;

  String get featureSchema => schema;

  List<String> get featureColumns =>
      List.unmodifiable(features);

  double get screeningThreshold => threshold;

  bool validate() {
    if (schema != 'koa_vs_healthy_v1') {
      return false;
    }

    if (modelType != 'logistic_regression') {
      return false;
    }

    if (features.length != 27 ||
        means.length != 27 ||
        scales.length != 27 ||
        weights.length != 27) {
      return false;
    }

    for (var i = 0; i < features.length; i++) {
      if (!means[i].isFinite ||
          !scales[i].isFinite ||
          scales[i] <= 0 ||
          !weights[i].isFinite) {
        return false;
      }
    }

    if (!bias.isFinite ||
        !threshold.isFinite ||
        threshold <= 0 ||
        threshold >= 1) {
      return false;
    }

    return true;
  }

  double predictProbability(
    Map<String, double> featureValues,
  ) {
    return predict(featureValues);
  }

  double predict(
    Map<String, double> featureValues,
  ) {
    if (!validate()) {
      throw StateError(
        'Screening model failed validation.',
      );
    }

    if (featureValues.length != features.length) {
      throw ArgumentError(
        'Expected ${features.length} features, '
        'got ${featureValues.length}.',
      );
    }

    var linear = bias;

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final value = featureValues[feature];

      if (value == null ||
          !value.isFinite) {
        throw ArgumentError(
          'Missing or invalid feature: $feature',
        );
      }

      final standardized =
          (value - means[i]) / scales[i];

      linear += standardized * weights[i];
    }

    return _sigmoid(linear);
  }

  bool isAboveThreshold(
    double probability,
  ) {
    return probability >= threshold;
  }

  List<ModelFeatureContribution> explain(
    Map<String, double> featureValues,
  ) {
    if (!validate()) {
      throw StateError(
        'Screening model failed validation.',
      );
    }

    if (featureValues.length != features.length) {
      throw ArgumentError(
        'Expected ${features.length} features, '
        'got ${featureValues.length}.',
      );
    }

    final contributions =
        <ModelFeatureContribution>[];

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final value = featureValues[feature];

      if (value == null ||
          !value.isFinite) {
        continue;
      }

      final standardized =
          (value - means[i]) / scales[i];

      final contribution =
          standardized * weights[i];

      contributions.add(
        ModelFeatureContribution(
          feature: feature,
          contribution: contribution,
          standardizedValue: standardized,
        ),
      );
    }

    contributions.sort(
      (a, b) => b.absoluteContribution.compareTo(
        a.absoluteContribution,
      ),
    );

    return contributions;
  }

  static bool _sameList(
    List<String> a,
    List<String> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  static double _sigmoid(
    double value,
  ) {
    if (value >= 0) {
      final z = math.exp(-value);
      return 1.0 / (1.0 + z);
    }

    final z = math.exp(value);
    return z / (1.0 + z);
  }
}


class ModelFeatureContribution {
  final String feature;

  String get featureName => feature;
  final double contribution;
  final double standardizedValue;

  const ModelFeatureContribution({
    required this.feature,
    required this.contribution,
    required this.standardizedValue,
  });

  double get absoluteContribution {
    return contribution.abs();
  }

  bool get increasesRisk {
    return contribution > 0;
  }
}