import 'dart:math';

import '../models/imu_data.dart';
import '../models/imu_embedding.dart';
import '../models/sensor_sample.dart';

/// Configuration for the PatchTST sensor transformer.
///
/// These hyper-parameters mirror the Python [PatchTSTEncoder] in
/// `ai/src/models/patch_tst_encoder.py` so that the Dart stub and
/// the Python training code stay structurally in sync.
class PatchTSTConfig {
  /// Number of input channels (6: ax, ay, az, gx, gy, gz per sensor pair).
  final int inputChannels;

  /// Length of each non-overlapping time patch (samples).
  final int patchSize;

  /// Stride between consecutive patches (samples). Equal to patchSize = no overlap.
  final int patchStride;

  /// Size of the transformer embedding dimension.
  final int dModel;

  /// Number of self-attention heads.
  final int nHeads;

  /// Number of stacked transformer blocks.
  final int nLayers;

  const PatchTSTConfig({
    this.inputChannels = 12, // thigh(6) + shin(6)
    this.patchSize = 16,
    this.patchStride = 16,
    this.dModel = 64,
    this.nHeads = 4,
    this.nLayers = 3,
  });
}

/// Pure-Dart implementation of the PatchTST sensor encoder branch.
///
/// Mirrors the architecture published in "PatchTST: A Time Series Worth
/// 64 Words" (NeurIPS 2023). The forward pass is deterministic for the
/// stub (sinusoidal position embeddings + fixed attention logits).
/// When real weights are trained in Python and exported as JSON, call
/// [loadWeights] to replace the sinusoidal fallback.
///
/// Pipeline:
///   SensorSample window → patchify → patch embedding → N × TransformerBlock
///   → global average pool → [d_model] embedding vector
class PatchTSTSensorEncoder {
  final PatchTSTConfig config;

  /// Optional trained projection weights (shape: [d_model × (patchSize × inputChannels)]).
  List<List<double>>? _projectionWeights;

  PatchTSTSensorEncoder({PatchTSTConfig? config})
      : config = config ?? const PatchTSTConfig();

  /// Loads trained projection weights exported from the Python training script.
  void loadWeights(List<List<double>> projectionWeights) {
    _projectionWeights = projectionWeights;
  }

