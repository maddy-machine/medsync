import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/screening_model.dart';

class ScreeningModelLoader {
  static const String modelAssetPath =
      'assets/models/koa_vs_healthy_v1_models.json';

  const ScreeningModelLoader();

  Future<ScreeningModel> load() async {
    final jsonString =
        await rootBundle.loadString(modelAssetPath);

    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Screening model JSON must contain an object.',
      );
    }

    final modelJson = _extractModel(decoded);

    return ScreeningModel.fromJson(modelJson);
  }

  Map<String, dynamic> _extractModel(
    Map<String, dynamic> root,
  ) {
    if (_looksLikeModel(root)) {
      return _prepareModel(root);
    }

    final combinedModel = root['combined_model'];

    if (combinedModel is Map) {
      final model =
          Map<String, dynamic>.from(combinedModel);

      if (_looksLikeModel(model)) {
        return _prepareModel(model);
      }
    }

    final combined = root['combined'];

    if (combined is Map) {
      final model =
          Map<String, dynamic>.from(combined);

      if (_looksLikeModel(model)) {
        return _prepareModel(model);
      }
    }

    final models = root['models'];

    if (models is Map) {
      final combinedFromModels =
          models['combined_model'];

      if (combinedFromModels is Map) {
        final model =
            Map<String, dynamic>.from(
          combinedFromModels,
        );

        if (_looksLikeModel(model)) {
          return _prepareModel(model);
        }
      }

      final combinedFromLegacy =
          models['combined'];

      if (combinedFromLegacy is Map) {
        final model =
            Map<String, dynamic>.from(
          combinedFromLegacy,
        );

        if (_looksLikeModel(model)) {
          return _prepareModel(model);
        }
      }

      for (final value in models.values) {
        if (value is Map) {
          final model =
              Map<String, dynamic>.from(value);

          if (_looksLikeModel(model)) {
            return _prepareModel(model);
          }
        }
      }
    }

    throw const FormatException(
      'Could not find a compatible screening model '
      'inside koa_vs_healthy_v1_models.json.',
    );
  }

  Map<String, dynamic> _prepareModel(
    Map<String, dynamic> model,
  ) {
    final prepared =
        Map<String, dynamic>.from(model);

    // The trained JSON stores the threshold inside:
    //
    // combined_model
    //   -> metrics
    //      -> threshold
    //
    // ScreeningModel expects threshold directly.
    if (!prepared.containsKey('threshold')) {
      final metrics = prepared['metrics'];

      if (metrics is Map &&
          metrics['threshold'] is num) {
        prepared['threshold'] =
            (metrics['threshold'] as num).toDouble();
      }
    }

    // The exported training artifact does not explicitly
    // store model_type. The trained model is logistic
    // regression, which is the model type supported by
    // ScreeningModel.
    prepared.putIfAbsent(
      'model_type',
      () => 'logistic_regression',
    );

    return prepared;
  }

  bool _looksLikeModel(
    Map<String, dynamic> json,
  ) {
    return json.containsKey('features') &&
        json.containsKey('means') &&
        json.containsKey('scales') &&
        json.containsKey('weights') &&
        json.containsKey('bias');
  }
}