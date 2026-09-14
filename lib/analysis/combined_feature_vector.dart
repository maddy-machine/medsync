
import 'knee_angle_features.dart';
import 'movement_features.dart';

class CombinedFeatureVector {
  final MovementFeatureVector features;

  const CombinedFeatureVector({
    required this.features,
  });

  factory CombinedFeatureVector.fromAnalysis({
    required MovementFeatureVector chairStandFeatures,
    required KneeAngleFeatures kneeFeatures,
  }) {
    final combined =
        <String, double>{};

    combined.addAll(
      chairStandFeatures.values,
    );

    combined.addAll(
      kneeFeatures.toMap(),
    );

    return CombinedFeatureVector(
      features: MovementFeatureVector(
        values: combined,
      ),
    );
  }

  Map<String, double> get values =>
      features.values;

  List<String> get names =>
      features.names;

  int get length =>
      features.length;

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(
      features.values,
    );
  }
}