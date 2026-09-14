class MovementFeatureVector {
  final Map<String, double> values;

  const MovementFeatureVector({
    required this.values,
  });

  double operator [](String name) {
    return values[name] ?? 0.0;
  }

  List<String> get names => values.keys.toList();

  int get length => values.length;

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(values);
  }
}