  /// Encodes a window of [SensorSample]s into a fixed-length [ImuEmbedding].
  ///
  /// [window] should contain at least [config.patchSize] samples. If fewer
  /// are available the window is zero-padded to the minimum required length.
  ImuEmbedding encode(List<SensorSample> window) {
    final padded = _pad(window);
    final rawPatches = _patchify(padded);
    final projectedPatches = _projectPatches(rawPatches);
    final withPos = _addPositionalEncoding(projectedPatches);
    final attended = _selfAttention(withPos);
    final embedding = _globalAveragePool(attended);

    final attentionWeights = _computeAttentionWeights(attended);
    final microTremor = _microTremorScore(rawPatches);
    final gaitIrregularity = _gaitIrregularityScore(rawPatches);
    final bilateralSymmetry = _bilateralSymmetryScore(window);

    return ImuEmbedding(
      embedding: embedding,
      patchAttentionWeights: attentionWeights,
      microTremorScore: double.parse(microTremor.toStringAsFixed(4)),
      gaitIrregularityScore: double.parse(gaitIrregularity.toStringAsFixed(4)),
      bilateralSymmetryScore: double.parse(bilateralSymmetry.toStringAsFixed(4)),
      isStubResult: _projectionWeights == null,
      encodedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Zero-pad the sample window to a multiple of patchSize.
  // ---------------------------------------------------------------------------
  List<SensorSample> _pad(List<SensorSample> window) {
    final minLen = config.patchSize;
    if (window.length >= minLen) return window;

    final lastTs = window.isNotEmpty ? window.last.timestamp : 0;
    const zeroImu = ImuData(ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0);

    final padding = List.generate(
      minLen - window.length,
      (i) => SensorSample(
        timestamp: lastTs + (i + 1) * 20,
        thigh: zeroImu,
        shin: zeroImu,
      ),
    );

    return [...window, ...padding];
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Split window into non-overlapping patches.
  //           Each patch is a (patchSize × inputChannels) matrix flattened to 1-D.
  // ---------------------------------------------------------------------------
  List<List<double>> _patchify(List<SensorSample> window) {
    final patches = <List<double>>[];
    final stride = config.patchStride;
    final pSize = config.patchSize;

    for (int start = 0; start + pSize <= window.length; start += stride) {
      final flat = <double>[];
      for (int i = start; i < start + pSize; i++) {
        final s = window[i];
        flat
          ..add(s.thigh.ax)
          ..add(s.thigh.ay)
          ..add(s.thigh.az)
          ..add(s.thigh.gx)
          ..add(s.thigh.gy)
          ..add(s.thigh.gz)
          ..add(s.shin.ax)
          ..add(s.shin.ay)
          ..add(s.shin.az)
          ..add(s.shin.gx)
          ..add(s.shin.gy)
          ..add(s.shin.gz);
      }
      patches.add(flat);
    }

    return patches;
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Linear projection: flatten → d_model.
  //           Uses trained weights if available, otherwise sinusoidal stub.
  // ---------------------------------------------------------------------------
  List<List<double>> _projectPatches(List<List<double>> patches) {
    return patches.map((patch) {
      final proj = List<double>.filled(config.dModel, 0.0);

      if (_projectionWeights != null) {
        // Trained linear projection.
        for (int d = 0; d < config.dModel; d++) {
          double sum = 0.0;
          for (int k = 0; k < patch.length; k++) {
            sum += _projectionWeights![d][k % _projectionWeights![d].length] *
                patch[k];
          }
          proj[d] = sum;
        }
      } else {
        // Stub: hash-based sinusoidal projection (deterministic, architecture-correct).
        for (int d = 0; d < config.dModel; d++) {
          double sum = 0.0;
          for (int k = 0; k < patch.length; k++) {
            final angle =
                patch[k] * (d + 1) / (config.dModel * (k + 1));
            sum += sin(angle) * patch[k];
          }
          proj[d] = sum / (patch.length + 1e-8);
        }
      }

      return proj;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Step 4 — Sinusoidal positional encoding (PE).
  //           PE(pos, 2i)   = sin(pos / 10000^(2i/dModel))
  //           PE(pos, 2i+1) = cos(pos / 10000^(2i/dModel))
  // ---------------------------------------------------------------------------
  List<List<double>> _addPositionalEncoding(List<List<double>> patches) {
    return List.generate(patches.length, (pos) {
      final encoded = List<double>.from(patches[pos]);
      for (int i = 0; i < config.dModel; i++) {
        final freq = 1.0 / pow(10000.0, (2 * (i ~/ 2)) / config.dModel);
        encoded[i] += (i.isEven ? sin(pos * freq) : cos(pos * freq));
      }
      return encoded;
    });
  }

  // ---------------------------------------------------------------------------
  // Step 5 — Scaled dot-product self-attention (single head, stub).
  //           Q = K = V = patch embeddings.
  //           Attention(Q,K,V) = softmax(QKᵀ / √d_k) · V
  // ---------------------------------------------------------------------------
  List<List<double>> _selfAttention(List<List<double>> patches) {
    final n = patches.length;
    final dk = config.dModel.toDouble();

    // Compute raw attention scores n×n.
    final scores = List.generate(
        n, (_) => List<double>.filled(n, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        double dot = 0.0;
        for (int d = 0; d < config.dModel; d++) {
          dot += patches[i][d] * patches[j][d];
        }
        scores[i][j] = dot / sqrt(dk);
      }
    }

    // Softmax per row.
    final attnWeights = scores.map(_softmax).toList();

    // Weighted sum of values (V = patches).
    return List.generate(n, (i) {
      final out = List<double>.filled(config.dModel, 0.0);
      for (int j = 0; j < n; j++) {
        for (int d = 0; d < config.dModel; d++) {
          out[d] += attnWeights[i][j] * patches[j][d];
        }
      }
      return out;
    });
  }

  // ---------------------------------------------------------------------------
  // Step 6 — Global average pooling across the patch dimension.
  // ---------------------------------------------------------------------------
  List<double> _globalAveragePool(List<List<double>> attended) {
    final pooled = List<double>.filled(config.dModel, 0.0);
    for (final patch in attended) {
      for (int d = 0; d < config.dModel; d++) {
        pooled[d] += patch[d];
      }
    }
    for (int d = 0; d < config.dModel; d++) {
      pooled[d] /= attended.length;
    }
    return pooled;
  }

  // ---------------------------------------------------------------------------
  // Interpretable scalar computation
  // ---------------------------------------------------------------------------

  /// Attention weight distribution across patches (sums to 1.0).
  List<double> _computeAttentionWeights(List<List<double>> attended) {
    // Use L2 norm of each patch output as a proxy for its importance.
    final norms = attended.map((p) {
      final sumSq = p.fold<double>(0.0, (s, v) => s + v * v);
      return sqrt(sumSq);
    }).toList();

    final total = norms.fold<double>(0.0, (s, v) => s + v);
    if (total < 1e-12) return List.filled(attended.length, 1.0 / attended.length);
    return norms.map((n) => n / total).toList();
  }

  /// High-frequency gyroscope variance → micro-tremor severity (0 – 1).
  double _microTremorScore(List<List<double>> rawPatches) {
    if (rawPatches.isEmpty) return 0.0;

    // Gyroscope channels are indices 3–5 (thigh) and 9–11 (shin).
    const gyroIndices = [3, 4, 5, 9, 10, 11];

    double totalVariance = 0.0;
    int count = 0;

    for (final patch in rawPatches) {
      for (final idx in gyroIndices) {
        if (idx >= patch.length) continue;
        final values = <double>[];
        for (int s = idx; s < patch.length; s += 12) {
          values.add(patch[s]);
        }
        if (values.length < 2) continue;
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance = values
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            values.length;
        totalVariance += variance;
        count++;
      }
    }

    if (count == 0) return 0.0;
    // Empirical normalisation: 50 deg/s variance ≈ significant tremor.
    return (totalVariance / count / 2500.0).clamp(0.0, 1.0);
  }

  /// Inter-patch acceleration magnitude variance → gait irregularity (0 – 1).
  double _gaitIrregularityScore(List<List<double>> rawPatches) {
    if (rawPatches.length < 2) return 0.0;

    // Mean acceleration magnitude per patch.
    final patchMags = rawPatches.map((patch) {
      double sumSq = 0.0;
      int n = 0;
      for (int i = 0; i < patch.length - 5; i += 12) {
        final ax = i < patch.length ? patch[i] : 0.0;
        final ay = i + 1 < patch.length ? patch[i + 1] : 0.0;
        final az = i + 2 < patch.length ? patch[i + 2] : 0.0;
        sumSq += ax * ax + ay * ay + az * az;
        n++;
      }
      return n > 0 ? sqrt(sumSq / n) : 0.0;
    }).toList();

    final mean = patchMags.reduce((a, b) => a + b) / patchMags.length;
    final variance = patchMags
            .map((m) => (m - mean) * (m - mean))
            .reduce((a, b) => a + b) /
        patchMags.length;

    // Empirical normalisation: variance > 1.0 g ≈ very irregular gait.
    return (variance / 1.0).clamp(0.0, 1.0);
  }

  /// Cross-sensor bilateral symmetry (0 – 1, 1 = perfect). 
  double _bilateralSymmetryScore(List<SensorSample> window) {
    if (window.isEmpty) return 1.0;

    double thighMag = 0.0;
    double shinMag = 0.0;

    for (final s in window) {
      thighMag += sqrt(
        s.thigh.ax * s.thigh.ax + s.thigh.ay * s.thigh.ay + s.thigh.az * s.thigh.az,
      );
      shinMag += sqrt(
        s.shin.ax * s.shin.ax + s.shin.ay * s.shin.ay + s.shin.az * s.shin.az,
      );
    }

    thighMag /= window.length;
    shinMag /= window.length;

    final total = thighMag + shinMag;
    if (total < 1e-12) return 1.0;

    final asymmetry = (thighMag - shinMag).abs() / total;
    return (1.0 - asymmetry).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------
  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps = logits.map((v) => exp(v - maxVal)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
