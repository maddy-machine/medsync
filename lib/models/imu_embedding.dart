/// Output of the PatchTST sensor encoder branch.
///
/// Contains a fixed-length transformer embedding vector together
/// with interpretable scalar features derived from the attention
/// weights — these are the numbers the cross-attention fusion
/// layer consumes from the sensor side.
class ImuEmbedding {
  /// Transformer embedding vector (length = d_model, typically 64).
  final List<double> embedding;

  /// Per-patch attention weight distribution (sums to ≈1.0).
  /// Maps each IMU time-patch to its relative importance.
  final List<double> patchAttentionWeights;

  /// Micro-tremor severity score derived from high-frequency gyroscope
  /// variance across patches (0.0 = none, 1.0 = severe).
  final double microTremorScore;

  /// Gait irregularity score: inter-patch variance in acceleration
  /// magnitude — captures asymmetric heel-strike patterns (0.0 – 1.0).
  final double gaitIrregularityScore;

  /// Bilateral symmetry score from thigh/shin channel comparison (0.0 – 1.0,
  /// 1.0 = perfect bilateral symmetry).
  final double bilateralSymmetryScore;

  /// Whether this embedding was produced by the stub encoder
  /// (before real PatchTST weights are trained).
  final bool isStubResult;

  /// Timestamp of encoding.
  final DateTime encodedAt;

  const ImuEmbedding({
    required this.embedding,
    required this.patchAttentionWeights,
    required this.microTremorScore,
    required this.gaitIrregularityScore,
    required this.bilateralSymmetryScore,
    this.isStubResult = true,
    required this.encodedAt,
  });

  /// L2-normalised sensor risk score derived from the embedding (0.0 – 1.0).
  double get sensorRiskScore {
    // Weighted combination of the three interpretable scalars.
    final raw = microTremorScore * 0.30 +
        gaitIrregularityScore * 0.45 +
        (1.0 - bilateralSymmetryScore) * 0.25;
    return raw.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'embedding': embedding,
        'patch_attention_weights': patchAttentionWeights,
        'micro_tremor_score': microTremorScore,
        'gait_irregularity_score': gaitIrregularityScore,
        'bilateral_symmetry_score': bilateralSymmetryScore,
        'is_stub_result': isStubResult,
        'encoded_at': encodedAt.toIso8601String(),
      };

  factory ImuEmbedding.fromJson(Map<String, dynamic> json) => ImuEmbedding(
        embedding: (json['embedding'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
        patchAttentionWeights: (json['patch_attention_weights'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
        microTremorScore: (json['micro_tremor_score'] as num).toDouble(),
        gaitIrregularityScore:
            (json['gait_irregularity_score'] as num).toDouble(),
        bilateralSymmetryScore:
            (json['bilateral_symmetry_score'] as num).toDouble(),
        isStubResult: json['is_stub_result'] as bool? ?? true,
        encodedAt:
            DateTime.tryParse(json['encoded_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
